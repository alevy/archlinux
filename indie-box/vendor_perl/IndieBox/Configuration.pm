#!/usr/bin/perl
#
# Run-time configuration for Indie Box Project
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

package IndieBox::Configuration;

use IndieBox::Logging;
use IndieBox::Utils qw( readJsonFromFile );
use JSON;
use fields qw( hierarchicalMap flatMap delegate );

##
# Constructor.
# $hierarchicalMap: map of name to value (which may be another map)
# $delegate: another Configuration object which may be used to resolve unknown variables
sub new {
    my $self            = shift;
    my $hierarchicalMap = shift;
    my $delegate        = shift;

    unless( ref $self ) {
        $self = fields::new( $self );
    }
    $self->{hierarchicalMap} = $hierarchicalMap;
    $self->{flatMap}         = _flatten( $hierarchicalMap );
    $self->{delegate}        = $delegate;

    return $self;
}

##
# Obtain a configuration value. This will not resolve symbolic references in the value.
# $name: name of the configuration value
# $default: value returned if the configuration value has not been set
# return: the value, or default value
sub get {
    my $self    = shift;
    my $name    = shift;
    my $default = shift;

    my $found = $self->{flatMap}->{$name};
    if( defined( $found )) {
        return $found;
    }
    if( $self->{delegate} ) {
        return $self->{delegate}->get( $name, $default );
    } else {
        return $default;
    }
}

##
# Obtain a configuration value, and recursively resolve symbolic references in the value.
# $name: name of the configuration value
# $default: value returned if the configuration value has not been set
# $map: location of additional name-value pairs
# $unresolvedOk: if true, and a variable cannot be replaced, leave the variable and continue; otherwise die
# $remainingDepth: remaining recursion levels before abortion
# return: the value, or default value
sub getResolve {
    my $self           = shift;
    my $name           = shift;
    my $default        = shift;
    my $unresolvedOk   = shift || 0;
    my $remainingDepth = shift || 16;

    my $ret = $self->get( $name, $default );
    if( defined( $ret )) {
        if( $remainingDepth > 0 ) {
            $ret =~ s/(?<!\\)\$\{\s*([^\}\s]+)\s*\}/$self->getResolve( $1, undef, $unresolvedOk, $remainingDepth-1 )/ge;
        }
    } elsif( !$unresolvedOk ) {
        die( "Cannot find variable $name" );
    } else {
        $ret = '${' . $name . '}';
    }
    return $ret;
}

##
# Obtain the keys in this Configuration object.
# return: the keys
sub keys {
    my $self = shift;

    my @ret = keys %{$self->{flatMap}};
    if( $self->{delegate} ) {
        push @ret, $self->{delegate}->keys();
    }
    return @ret;
}

##
# Replace all variables in the string values in this hash with the values from this Configuration object.
# $value: the hash, array or string
# $unresolvedOk: if true, and a variable cannot be replaced, leave the variable and continue; otherwise die
# return: the same $value
sub replaceVariables {
    my $self         = shift;
    my $value        = shift;
    my $unresolvedOk = shift || 0;

    my $ret;
    if( ref( $value ) eq 'HASH' ) {
        $ret = {};
        while( my( $key2, $value2 ) = each %$value ) {
            my $newValue2 = $self->replaceVariables( $value2, $unresolvedOk );
            $ret->{$key2} = $newValue2;
        }

    } elsif( ref( $value ) eq 'ARRAY' ) {
        $ret = [];
        foreach my $value2 ( @$value ) {
            my $newValue2 = $self->replaceVariables( $value2, $unresolvedOk );
            push @$ret, $newValue2
        }
    } else {
        $ret = $value;
        $ret =~ s/(?<!\\)\$\{\s*([^\}\s]+)\s*\}/$self->getResolve( $1, undef, $unresolvedOk )/ge;
    }
    return $ret;
}

##
# Dump this Configuration to string
sub dump {
    my $self = shift;

    my $ret = join( '', map
        {
            my $key   = $_;
            my $value = $self->getResolve( $_, undef, 1 );
            if( defined( $value )) {
                "$_ => $value\n";
            } else {
                "$_ => <undef>\n";
            }
        } sort $self->keys() );
    return $ret;
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
