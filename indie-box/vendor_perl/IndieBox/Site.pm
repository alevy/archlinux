#!/usr/bin/perl
#
# Represents a Site for Indie Box Project
#
# Copyright (C) 2013-2014 Indie Box Project http://indieboxproject.org/
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

package IndieBox::Site;

use IndieBox::Apache2;
use IndieBox::AppConfiguration;
use IndieBox::Backup;
use IndieBox::Logging;
use IndieBox::Utils;
use JSON;
use MIME::Base64;

use fields qw{json appConfigs config};

##
# Constructor.
# $json: JSON object containing Site JSON
# return: Site object
sub new {
    my $self = shift;
    my $json = shift;

    unless( ref $self ) {
        $self = fields::new( $self );
    }
    $self->{json} = $json;
    $self->_checkJson();

    my $siteId = $self->siteId();
    $self->{config} = new IndieBox::Configuration(
                "Site=$siteId",
                {
                    "site.hostname" => $self->hostName(),
                    "site.siteid"   => $siteId,
                    "site.protocol" => ( $self->hasSsl() ? 'https' : 'http' )
                },
            IndieBox::Host::config() );

    return $self;
}

##
# Obtain the site's id.
# return: string
sub siteId {
    my $self = shift;

    return $self->{json}->{siteid};
}

##
# Obtain the site JSON
# return: site JSON
sub siteJson {
    my $self = shift;

    return $self->{json};
}

##
# Obtain the site's host name.
# return: string
sub hostName {
    my $self = shift;

    return $self->{json}->{hostname};
}

##
# Obtain the Configuration object
# return: the Configuration object
sub config {
    my $self = shift;

    return $self->{config};
}

##
# Determine whether SSL data has been given.
# return: 0 or 1
sub hasSsl {
    my $self = shift;

    return ( defined( $self->{json}->{ssl}->{key} ) ? 1 : 0 );
}

##
# Obtain the SSL key, if any has been provided.
# return: the SSL key
sub sslKey {
    my $self = shift;

    return $self->{json}->{ssl}->{key};
}

##
# Obtain the SSL certificate, if any has been provided.
# return: the SSL certificate
sub sslCert {
    my $self = shift;

    return $self->{json}->{ssl}->{crt};
}

##
# Obtain the SSL certificate chain, if any has been provided.
# return: the SSL certificate chain
sub sslCertChain {
    my $self = shift;

    return $self->{json}->{ssl}->{crtchain};
}

##
# Obtain the SSL certificate chain to be used with clients, if any has been provided.
sub sslCaCert {
    my $self = shift;

    return $self->{json}->{ssl}->{cacrt};
}

##
# Obtain the site's robots.txt file content, if any has been provided.
# return: robots.txt content
sub robotsTxt {
    my $self = shift;

    return $self->{json}->{wellknown}->{robotstxt};
}

##
# Obtain the beginning of the site's robots.txt file content, if no robots.txt
# has been provided.
# return: prefix of robots.txt content
sub robotsTxtPrefix {
    my $self = shift;

    return $self->{json}->{wellknown}->{robotstxtprefix};
}

##
# Obtain the site's sitemap.xml file content, if any has been provided.
# return: robots.txt content
sub sitemapXml {
    my $self = shift;

    return $self->{json}->{wellknown}->{sitemapxml};
}

##
# Obtain the site's favicon.ico file content, if any has been provided.
# return: binary content of favicon.ico
sub faviconIco {
    my $self = shift;

    if( $self->{json}->{wellknown}->{faviconicobase64} ) {
        return decode_base64( $self->{json}->{wellknown}->{faviconicobase64} );
    } else {
        return undef;
    }
}

##
# Obtain the AppConfigurations at this Site.
# return: array of AppConfiguration objects
sub appConfigs {
    my $self = shift;

    unless( defined( $self->{appConfigs} )) {
        my $jsonAppConfigs = $self->{json}->{appconfigs};
        $self->{appConfigs} = [];
        foreach my $current ( @$jsonAppConfigs ) {
            push @{$self->{appConfigs}}, new IndieBox::AppConfiguration( $current, $self );
        }
    }
    return $self->{appConfigs};
}

##
# Obtain an AppConfiguation with a particular appconfigid on this Site.
# return: the AppConfiguration, or undef
sub appConfig {
    my $self        = shift;
    my $appconfigid = shift;

    foreach my $appConfig ( @{$self->appConfigs} ) {
        if( $appconfigid eq $appConfig->appConfigId ) {
            return $appConfig;
        }
    }
    return undef;
}

##
# Add names of application packages that are required to run the specified roles for this site.
# $roleNames: array of role names
# $packages: hash of packages
sub addInstallablesToPrerequisites {
    my $self      = shift;
    my $roleNames = shift;
    my $packages  = shift;

    # This may be invoked before the Application JSON of some of the applications is
    # available, so we cannot access $appConfig->app for example.

    my $jsonAppConfigs = $self->{json}->{appconfigs};
    foreach my $jsonAppConfig ( @$jsonAppConfigs ) {
        my $appId = $jsonAppConfig->{appid};

        $packages->{$appId} = $appId;
    }

    1;
}

##
# Add names of dependent packages that are required to run the specified roles for this site.
# $roleNames: array of role names
# $packages: hash of packages
sub addDependenciesToPrerequisites {
    my $self      = shift;
    my $roleNames = shift;
    my $packages  = shift;

    foreach my $appConfig ( @{$self->appConfigs} ) {
        foreach my $installable ( $appConfig->installables ) {
            foreach my $roleName ( @$roleNames ) {
                my $roleJson = $installable->{json}->{roles}->{$roleName};
                if( $roleJson ) {
                    my $depends = $roleJson->{depends};
                    if( $depends ) {
                        foreach my $depend ( @$depends ) {
                            $packages->{$depend} = $depend;
                        }
                    }
                }
            }
        }
    }
    1;
}

##
# Before deploying, check whether this Site would be deployable
# If not, this invocation never returns
sub checkDeployable {
    my $self = shift;

    debug( 'Site', $self->{json}->{siteid}, '->checkDeployable' );

    $self->_deployOrCheck( 0 );
}

##
# Deploy this Site
sub deploy {
    my $self = shift;

    debug( 'Site', $self->{json}->{siteid}, '->deploy' );

    $self->_deployOrCheck( 1 );
}

##
# Deploy this Site, or just check whether it is deployable. Both functions
# share the same code, so the checks get updated at the same time as the
# actual deployment.
# $doIt: if 1, deploy; if 0, only check
sub _deployOrCheck {
    my $self = shift;
    my $doIt = shift;
    
    my $siteDocumentDir = $self->config->getResolve( 'site.apache2.sitedocumentdir' );

    if( $doIt ) {
        IndieBox::Utils::mkdir( $siteDocumentDir, 0755 );
        IndieBox::Apache2::setupSite( $self );
    }
    
    foreach my $appConfig ( @{$self->appConfigs} ) {
        $appConfig->_deployOrCheck( $doIt );
    }

    if( $doIt ) {
        IndieBox::Host::siteDeployed( $self );
    }

    1;
}

##
# Prior to undeploying, check whether this site can be undeployed
# If not, this invocation never returns
sub checkUndeployable {
    my $self = shift;

    debug( 'Site', $self->{json}->{siteid}, '->checkUndeployable' );

    $self->_undeployOrCheck( 0 );
}
    
##
# Undeploy this site
sub undeploy {
    my $self = shift;

    debug( 'Site', $self->{json}->{siteid}, '->undeploy' );

    $self->_undeployOrCheck( 1 );
}

##
# Undeploy this site, or just check whether it is undeployable. Both functions
# share the same code, so the checks get updated at the same time as the
# actual undeployment.
# $doIt: if 1, undeploy; if 0, only check
sub _undeployOrCheck {
    my $self = shift;
    my $doIt = shift;

    foreach my $appConfig ( @{$self->appConfigs} ) {
        $appConfig->_undeployOrCheck( $doIt );
    }

    if( $doIt ) {
        IndieBox::Apache2::removeSite( $self );
        IndieBox::Host::siteUndeployed( $self );
    }

    my $siteDocumentDir = $self->config->getResolve( 'site.apache2.sitedocumentdir' );

    if( $doIt ) {
        IndieBox::Utils::rmdir( $siteDocumentDir );
    }

    1;
}

##
# Set up a placeholder for this new site: "coming soon"
# $triggers: triggers to be executed may be added to this hash
sub setupPlaceholder {
    my $self     = shift;
    my $triggers = shift;

    IndieBox::Apache2::setupPlaceholderSite( $self, 'maintenance' );

    $triggers->{'httpd-reload'} = 1;
}

##
# Suspend this site: replace site with an "updating" placeholder or such
# $triggers: triggers to be executed may be added to this hash
sub suspend {
    my $self     = shift;
    my $triggers = shift;

    IndieBox::Apache2::setupPlaceholderSite( $self, 'maintenance' );

    $triggers->{'httpd-reload'} = 1;
}

##
# Resume this site from suspension
# $triggers: triggers to be executed may be added to this hash
sub resume {
    my $self     = shift;
    my $triggers = shift;

    IndieBox::Apache2::setupSite( $self );

    $triggers->{'httpd-reload'} = 1;
}

##
# Permanently disable this site
# $triggers: triggers to be executed may be added to this hash
sub disable {
     my $self     = shift;
     my $triggers = shift;

    IndieBox::Apache2::setupPlaceholderSite( $self, 'nosuchsite' );

    $triggers->{'httpd-reload'} = 1;
}

##
# Back up this site.
# $filename: optional filename to back up to
# return: the Backup object
sub backup {
    my $self     = shift;
    my $filename = shift;

    debug( 'Site', $self->{json}->{siteid}, '->backup' );

    unless( $filename ) {
        $filename = $self->{config}->getResolve( 'site.backupfile' );
    }

    my $backup = new IndieBox::Backup( [ $self->siteId ], undef, $filename );
    return $backup;
}

##
# Restore this entire Site.
# $backup: the Backup object from which to restore the Site
# $oldSite: the Site before the restore, or undef if none
sub restoreSite {
    my $self    = shift;
    my $backup  = shift;
    my $oldSite = shift;

    debug( 'Site', $self->{json}->{siteid}, '->restoreSite' );

    my $siteDocumentDir = $self->config->getResolve( 'site.apache2.sitedocumentdir' );
    IndieBox::Utils::mkdir( $siteDocumentDir, 0755 );

    IndieBox::Apache2::setupSite( $self );

    foreach my $appConfig ( @{$self->appConfigs} ) {
        $appConfig->deploy();
    }
    foreach my $appConfig ( @{$self->appConfigs} ) {
        $backup->restoreAppConfiguration( $oldSite, $appConfig );
    }

    IndieBox::Host::siteDeployed( $self );

    1;
}

##
# Restore a single AppConfiguration to this Site.
# $backup: the Backup object from which to restore the AppConfiguration
# $oldSite: the Site before the restore, or undef if none
# $appConfigId: the appconfigid of the AppConfiguration to restore
sub restoreAppConfiguration {
    my $self        = shift;
    my $backup      = shift;
    my $oldSite     = shift;
    my $appConfigId = shift;

    debug( 'Site', $self->{json}->{siteid}, '->restoreAppConfiguration' );

    my $appConfig = $oldSite->appConfig( $appConfigId );
    $appConfig->deploy();
    $backup->restoreAppConfiguration( $self, $oldSite, $appConfig );

    IndieBox::Host::siteDeployed( $self );
}

##
# Check validity of the Site JSON
# return: 1 or exits with fatal error
sub _checkJson {
    my $self = shift;
    my $json = $self->{json};

    unless( $json ) {
        fatal( 'No Site JSON present' );
    }
    $self->_checkJsonValidKeys( $json, [] );

    unless( $json->{siteid} ) {
        fatal( 'Site JSON: missing siteid' );
    }
    unless( ref( $json->{siteid} ) || $json->{siteid} =~ m/^s[0-9a-f]{4}([0-9a-f]{28})?$/ ) {
        fatal( 'Site JSON: invalid siteid, must be s followed by 4 or 32 hex chars' );
    }
    unless( $json->{hostname} ) {
        fatal( 'Site JSON: missing hostname' );
    }
    unless( ref( $json->{hostname} ) || $json->{hostname} =~ m/^(?=.{1,255}$)[0-9A-Za-z](?:(?:[0-9A-Za-z]|-){0,61}[0-9A-Za-z])?(?:\.[0-9A-Za-z](?:(?:[0-9A-Za-z]|-){0,61}[0-9A-Za-z])?)*\.?$/ ) {
        # regex from http://stackoverflow.com/a/1420225/200304
        fatal( 'Site JSON: invalid hostname' );
    }

    if( $json->{ssl} ) {
        unless( ref( $json->{ssl} ) eq 'HASH' ) {
            fatal( 'Site JSON: ssl section: not a JSON object' );
        }
        unless( $json->{ssl}->{key} || !ref( $json->{ssl}->{key} )) {
            fatal( 'Site JSON: ssl section: missing or invalid key' );
        }
        unless( $json->{ssl}->{crt} || !ref( $json->{ssl}->{crt} )) {
            fatal( 'Site JSON: ssl section: missing or invalid crt' );
        }
        unless( $json->{ssl}->{crtchain} || !ref( $json->{ssl}->{crtchain} )) {
            fatal( 'Site JSON: ssl section: missing or invalid crtchain' );
        }
        if( $json->{ssl}->{cacrt} && ref( $json->{ssl}->{cacrt} )) {
            fatal( 'Site JSON: ssl section: invalid cacrt' );
        }
    }

    if( $json->{wellknown} ) {
        unless( ref( $json->{wellknown} ) eq 'HASH' ) {
            fatal( 'Site JSON: wellknown section: not a JSON object' );
        }
        if( $json->{wellknown}->{robotstxt} && ref( $json->{wellknown}->{robotstxt} )) {
            fatal( 'Site JSON: wellknown section: invalid robotstxt' );
        }
        if(    $json->{wellknown}->{sitemapxml}
            && (    ref( $json->{wellknown}->{sitemapxml} )
                 || $json->{wellknown}->{sitemapxml} !~ m!^<\?xml! ))
        {
            fatal( 'Site JSON: wellknown section: invalid sitemapxml' );
        }
        if( $json->{wellknown}->{faviconicobase64} && ref( $json->{wellknown}->{faviconicobase64} )) {
            fatal( 'Site JSON: wellknown section: invalid faviconicobase64' );
        }
    }

    if( $json->{appconfigs} ) {
        unless( ref( $json->{appconfigs} ) eq 'ARRAY' ) {
            fatal( 'Site JSON: appconfigs section: not a JSON array' );
        }

        my $i=0;
        foreach my $appConfigJson ( @{$json->{appconfigs}} ) {
            unless( $appConfigJson->{appconfigid} ) {
                fatal( "Site JSON: appconfig $i: missing appconfigid" );
            }
            unless( ref( $appConfigJson->{appconfigid} ) || $appConfigJson->{appconfigid} =~ m/^a[0-9a-f]{4}([0-9a-f]{28})?$/ ) {
                fatal( "Site JSON: appconfig $i: invalid appconfigid, must be a followed by 4 or 32 hex chars" );
            }
            if(    $appConfigJson->{context}
                && (    ref( $appConfigJson->{context} )
                     || $appConfigJson->{context} !~ m!^(/[-_\.a-zA-Z0-9]+)?$! ))
            {
                fatal( "Site JSON: appconfig $i: invalid context, must be valid context URL without trailing slash" );
            }
            if( $appConfigJson->{isdefault} && !JSON::is_bool( $appConfigJson->{isdefault} )) {
                fatal( "Site JSON: appconfig $i: invalid isdefault, must be true or false" );
            }
            unless( $appConfigJson->{appid} && !ref( $appConfigJson->{appid} )) {
                fatal( "Site JSON: appconfig $i: invalid appid" );
                # FIXME: format of this string must be better specified and checked
            }
            ++$i;
        }
    }
    
    return 1;
}

##
# Recursive check that Site JSON only has valid keys. This catches typos.
# $json: the JSON, or JSON sub-tree
# $context: the name of the current section, if any
sub _checkJsonValidKeys {
    my $self    = shift;
    my $json    = shift;
    my $context = shift;
    
    if( ref( $json ) eq 'HASH' ) {
        if( @$context >= 2 && $context->[-1] eq 'customizationpoints' ) {
            # This is a package name, which has laxer rules
            while( my( $key, $value ) = each %$json ) {
                unless( $key =~ m!^[a-z][-_a-z0-9]*$! ) {
                    fatal( 'Site JSON: invalid key in JSON:', "'$key'", 'context:', join( ' / ', @$context ) || '(top)' );
                }
                $self->_checkJsonValidKeys( $value, [ @$context, $key ] );
            }
        } elsif( @$context >= 2 && $context->[-2] eq 'customizationpoints' ) {
            # This is a customization point name, which has laxer rules
            while( my( $key, $value ) = each %$json ) {
                unless( $key =~ m!^[a-z][_a-z0-9]*$! ) {
                    fatal( 'Site JSON: invalid key in JSON:', "'$key'", 'context:', join( ' / ', @$context ) || '(top)' );
                }
                $self->_checkJsonValidKeys( $value, [ @$context, $key ] );
            }
        } else {
            while( my( $key, $value ) = each %$json ) {
                unless( $key =~ m!^[a-z]+$! ) {
                    fatal( 'Site JSON: invalid key in JSON:', "'$key'", 'context:', join( ' / ', @$context ) || '(top)' );
                }
                $self->_checkJsonValidKeys( $value, [ @$context, $key ] );
            }
        }
    } elsif( ref( $json ) eq 'ARRAY' ) {
        foreach my $element ( @$json ) {
            $self->_checkJsonValidKeys( $element, $context );
        }
    }
}

1;
