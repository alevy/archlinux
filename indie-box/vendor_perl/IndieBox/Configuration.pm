#!/usr/bin/perl
#
# Run-time configuration for Indie Box Project
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

package IndieBox::Configuration;

use IndieBox::Logging;
use IndieBox::Utils qw( readJsonFromFile );
use JSON;
use fields;

my $confFile = '/etc/indie-box/config.json';
my $values   = undef;

##
# Obtain a configuration value. This will not resolve symbolic references in the value.
# $name: name of the configuration value
# $default: value returned if the configuration value has not been set
# return: the value, or default value
sub get {
    my $name    = shift;
    my $default = shift;

    _initialize();

    return $values->{$name} || $default;
}

##
# Obtain a configuration value, and recursively resolve symbolic references in the value.
# $name: name of the configuration value
# $default: value returned if the configuration value has not been set
# $map: location of additional name-value pairs
# return: the value, or default value
sub getResolve {
    my $name           = shift;
    my $default        = shift;
    my $map            = shift || {};
    my $remainingDepth = shift || 16;

    my $ret = $map->{$name};
    unless( $ret ) {
        $ret = $values->{$name};
    }
    if( $ret ) {
        if( $remainingDepth > 0 ) {
            $ret =~ s/(?<!\\)\$\{\s*([^\}\s]+)\s*\}/getResolve( $1, undef, $map, $remainingDepth-1 )/ge;
        }
    } else {
        die( "Cannot find variable $name" );
    }

    return $ret;
}

##
# Replace all variables in the string values in this hash with configuration values.
# $map: the hash
# $
# return: the same hash
sub replaceVariables {
    my $value       = shift;
    my $toplevelMap = shift || ( ref( $value ) eq 'HASH' ? $value : {} );

    if( ref( $value ) eq 'HASH' ) {
        while( my( $key2, $value2 ) = each %$value ) {
            replaceVariables( $value2, $toplevelMap );
        }

    } elsif( ref( $value ) eq 'ARRAY' ) {
        foreach my $value2 ( @$value ) {
            replaceVariables( $value2, $toplevelMap );
        }
    } else {
        $value =~ s/(?<!\\)\$\{\s*([^\}\s]+)\s*\}/getResolve( $1, undef, $toplevelMap, 16 )/ge;
    }
    return $value;
}

##
# Obtain the filename of the manifest file for a package with a given identifier
# $identifier: the package identifier
# return: the filename
sub manifestFileFor {
    my $identifier = shift;

    return get( 'package.manifestdir' ) . "/$identifier.json";
}

##
# Read configuration values if needed.
sub _initialize {
    unless( $values ) {
        my $raw = readJsonFromFile( $confFile );

        # turn hierarchical JSON into flat hierarchical strings
        $values = _flatten( $raw );
    }
}

##
# Recursive helper to flatten JSON into hierarchical variable names
# $map: JSON, or sub-JSON
# return: array of hierarchical variables names (may be sub-hierarchy)
sub _flatten {
    my $map = shift;
    my $ret = {};

    while( my( $key, $value ) = each %$map ) {
        if( ref( $value ) eq 'HASH' ) {
            my $subRet = _flatten( $value );
            while( my( $foundKey, $foundValue ) = each %$subRet ) {
                $ret->{"$key.$foundKey"} = $foundValue;
            }
        } else {
            $ret->{$key} = $value;
        }
    }

    return $ret;
}

1;
