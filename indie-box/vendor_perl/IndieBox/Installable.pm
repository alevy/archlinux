#!/usr/bin/perl
#
# Superclass of all installable items e.g. Apps for Indie Box Project
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

package IndieBox::Installable;

use fields qw{json config packageName};

use IndieBox::Host;
use IndieBox::Logging;
use JSON;
use IndieBox::Utils qw( readJsonFromFile );

##
# Constructor.
# $packageName: unique identifier of the package
sub new {
    my $self        = shift;
    my $packageName = shift;

    unless( ref $self ) {
        $self = fields::new( $self );
    }

    my $json        = readJsonFromFile( manifestFileFor( $packageName ));
    $self->{config} = new IndieBox::Configuration(
            "Installable=$packageName",
            { "package.name" => $packageName },
            IndieBox::Host::config() );

    $self->{json}        = $json;
    $self->{packageName} = $packageName;

    return $self;
}

##
# Obtain the Configuration object
# return: the Configuration object
sub config {
    my $self = shift;

    return $self->{config};
}

##
# Determine the package name
# return: the package name
sub packageName {
    my $self = shift;

    return $self->{packageName};
}

##
# Determine the name
# return: the name
sub name {
    my $self = shift;

    return $self->{json}->{info}->{name};
}

##
# Obtain this Installable's JSON
# return: JSON
sub installableJson {
    my $self = shift;

    return $self->{json};
}

##
# Determine the customization points defined for this installable
# return: map from name to has as in application JSON, or undef
sub customizationPoints {
    my $self = shift;

    return $self->{json}->{customizationpoints};
}

##
# Determine the role names that this Installable has information about
# return: array of role names
sub roleNames {
    my $self = shift;

    my $rolesJson = $self->{json}->{roles};
    if( $rolesJson ) {
        my @roleNames = keys %$rolesJson;
        return \@roleNames;
    } else {
        return [];
    }
}

##
# Determine the JSON AppConfigurationItems in the role with this name
# $roleName: name of the role
# return: array of JSON AppConfigurationItems
sub appConfigItemsInRole {
    my $self     = shift;
    my $roleName = shift;

    my $ret = $self->{json}->{roles}->{$roleName}->{appconfigitems};
    return $ret;
}

##
# Obtain the filename of the manifest file for a package with a given identifier
# $identifier: the package identifier
# return: the filename
sub manifestFileFor {
    my $identifier = shift;

    return IndieBox::Host::config()->get( 'package.manifestdir' ) . "/$identifier.json";
}

1;
