#!/usr/bin/perl
#
# Represents an AppConfiguration on a Site for Indie Box Project
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

package IndieBox::AppConfiguration;

use IndieBox::App;
use IndieBox::Host;
use IndieBox::AppConfigurationItems::Directory;
use IndieBox::AppConfigurationItems::DirectoryTree;
use IndieBox::AppConfigurationItems::File;
use IndieBox::AppConfigurationItems::MysqlDatabase;
use IndieBox::AppConfigurationItems::Perlscript;
use IndieBox::AppConfigurationItems::Sqlscript;
use IndieBox::AppConfigurationItems::Symlink;
use IndieBox::Logging;
use JSON;
use MIME::Base64;

use fields qw{json site app config};

my $APPCONFIGPARSDIR = '/var/lib/indie-box/appconfigpars';

##
# Constructor.
# $json: JSON object containing one appconfig section of a Site JSON
# $site: Site object representing the site that this AppConfiguration belongs to
# return: AppConfiguration object
sub new {
    my $self = shift;
    my $json = shift;
    my $site = shift; # this may be undef when restoring from backup

    unless( ref $self ) {
        $self = fields::new( $self );
    }
    $self->{json}   = $json;
    $self->{site}   = $site;
    $self->{config} = undef; # initialized when needed

    # No checking required, IndieBox::Site::new has done that already
    return $self;
}

##
# Obtain identifier of this AppConfiguration.
# return: string
sub appConfigId {
    my $self = shift;

    return $self->{json}->{appconfigid};
}

##
# Obtain the AppConfiguration JSON
# return: AppConfiguration JSON
sub appConfigurationJson {
    my $self = shift;

    return $self->{json};
}

##
# Obtain the Site object that this AppConfiguration belongs to.
# return: Site object
sub site {
    my $self = shift;

    return $self->{site};
}

##
# Determine whether this AppConfiguration is the default AppConfiguration at this Site.
# return: 0 or 1
sub isDefault {
    my $self = shift;

    my $isDefault = $self->{json}->{isdefault};
    if( defined( $isDefault ) && JSON::is_bool( $isDefault ) && $isDefault ) {
        return 1;
    } else {
        return 0;
    }
}

##
# Obtain the relative URL without trailing slash.
# return: relative URL
sub context {
    my $self = shift;

    $self->_initialize();

    my $ret = $self->{app}->fixedContext();
    unless( defined( $ret )) {
        $ret = $self->{json}->{context};
    }
    unless( defined( $ret )) {
        $ret = $self->{app}->defaultContext();
    }
    return $ret;
}

##
# Obtain the relative URL without trailing slash, except return / if root of site
# return: relative URL
sub contextOrSlash {
    my $self = shift;

    my $ret = $self->context;
    unless( $ret ) {
        $ret = '/';
    }
    return $ret;
}

##
# Obtain the app at this AppConfiguration.
# return: the App
sub app {
    my $self = shift;

    $self->_initialize();

    return $self->{app};
}

##
# Obtain the installables at this AppConfiguration.
# return: list of installables
sub installables {
    my $self = shift;

    $self->_initialize();

    return ( $self->{app} );
}

##
# Obtain the instantiated customization points for this AppConfiguration
# return: customization points hierarchy as given in the site JSON
sub customizationPoints {
    my $self = shift;

    return $self->{json}->{customizationpoints};
}

##
# Obtain the Configuration object
# return: the Configuration object
sub config {
    my $self = shift;

    unless( $self->{config} ) {
        my $site        = $self->site();
        my $appConfigId = $self->appConfigId();
        $self->{config} = new IndieBox::Configuration(
                    "AppConfiguration=$appConfigId",
                    {
                        "appconfig.appconfigid"    => $appConfigId,
                        "appconfig.context"        => $self->context(),
                        "appconfig.contextorslash" => $self->contextOrSlash(),
                    },
                    defined( $site ) ? $site->config : undef );
    }

    return $self->{config};
}

##
# Before deploying, check whether this AppConfiguration would be deployable
# If not, this invocation never returns
sub checkDeployable {
    my $self = shift;

    debug( 'AppConfiguration', $self->{json}->{siteid}, '->checkDeployable' );

    $self->_deployOrCheck( 0 );
}

##
# Deploy this AppConfiguration.
sub deploy {
    my $self = shift;

    trace( 'AppConfiguration', $self->{json}->{appconfigid}, '->deploy' );

    $self->_deployOrCheck( 1 );
}

##
# Deploy this AppConfiguration, or just check whether it is deployable. Both functions
# share the same code, so the checks get updated at the same time as the
# actual deployment.
# $doIt: if 1, deploy; if 0, only check
sub _deployOrCheck {
    my $self = shift;
    my $doIt = shift;

    $self->_initialize();

    unless( $self->{site} ) {
        fatal( 'Cannot deploy AppConfiguration without site' );
    }
    my $siteDocumentDir = $self->config->getResolve( 'site.apache2.sitedocumentdir' );

    my $applicableRoleNames = IndieBox::Host::applicableRoleNames();
    foreach my $roleName ( @$applicableRoleNames ) {
        my $dir = $self->config->getResolveOrNull( "appconfig.$roleName.dir", undef, 1 );
        if( $doIt && $dir && $dir ne $siteDocumentDir ) {
            IndieBox::Utils::mkdir( $dir, 0755 );
        }
    }

    my $appConfigId = $self->appConfigId;
    if( $doIt ) {
        IndieBox::Utils::mkdir( "$APPCONFIGPARSDIR/$appConfigId" );
    }

    my @installables = $self->installables();

    foreach my $installable ( @installables ) {
        my $installableJson = $installable->installableJson;
        my $packageName     = $installable->packageName;

        my $config = new IndieBox::Configuration(
                "Installable=$packageName,AppConfiguration=$appConfigId",
                {},
                $installable->config,
                $self->config );

        # Customization points for this Installable at this AppConfiguration

        if( $doIt ) {
            IndieBox::Utils::mkdir( "$APPCONFIGPARSDIR/$appConfigId/$packageName" );
        }

        $self->_addCustomizationPointValuesToConfig( $config, $installable, $doIt );

        # Now for all the roles
        foreach my $roleName ( @$applicableRoleNames ) {
            my $installableRoleJson = $installableJson->{roles}->{$roleName};
            unless( $installableRoleJson ) {
                next;
            }

            # skip dependencies: done already

            if( 'apache2' eq $roleName ) {
                my $apache2modules = $installableRoleJson->{apache2modules};
                if( $self->site->hasSsl ) {
					push @$apache2modules, 'ssl';
				}
                if( $doIt && $apache2modules ) {
                    IndieBox::Apache2::activateApacheModules( @$apache2modules );
                }
                my $phpModules = $installableRoleJson->{phpmodules};
                if( $doIt && $phpModules ) {
                    IndieBox::Apache2::activatePhpModules( @$phpModules );
                }
            }

            my $appConfigItems = $installableRoleJson->{appconfigitems};
            unless( $appConfigItems ) {
                next;
            }

            my $codeDir = $config->getResolve( 'package.codedir' );
            my $dir     = $self->config->getResolveOrNull( "appconfig.$roleName.dir", undef, 1 );
            foreach my $appConfigItem ( @$appConfigItems ) {
                my $item = $self->instantiateAppConfigurationItem( $appConfigItem, $installable );
                if( $item ) {
                    $item->installOrCheck( $doIt, $codeDir, $dir, $config );
                }
            }
        }
    }
}

##
# Before undeploying, check whether this AppConfiguration would be undeployable
# If not, this invocation never returns
sub checkUndeployable {
    my $self = shift;

    debug( 'AppConfiguration', $self->{json}->{siteid}, '->checkUndeployable' );

    $self->_undeployOrCheck( 0 );
}

##
# Undeploy this AppConfiguration.
sub undeploy {
    my $self = shift;

    trace( 'AppConfiguration', $self->{json}->{appconfigid}, '->undeploy' );

    $self->_undeployOrCheck( 1 );
}

##
# Undeploy this AppConfiguration, or just check whether it is undeployable. Both functions
# share the same code, so the checks get updated at the same time as the
# actual deployment.
# $doIt: if 1, undeploy; if 0, only check
sub _undeployOrCheck {
    my $self = shift;
    my $doIt = shift;

    $self->_initialize();

    unless( $self->{site} ) {
        fatal( 'Cannot undeploy AppConfiguration without site' );
    }

    my $applicableRoleNames = IndieBox::Host::applicableRoleNames();

    my $appConfigId = $self->appConfigId;

    # faster to do a simple recursive delete, instead of going point by point
    if( $doIt ) {
        IndieBox::Utils::deleteRecursively( "$APPCONFIGPARSDIR/$appConfigId" );
    }

    my @installables = $self->installables();

    foreach my $installable ( reverse @installables ) {
        my $installableJson = $installable->installableJson;
        my $packageName     = $installable->packageName;

        my $config = new IndieBox::Configuration(
                "Installable=$packageName,AppConfiguration=$appConfigId",
                {},
                $installable->config,
                $self->config );

        $self->_addCustomizationPointValuesToConfig( $config, $installable );

        # Now for all the roles
        foreach my $roleName ( reverse @$applicableRoleNames ) {
            my $installableRoleJson = $installableJson->{roles}->{$roleName};
            unless( $installableRoleJson ) {
                next;
            }

            my $appConfigItems = $installableRoleJson->{appconfigitems};
            unless( $appConfigItems ) {
                next;
            }
            my $codeDir = $config->getResolve( 'package.codedir' );
            my $dir     = $self->config->getResolveOrNull( "appconfig.$roleName.dir", undef, 1 );

            foreach my $appConfigItem ( reverse @$appConfigItems ) {
                my $item = $self->instantiateAppConfigurationItem( $appConfigItem, $installable );

                if( $item ) {
                    $item->uninstallOrCheck( $doIt, $codeDir, $dir, $config );
                }
            }
        }
    }

    my $siteDocumentDir = $self->config->getResolve( 'site.apache2.sitedocumentdir' );
    foreach my $roleName ( @$applicableRoleNames ) {
        my $dir = $self->config->getResolveOrNull( "appconfig.$roleName.dir", undef, 1 );
        if( $doIt && $dir && $dir ne $siteDocumentDir ) {
            IndieBox::Utils::rmdir( $dir );
        }
    }
}

##
# Run the installer(s) for the app at this AppConfiguration
sub runInstaller {
    my $self = shift;

    return $self->_runPostDeploy( 'installers', 'install' );
}

##
# Run the uninstaller(s) for the app at this AppConfiguration
sub runUninstaller {
    my $self = shift;

    return $self->_runPostDeploy( 'uninstallers', 'uninstall' );
}

##
# Run the upgrader(s) for the app at this AppConfiguration
sub runUpgrader {
    my $self = shift;

    return $self->_runPostDeploy( 'upgraders', 'upgrade' );
}

##
# Common code for running installers, uninstallers and upgraders
# $jsonSection: name of the JSON section that holds the script(s)
# $methodName: name of the method on AppConfigurationItem to invoke
sub _runPostDeploy {
    my $self        = shift;
    my $jsonSection = shift;
    my $methodName  = shift;

    debug( 'AppConfiguration', $self->{json}->{appconfigid}, '->_runPostDeploy', $methodName );

    unless( $self->{site} ) {
        fatal( 'Cannot _runPostDeploy AppConfiguration without site' );
    }

    my $applicableRoleNames = IndieBox::Host::applicableRoleNames();
    my $appConfigId         = $self->appConfigId;
    my @installables        = $self->installables();

    foreach my $installable ( @installables ) {
        my $packageName = $installable->packageName;

        my $config = new IndieBox::Configuration(
                "Installable=$packageName,AppConfiguration=$appConfigId",
                {},
                $installable->config,
                $self->config );

        $self->_addCustomizationPointValuesToConfig( $config, $installable );

        foreach my $roleName ( @$applicableRoleNames ) {
            my $itemsJson = $installable->installableJson->{roles}->{$roleName}->{$jsonSection};

            unless( $itemsJson ) {
                next;
            }

            my $codeDir = $config->getResolve( 'package.codedir' );
            my $dir     = $self->config->getResolveOrNull( "appconfig.$roleName.dir", undef, 1 );

            foreach my $itemJson ( @$itemsJson ) {
                my $item = $self->instantiateAppConfigurationItem( $itemJson, $installable );

                if( $item ) {
                    $item->runPostDeployScript( $methodName, $codeDir, $dir, $config );
                }
            }
        }
    }
}

##
# Instantiate the right subclass of AppConfigurationItem.
# $json: the JSON fragment for the AppConfigurationItem
# $installable: the Installable that the AppConfigurationItem belongs to
# return: instance of subclass of AppConfigurationItem, or undef
sub instantiateAppConfigurationItem {
    my $self        = shift;
    my $json        = shift;
    my $installable = shift;

    my $ret;
    my $type = $json->{type};

    if( 'file' eq $type ) {
        $ret = IndieBox::AppConfigurationItems::File->new( $json, $self, $installable );
    } elsif( 'directory' eq $type ) {
        $ret = IndieBox::AppConfigurationItems::Directory->new( $json, $self, $installable );
    } elsif( 'directorytree' eq $type ) {
        $ret = IndieBox::AppConfigurationItems::DirectoryTree->new( $json, $self, $installable );
    } elsif( 'symlink' eq $type ) {
        $ret = IndieBox::AppConfigurationItems::Symlink->new( $json, $self, $installable );
    } elsif( 'perlscript' eq $type ) {
        $ret = IndieBox::AppConfigurationItems::Perlscript->new( $json, $self, $installable );
    } elsif( 'sqlscript' eq $type ) {
        $ret = IndieBox::AppConfigurationItems::Sqlscript->new( $json, $self, $installable );
    } elsif( 'mysql-database' eq $type ) {
        $ret = IndieBox::AppConfigurationItems::MysqlDatabase->new( $json, $self, $installable );
    } else {
        error( 'Unknown AppConfigurationItem type:', $type );
        $ret = undef;
    }
    return $ret;
}

##
# Internal helper to initialize the on-demand app field
# return: the App
sub _initialize {
    my $self = shift;

    if( defined( $self->{app} )) {
        return 1;
    }

    $self->{app} = new IndieBox::App( $self->{json}->{appid} );

    return 1;
}

##
# Internal helper to add the applicable customization point values to the $config object.
# This is factored out because it is used in several places.
# $config: the Configuration object
# $installable: the installable whose customization points values are to be added
# $save: if true, save the value to the file as well
sub _addCustomizationPointValuesToConfig {
    my $self        = shift;
    my $config      = shift;
    my $installable = shift;
    my $save        = shift || 0;
    
    my $installableCustPoints = $installable->customizationPoints;
    if( $installableCustPoints ) {
        my $packageName         = $installable->packageName;
        my $appConfigId         = $self->appConfigId;
        my $appConfigCustPoints = $self->customizationPoints();

        while( my( $custPointName, $custPointDef ) = each( %$installableCustPoints )) {
            my $value = $appConfigCustPoints->{$packageName}->{$custPointName};

            unless( defined( $value ) && defined( $value->{value} )) {
                # use default instead
                $value = $custPointDef->{default};
            }
            if( defined( $value )) {
                my $data = $value->{value};
                if( defined( $data )) { # value might be null
                    if( defined( $value->{encoding} ) && $value->{encoding} eq 'base64' ) {
                        $data = decode_base64( $data );
                    }
                    my $filename = "$APPCONFIGPARSDIR/$appConfigId/$packageName/$custPointName";
                    if( $save ) {
                        IndieBox::Utils::saveFile( $filename, $data );
                    }

                    $config->put( 'appconfig.installable.customizationpoints.' . $custPointName . '.filename', $filename );
                    $config->put( 'appconfig.installable.customizationpoints.' . $custPointName . '.value', $data );
                }
            }
        }
    }
}

1;
