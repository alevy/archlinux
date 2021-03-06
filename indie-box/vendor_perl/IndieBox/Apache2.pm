#!/usr/bin/perl
#
# Apache2 abstraction for the Indie Box Project
#
# Copyright (C) 2013 Indie Box Project http://indieboxproject.org/
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

use strict;
use warnings;

package IndieBox::Apache2;

use DBI;
use Fcntl qw( SEEK_END SEEK_SET );
use IndieBox::Logging;
use IndieBox::Utils;
use Time::HiRes qw( gettimeofday );

my $mainConfigFile   = '/etc/httpd/conf/httpd.conf';
my $ourConfigFile    = '/etc/httpd/conf/httpd-indie-box.conf';
my $modsAvailableDir = '/etc/httpd/indie-box/mods-available';
my $modsEnabledDir   = '/etc/httpd/indie-box/mods-enabled';
my $sitesDir         = '/etc/httpd/indie-box/sites';
my $appConfigsDir    = '/etc/httpd/indie-box/appconfigs';
my $sitesDocumentRootDir            = '/srv/http/sites';
my $sitesWellknownDir               = '/srv/http/wellknown';
my $placeholderSitesDocumentRootDir = '/srv/http/placeholders';
my $phpModulesDir     = '/usr/lib/php/modules';
my $phpModulesConfDir = '/etc/php/conf.d';

my $logFile  = '/var/log/httpd/error_log';

my @minimumApacheModules = qw( alias authz_core authz_host cgi deflate dir env log_config mime mpm_prefork setenvif unixd ); # always need those

##
# Ensure that Apache is running.
sub ensureRunning {
    trace( 'Apache2::ensureRunning' );

    IndieBox::Utils::myexec( 'systemctl enable httpd' );
    IndieBox::Utils::myexec( 'systemctl restart httpd' );

    1;
}

##
# Reload configuration
sub reload {
    trace( 'Apache2::reload' );

    _syncApacheCtl( 'reload' );

    1;
}

##
# Restart configuration
sub restart {
    trace( 'Apache2::restart' );

    _syncApacheCtl( 'restart' );

    1;
}

##
# Helper method to restart or reload Apache, and wait until it is ready to accept
# requests again. Because apachectl is asynchronous, this keeps reading the system
# log until it appears that the operation is complete. For good measure, we wait a
# little bit longer.
# Note that open connections will not necessarily be closed forcefully.
# $command: the Apache systemd command, such as 'restart' or 'reload'
# $max: maximum seconds to wait until returning from this method
# $poll: seconds (may be fraction) between subsequent reads of the log
# return: 0: success, 1: timeout
sub _syncApacheCtl {
    my $command = shift;
    my $max     = shift || 10;
    my $poll    = shift || 0.1;

    open( FH, '<', $logFile ) || fatal( 'Cannot open', $logFile );
    my $lastPos = sysseek( FH, 0, SEEK_END );
    close( FH );

    IndieBox::Utils::myexec( "systemctl $command httpd" );
    
    my( $seconds, $microseconds ) = gettimeofday;
    my $until = $seconds + 0.000001 * $microseconds + $max;
    
    while( 1 ) {
        select( undef, undef, undef, $poll ); # apparently a tricky way of sleeping for $poll seconds that works with fractions        

        open( FH, '<', $logFile ) || fatal( 'Cannot open', $logFile );
        my $pos = sysseek( FH, 0, SEEK_END );
        
        my $written = '';
        if( $pos != $lastPos ) {
            sysseek( FH, $lastPos, SEEK_SET );
            sysread( FH, $written, $pos - $lastPos, 0 );
        }
        close( FH );
        $lastPos = $pos;
        
        ( $seconds, $microseconds ) = gettimeofday;
        my $delta = $seconds + 0.000001 * $microseconds - $until;
        
        if( $written =~ /resuming normal operations/ ) {
            debug( 'Detected Apache restart after ', $delta + $max, 'seconds' );
            return 0;
        }
        
        if( $delta >= $max ) {
            IndieBox::Logging::warn( 'Apache command', $command, 'not finished within', $max, 'seconds' );
            return 1;
        }
    }
}

##
# Do what is necessary to set up a named placeholder site.
sub setupPlaceholderSite {
    my $site            = shift;
    my $placeholderName = shift;

    trace( 'Apache2::setupPlaceholderSite' );

    my $siteId            = $site->siteId;
    my $hostName          = $site->hostName;
    my $siteFile          = "$sitesDir/$siteId.conf";
    my $siteDocumentRoot  = "$placeholderSitesDocumentRootDir/$placeholderName";

    unless( -d $siteDocumentRoot ) {
        error( 'Placeholder site', $placeholderName, 'does not exist at', $siteDocumentRoot );
    }

    my $content .= <<CONTENT;
#
# Apache config fragment for placeholder site $siteId (placeholder $placeholderName) at host $hostName
#
# (C) 2013 Indie Box Project
# Generated automatically, do not modify.
#

<VirtualHost *:80>
    ServerName $hostName

    DocumentRoot "$siteDocumentRoot"
    Options -Indexes

    AliasMatch ^/_common/css/([-a-z0-9]*\.css)\$ /srv/http/_common/css/\$1
    AliasMatch ^/_common/images/([-a-z0-9]*\.png)\$ /srv/http/_common/images/\$1
</VirtualHost>
CONTENT

    IndieBox::Utils::saveFile( $siteFile, $content );

    1;
}

##
# Do what is necessary to set up a site. This includes:
# * generate an Apache2 configuration fragment for a site and save it in the right place
# * create directories etc
# $site: the Site
sub setupSite {
    my $site = shift;

    trace( 'Apache2::setupSite' );

    my $siteId            = $site->siteId;
    my $hostName          = $site->hostName;
    my $siteFile          = "$sitesDir/$siteId.conf";
    my $appConfigFilesDir = "$appConfigsDir/$siteId";
    my $siteDocumentRoot  = "$sitesDocumentRootDir/$siteId";
    my $siteWellKnownDir  = "$sitesWellknownDir/$siteId";

    unless( -d $siteWellKnownDir ) {
        IndieBox::Utils::mkdir( $siteWellKnownDir );
    }
    unless( -d $appConfigFilesDir ) {
        IndieBox::Utils::mkdir( $appConfigFilesDir );
    }
    
    my $siteFileContent = <<CONTENT;
#
# Apache config fragment for site $siteId at host $hostName
#
# (C) 2013 Indie Box Project
# Generated automatically, do not modify.
#
CONTENT
    
    my $siteAtPort;
    my $sslDir;
    my $sslKey;
    my $sslCert;
    my $sslCertChain;
    my $sslCaCert;
    
    if( $site->hasSsl ) {
        $siteAtPort = 443;
        $siteFileContent .= <<CONTENT;

<VirtualHost *:80>
    ServerName $hostName

    Redirect / https://$hostName/
</VirtualHost>
CONTENT

        $sslDir       = $site->config->getResolve( 'apache2.ssldir' );
        $sslKey       = $site->sslKey;
        $sslCert      = $site->sslCert;
        $sslCertChain = $site->sslCertChain;
        $sslCaCert    = $site->sslCaCert;

        my $group = $site->config->getResolve( 'apache2.gname' );
        
        if( $sslKey ) {
            IndieBox::Utils::saveFile( "$sslDir/$siteId.key",      $sslKey,       0440, 'root', $group ); # avoid overwrite by apache
        }
        if( $sslCert ) {
            IndieBox::Utils::saveFile( "$sslDir/$siteId.crt",      $sslCert,      0440, 'root', $group );
        }
        if( $sslCertChain ) {
            IndieBox::Utils::saveFile( "$sslDir/$siteId.crtchain", $sslCertChain, 0440, 'root', $group );
        }

        if( $sslCaCert ) {
            IndieBox::Utils::saveFile( "$sslDir/$siteId.cacrt", $sslCaCert, 0040, 'root', $group );
        }


    } else {
        # No SSL
        $siteAtPort = 80;
    }
    
    $siteFileContent .= <<CONTENT;

<VirtualHost *:$siteAtPort>
    ServerName $hostName

    DocumentRoot "$siteDocumentRoot"
    Options -Indexes

    SetEnv SiteId "$siteId"

    <Directory "$siteDocumentRoot">
        AllowOverride All

        <IfModule php5_module>
            php_admin_value open_basedir $siteDocumentRoot:/tmp/:/usr/share/
        </IfModule>
    </Directory>
CONTENT

    if( $site->hasSsl ) {
        $siteFileContent .= <<CONTENT;

    SSLEngine on

    # our own key
    SSLCertificateKeyFile $sslDir/$siteId.key

    # our own cert
    SSLCertificateFile $sslDir/$siteId.crt
 
    # the CA certs explaining where we got our own cert from
    SSLCertificateChainFile $sslDir/$siteId.crtchain
CONTENT
        if( $sslCaCert ) {
            $siteFileContent .= <<CONTENT;

    # the CA certs explaining where our clients got their certs from
    SSLCACertificateFile $sslDir/$siteId.cacrt
CONTENT
        }
    }

    my $hasDefault = 0;
    foreach my $appConfig ( @{$site->appConfigs} ) {
        my $context = $appConfig->context();
        if( $appConfig->isDefault ) {
            $hasDefault = 1;
            if( $context ) {
                $siteFileContent .= <<CONTENT;

    RedirectMatch seeother ^/\$ $context/
CONTENT
                last;
            }
        } elsif( defined( $context ) && !$context ) {
            # runs at root of site
            $hasDefault = 1;
        }
    }
    unless( $hasDefault ) {
        $siteFileContent .= <<CONTENT;

    ScriptAliasMatch ^/\$ /usr/share/indie-box/cgi-bin/show-apps.pl
    ScriptAliasMatch ^/_appicons/([-a-z0-9]+)/([0-9]+x[0-9]+|license)\\.(png|txt)\$ /usr/share/indie-box/cgi-bin/render-appicon.pl

    AliasMatch ^/_common/css/([-a-z0-9]*\.css)\$ /srv/http/_common/css/\$1
    AliasMatch ^/_common/images/([-a-z0-9]*\.png)\$ /srv/http/_common/images/\$1
CONTENT
    }

    $siteFileContent .= <<CONTENT;

    AliasMatch ^/favicon\.ico $siteWellKnownDir/favicon.ico
    AliasMatch ^/robots\.txt  $siteWellKnownDir/robots.txt
    AliasMatch ^/sitemap\.xml $siteWellKnownDir/sitemap.xml

    Include $appConfigFilesDir/
</VirtualHost>
CONTENT

    IndieBox::Utils::saveFile( $siteFile, $siteFileContent, 0644 );
    
    1;
}

##
# Do what is necessary to remove a site. This includes:
#  * remove an Apache2 configuration fragment for the site
#  * delete directories etc.
# $site: the Site
sub removeSite {
    my $site = shift;

    trace( 'Apache2::removeSite' );

    my $siteId            = $site->siteId;
    my $siteFile          = "$sitesDir/$siteId.conf";
    my $appConfigFilesDir = "$appConfigsDir/$siteId";
    my $siteDocumentRoot  = "$sitesDocumentRootDir/$siteId";
    my $siteWellKnownDir  = "$sitesWellknownDir/$siteId";

    IndieBox::Utils::deleteFile( $siteFile );

    if( -d $appConfigFilesDir ) {
        IndieBox::Utils::rmdir( $appConfigFilesDir );
    }
    if( -d $siteWellKnownDir ) {
        IndieBox::Utils::rmdir( $siteWellKnownDir );
    }

    1;
}

##
# Make the changes to Apache configuration files are in place that are needed by Indie Box.
sub ensureConfigFiles {
    trace( 'Apache2::ensureConfigFiles' );

    if( -e $ourConfigFile ) {
        IndieBox::Utils::myexec( "cp -f '$ourConfigFile' '$mainConfigFile'" );
    } else {
        IndieBox::Logging::warn( 'Config file', $ourConfigFile, 'is missing' );
    }
    activateApacheModules( @minimumApacheModules );

    # Make sure we have default SSL keys and a self-signed cert

    my $sslDir  = '/etc/httpd/conf';
    my $crtFile = "$sslDir/server.crt";
    my $keyFile = "$sslDir/server.key";
    my $csrFile = "$sslDir/server.csr";
    
    my $uid = 0;  # avoid overwrite by http
    my $gid = IndieBox::Utils::getGid( 'http' );

    unless( -f $keyFile ) {
        IndieBox::Utils::myexec( "openssl genrsa -out '$keyFile' 4096" );
        chmod 0040, $keyFile;
        chown $uid, $gid, $keyFile;
    }
    unless( -f $crtFile ) {
        IndieBox::Utils::myexec(
                "openssl req -new -key '$keyFile' -out '$csrFile'"
                . ' -subj "/CN=localhost.localdomain"' );

        IndieBox::Utils::myexec( "openssl x509 -req -days 3650 -in '$csrFile' -signkey '$keyFile' -out '$crtFile'" );
        chmod 0040, $crtFile;
        chown $uid, $gid, $crtFile;
    }
}

##
# Activate one ore more Apache modules
# @modules: list of module names
sub activateApacheModules {
    my @modules = @_;

    foreach my $module ( @modules ) {
        if( -e "$modsEnabledDir/$module.load" ) {
            debug( 'Apache2 module activated already:', $module );
            next;
        }
        unless( -e "$modsAvailableDir/$module.load" ) {
            IndieBox::Logging::warn( 'Cannot find Apache2 module, not activating:', $module );
            next;
        }
        debug( 'Activating Apache2 module:', $module );

        IndieBox::Utils::myexec( "ln -s '$modsAvailableDir/$module.load' '$modsEnabledDir/$module.load'" );
    }

    1;
}

##
# Activate one or more PHP modules
# @modules: list of module names
sub activatePhpModules {
    my @modules = @_;

    foreach my $module ( @modules ) {
        if( -e "$phpModulesConfDir/$module.ini" ) {
            debug( 'PHP module activated already:', $module );
            next;
        }
        unless( -e "$phpModulesDir/$module.so" ) {
            IndieBox::Logging::warn( 'Cannot find PHP module, not activating:', $module );
            next;
        }
        debug( 'Activating PHP module:', $module );

        IndieBox::Utils::saveFile( "$phpModulesConfDir/$module.ini", <<END );
extension=$module.so
END
    }

    1;
}

1;
