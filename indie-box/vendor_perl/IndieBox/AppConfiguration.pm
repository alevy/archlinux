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
# use IndieBox::AppConfigurationItems::DirectoryTree;
use IndieBox::AppConfigurationItems::File;
# use IndieBox::AppConfigurationItems::Perlscript;
# use IndieBox::AppConfigurationItems::Symlink;
use IndieBox::Logging;
use JSON;
use MIME::Base64;

use fields qw{json site app};

my $APPCONFIGPARSDIR = '/etc/indie-box/appconfigpars';

##
# Constructor.
# $json: JSON object containing one appconfig section of a Site JSON
# $site: Site object representing the site that this AppConfiguration belongs to
# return: AppConfiguration object
sub new {
    my $self = shift;
    my $json = shift;
    my $site = shift;

    unless( ref $self ) {
        $self = fields::new( $self );
    }
    $self->{json} = $json;
    $self->{site} = $site;

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
# Obtain the instantiated customization points for this AppConfiguration
# return: customization points hierarchy as given in the site JSON
sub customizationPoints {
    my $self = shift;

    return $self->{json}->{customizationpoints};
}

##
# Install this AppConfiguration.
sub install {
    my $self = shift;

    my $appConfigId = $self->appConfigId;
    IndieBox::Utils::mkdir( "$APPCONFIGPARSDIR/$appConfigId" );

    my @installables        = ( $self->{app} );
    my $appConfigCustPoints = $self->customizationPoints();

    foreach my $installable ( @installables ) {
        my $installableJson = $installable->installableJson;
        my $packageName     = $installable->packageName;

        my $config = new IndieBox::Configuration(
                {
                    "package.name" => $packageName,
                    "appconfig.appconfigid" => $self->appConfigId(),
                    "appconfig.context" => $self->context(),
                    "appconfig.contextorslash" => $self->contextOrSlash(),
                    "site.hostname" => $self->{site}->hostName(),
                    "site.siteid" => $self->{site}->siteId()
                },
                $installable->config );

        # Customization points for this Installable at this AppConfiguration

        IndieBox::Utils::mkdir( "$APPCONFIGPARSDIR/$appConfigId/$packageName" );

        my $installableCustPoints = $installable->customizationPoints;
        if( $installableCustPoints ) {
            while( my( $custPointName, $custPointDef ) = each( %$installableCustPoints )) {
                my $value = $appConfigCustPoints->{$packageName}->{$custPointName};

                unless( $value ) {
                    # use default instead
                    $value = $custPointDef->{default};
                }
                if( defined( $value )) {
                    my $data = $value->{value};
                    if( $value->{encoding} eq 'base64' ) {
                        $data = decode_base64( $data );
                    }
                    IndieBox::Utils::saveFile( "$APPCONFIGPARSDIR/$appConfigId/$packageName/$custPointName", $data );
                }
            }
        }

        # Now for all the roles
        my $applicableRoleNames = IndieBox::Host::applicableRoleNames();
        foreach my $roleName ( @$applicableRoleNames ) {
            my $installableRoleJson = $installableJson->{roles}->{$roleName};
            unless( $installableRoleJson ) {
                next;
            }

            # skip dependencies: done already

            if( 'apache2' eq $roleName ) {
                my $apache2modules = $installableRoleJson->{apache2modules};
                if( $apache2modules ) {
                    IndieBox::Apache2::activateModules( @$apache2modules );
                }
            }

            my $appConfigItems = $installableRoleJson->{appconfigitems};
            unless( $appConfigItems ) {
                next;
            }
            foreach my $appConfigItem ( @$appConfigItems ) {
                my $type = $appConfigItem->{type};
                my $item;

                if( 'file' eq $type ) {
                    $item = IndieBox::AppConfigurationItems::File->new( $appConfigItem, $self );
                } elsif( 'directory' eq $type ) {
                    $item = IndieBox::AppConfigurationItems::Directory->new( $appConfigItem, $self );
                }
                if( $item ) {
                    $item->install(
                            $config->getResolve( 'package.codedir' ),
                            $config->getResolve( "appconfig.$roleName.dir" ),
                            $config );
                }
            }
        }
    }
}

##
# Uninstall this AppConfiguration.
sub uninstall {
    my $self = shift;

    my $appConfigId = $self->appConfigId;

    # faster to do a simple recursive delete, instead of going point by point
    IndieBox::Utils::deleteRecursively( "$APPCONFIGPARSDIR/$appConfigId" );
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

1;
