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
use IndieBox::Logging;
use IndieBox::Utils;

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

my @minimumApacheModules = qw( alias authz_host deflate dir mime log_config setenvif ); # always need those

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

    IndieBox::Utils::myexec( 'systemctl reload httpd' );

    1;
}

##
# Restart configuration
sub restart {
    trace( 'Apache2::restart' );

    IndieBox::Utils::myexec( 'systemctl restart httpd' );

    1;
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
        
        if( $sslKey ) {
            IndieBox::Utils::saveFile( "$sslDir/$siteId.key",      $sslKey,       0440, 'root', 'www-data' ); # avoid overwrite by www-data
        }
        if( $sslCert ) {
            IndieBox::Utils::saveFile( "$sslDir/$siteId.crt",      $sslCert,      0440, 'root', 'www-data' );
        }
        if( $sslCertChain ) {
            IndieBox::Utils::saveFile( "$sslDir/$siteId.crtchain", $sslCertChain, 0440, 'root', 'www-data' );
        }

        if( $sslCaCert ) {
            IndieBox::Utils::saveFile( "$sslDir/$siteId.cacrt", $sslCaCert, 0040, 'root', 'www-data' );
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

    <Directory "$siteDocumentRoot">
        AllowOverride All

        <IfModule php5_module>
            php_admin_value open_basedir $siteDocumentRoot:/tmp/:/usr/share/enx
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

	foreach my $appConfig ( @{$site->appConfigs} ) {
		if( $appConfig->isDefault ) {
			my $context = $appConfig->context();
			if( $context ) {
				$siteFileContent .= <<CONTENT;

    RedirectMatch seeother ^/\$ $context/
CONTENT
				last;
			}
		}
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
        warn( 'Config file', $ourConfigFile, 'is missing' );
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
            warn( 'Cannot find Apache2 module, not activating:', $module );
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
            warn( 'Cannot find PHP module, not activating:', $module );
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
