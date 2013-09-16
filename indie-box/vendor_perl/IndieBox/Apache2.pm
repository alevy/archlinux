#!/usr/bin/perl
#
# Apache2 abstraction for the Indie Box Project
#
# Copyright (C) 2013 Johannes Ernst
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

##
# Ensure that Apache is running.
sub ensureRunning {
    debug( "Apache2::ensureRunning" );

    IndieBox::Utils::myexec( 'systemctl enable httpd' );
    IndieBox::Utils::myexec( 'systemctl restart httpd' );

    1;
}

##
# Reload configuration
sub reload {
    debug( "Apache2::reload" );

    IndieBox::Utils::myexec( 'systemctl reload httpd' );

    1;
}

##
# Restart configuration
sub restart {
    debug( "Apache2::restart" );

    IndieBox::Utils::myexec( 'systemctl restart httpd' );

    1;
}

##
# Do what is necessary to set up a named placeholder site.
sub setupPlaceholderSite {
    my $site            = shift;
    my $placeholderName = shift;

    my $siteId            = $site->siteId;
    my $hostName          = $site->hostName;
    my $siteFile          = "$sitesDir/$siteId.conf";
    my $siteDocumentRoot  = "$placeholderSitesDocumentRootDir/$placeholderName";

    unless( -d $siteDocumentRoot ) {
        error( "Placeholder site $placeholderName does not exist at $siteDocumentRoot" );
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

    my $siteId            = $site->siteId;
    my $hostName          = $site->hostName;
    my $siteFile          = "$sitesDir/$siteId.conf";
    my $appConfigFilesDir = "$appConfigsDir/$siteId";
    my $siteDocumentRoot  = "$sitesDocumentRootDir/$siteId";
    my $siteWellKnownDir  = "$sitesWellknownDir/$siteId";

    unless( -d $siteDocumentRoot ) {
        IndieBox::Utils::mkdir( $siteDocumentRoot );
    }
    unless( -d $siteWellKnownDir ) {
        IndieBox::Utils::mkdir( $siteWellKnownDir );
    }
    unless( -d $appConfigFilesDir ) {
        IndieBox::Utils::mkdir( $appConfigFilesDir );
    }

    my $content .= <<CONTENT;
#
# Apache config fragment for site $siteId at host $hostName
#
# (C) 2013 Indie Box Project
# Generated automatically, do not modify.
#

<VirtualHost *:80>
    ServerName $hostName

    DocumentRoot "$siteDocumentRoot"
    Options -Indexes
CONTENT

    foreach my $appConfig ( @{$site->appConfigs} ) {
        if( $appConfig->isDefault ) {
            my $context = $appConfig->context();
            if( $context ) {
                $$content .= <<CONTENT;
        RedirectMatch seeother ^/\$ $context/
CONTENT
                last;
            }
        }
    }

    $content .= <<CONTENT;
    AliasMatch ^/favicon\.ico $siteWellKnownDir/favicon.ico
    AliasMatch ^/robots\.txt  $siteWellKnownDir/robots.txt
    AliasMatch ^/sitemap\.xml $siteWellKnownDir/sitemap.xml

    Include $appConfigFilesDir/
</VirtualHost>
CONTENT

    IndieBox::Utils::saveFile( $siteFile, $content, 0644 );

    1;
}

##
# Do what is necessary to remove a site. This includes:
# * remove an Apache2 configuration fragment for the site
# * delete directories etc.
# $site: the Site
sub removeSite {
    my $site = shift;

    my $siteId            = $site->siteId;
    my $siteFile          = "$sitesDir/$siteId.conf";
    my $appConfigFilesDir = "$appConfigsDir/$siteId";
    my $siteDocumentRoot  = "$sitesDocumentRootDir/$siteId";
    my $siteWellKnownDir  = "$sitesWellknownDir/$siteId";

    IndieBox::Utils::deleteFile( $siteFile );

    if( -d $appConfigFilesDir ) {
        IndieBox::Utils::deleteFile( $appConfigFilesDir );
    }
    if( -d $siteWellKnownDir ) {
        IndieBox::Utils::deleteFile( $siteWellKnownDir );
    }
    if( -d $siteDocumentRoot ) {
        IndieBox::Utils::deleteFile( $siteDocumentRoot );
    }

    1;
}

##
# Make the changes to Apache configuration files are in place that are needed by Indie Box.
sub ensureConfigFiles {
    debug( "Apache2::ensureConfigFiles" );

    if( -e $ourConfigFile ) {
        IndieBox::Utils::myexec( "cp -f '$ourConfigFile' '$mainConfigFile'" );
    } else {
        warn( "Config file $ourConfigFile is missing" );
    }
    activateModules( 'alias', 'authz_host', 'deflate', 'dir', 'mime' ); # always need those
}

##
# Activate one ore more Apache modules
sub activateModules {
    my @modules = @_;

    foreach my $module ( @modules ) {
        debug( "Activating Apache2 module: $module" );

        if( -e "$modsEnabledDir/$module.load" ) {
            next; # enabled already
        }
        unless( -e "$modsAvailableDir/$module.load" ) {
            warn( "Cannot find Apache2 module $module; not enabling" );
            next;
        }
        IndieBox::Utils::myexec( "ln -s '$modsAvailableDir/$module.load' '$modsEnabledDir/$module.load'" );
    }
    1;
}

1;
