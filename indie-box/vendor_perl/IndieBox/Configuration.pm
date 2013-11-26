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
use IndieBox::Utils;
use JSON;
use fields qw( name hierarchicalMap flatMap delegates );

##
# Constructor.
# $name: name for this Configuration object. This helps with debugging.
# $hierarchicalMap: map of name to value (which may be another map)
# @delegates: more Configuration objects which may be used to resolve unknown variables
sub new {
    my $self            = shift;
    my $name            = shift;
    my $hierarchicalMap = shift;
    my @delegates       = @_;

    unless( ref $self ) {
        $self = fields::new( $self );
    }
    $self->{name}            = $name;
    $self->{hierarchicalMap} = $hierarchicalMap;
    $self->{flatMap}         = _flatten( $hierarchicalMap );
    $self->{delegates}       = \@delegates;

    return $self;
}

##
# Obtain a configuration value. This will not resolve symbolic references in the value.
# $name: name of the configuration value
# $default: value returned if the configuration value has not been set
# return: the value, or default value
sub get {
    my $self           = shift;
    my $name           = shift;
    my $default        = shift;
    my $remainingDepth = shift || 16;

    my $ret;
    my $found = $self->{flatMap}->{$name};
    if( defined( $found )) {
        $ret = $found;
    } else {
        foreach my $delegate ( @{$self->{delegates}} ) {
            $ret = $delegate->get( $name, undef, $remainingDepth-1 );
            if( defined( $ret )) {
                last;
            }
        }
    }
#    if( defined( $ret )) {
#        trace( ( '  ' x ( 16-$remainingDepth)), "Configuration::get( ", $self->{name}, ", ", $name, ", ", $remainingDepth, " ) -> ", $ret, "\n" );
#    } else {
#        trace( ( '  ' x ( 16-$remainingDepth)), "Configuration::get( ", $self->{name}, ", ", $name, ", ", $remainingDepth, " ) -> <undef>\n" );
#    }
    return $ret;
}

##
# Add an additional configuration value. This will fail if the name exists already.
# $name: name of the configuration value
# $value: value of the configuration value
sub put {
    my $self  = shift;
    my $name  = shift;
    my $value = shift;

    if( !defined( $self->{flatMap}->{$name} )) {
        $self->{flatMap}->{$name} = $value;
    } else {
        error( 'Have value already for', $name );
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

#    trace( ( '  ' x ( 16-$remainingDepth)), "Attempting to Configuration::getResolve( ", $self->{name}, ", ", $name, " )\n" );

    my $func = undef;
    if( $name =~ m!([^\s]+)\s*\(\s*([^\s]+)\s*\)! ) {
        $func = $1;
        $name = $2;
    }
    my $ret = $self->get( $name, $default, $remainingDepth-1 );
    if( defined( $ret )) {
        if( $remainingDepth > 0 ) {
            $ret =~ s/(?<!\\)\$\{\s*([^\}\s]+(\s+[^\}\s]+)*)\s*\}/$self->getResolve( $1, undef, $unresolvedOk, $remainingDepth-1 )/ge;
        }
        if( defined( $func )) {
            $ret = _applyFunc( $func, $ret );
        }
    } elsif( !$unresolvedOk ) {
        fatal( 'Cannot find variable', $name, "\n" . $self->dump() );
    } else {
        $ret = '${' . $name . '}';
    }

#    if( defined( $ret )) {
#        trace( ( '  ' x ( 16-$remainingDepth)), "Configuration::getResolve( ", $self->{name}, ", ", $name, ", ", $remainingDepth, " ) -> ", $ret, "\n" );
#    } else {
#        trace( ( '  ' x ( 16-$remainingDepth)), "Configuration::getResolve( ", $self->{name}, ", ", $name, ", ", $remainingDepth, " ) -> <undef>\n" );
#    }
    return $ret;
}

##
# Obtain a configuration value, and recursively resolve symbolic references in the value.
# $name: name of the configuration value
# $default: value returned if the configuration value has not been set
# $map: location of additional name-value pairs
# $unresolvedOk: if true, and a variable cannot be replaced, leave the variable and continue; otherwise die
# $remainingDepth: remaining recursion levels before abortion
# return: the value, or default value
sub getResolveOrNull {
    my $self           = shift;
    my $name           = shift;
    my $default        = shift;
    my $unresolvedOk   = shift || 0;
    my $remainingDepth = shift || 16;

#    trace( ( '  ' x ( 16-$remainingDepth)), "Attempting to Configuration::getResolveOrNull( ", $self->{name}, ", ", $name, " )\n" );

    my $func = undef;
    if( $name =~ m!([^\s]+)\s*\(\s*([^\s]+)\s*\)! ) {
        $func = $1;
        $name = $2;
    }
    my $ret = $self->get( $name, $default, $remainingDepth-1 );
    if( defined( $ret )) {
        if( $remainingDepth > 0 ) {
            $ret =~ s/(?<!\\)\$\{\s*([^\}\s]+(\s+[^\}\s]+)*)\s*\}/$self->getResolve( $1, undef, $unresolvedOk, $remainingDepth-1 )/ge;
        }
        if( defined( $func )) {
            $ret = _applyFunc( $func, $ret );
        }
    } elsif( !$unresolvedOk ) {
        fatal( 'Cannot find variable', $name, "\n" . $self->dump() );
    } else {
        $ret = undef;
    }
#    if( defined( $ret )) {
#        trace( ( '  ' x ( 16-$remainingDepth)), "Configuration::getResolveOrNull( ", $self->{name}, ", ", $name, ", ", $remainingDepth, " ) -> ", $ret, "\n" );
#    } else {
#        trace( ( '  ' x ( 16-$remainingDepth)), "Configuration::getResolveOrNull( ", $self->{name}, ", ", $name, ", ", $remainingDepth, " ) -> <undef>\n" );
#    }
    return $ret;
}

##
# Obtain the keys in this Configuration object.
# return: the keys
sub keys {
    my $self = shift;

    my $uniq = {};
    foreach my $key ( keys %{$self->{flatMap}} ) {
        $uniq->{$key} = 1;
    }
    foreach my $delegate ( @{$self->{delegates}} ) {
        foreach my $key ( $delegate->keys() ) {
            $uniq->{$key} = 1;
        }
    }
    return keys %$uniq;
}

##
# Replace all variables in the string values in this hash with the values from this Configuration object.
# $value: the hash, array or string
# $unresolvedOk: if true, and a variable cannot be replaced, leave the variable and continue; otherwise die
# $remainingDepth: remaining recursion levels before abortion
# return: the same $value
sub replaceVariables {
    my $self           = shift;
    my $value          = shift;
    my $unresolvedOk   = shift || 0;
    my $remainingDepth = shift || 16;

#    trace( ( '  ' x ( 16-$remainingDepth)), "Attempting to Configuration::replaceVariables( ", $self->dump(), " )" );

    my $ret;
    if( ref( $value ) eq 'HASH' ) {
        $ret = {};
        while( my( $key2, $value2 ) = each %$value ) {
            my $newValue2 = $self->replaceVariables( $value2, $unresolvedOk, $remainingDepth-1 );
            $ret->{$key2} = $newValue2;
        }

    } elsif( ref( $value ) eq 'ARRAY' ) {
        $ret = [];
        foreach my $value2 ( @$value ) {
            my $newValue2 = $self->replaceVariables( $value2, $unresolvedOk, $remainingDepth-1 );
            push @$ret, $newValue2
        }
    } elsif( $value ) {
        $ret = $value;
        $ret =~ s/(?<!\\)\$\{\s*([^\}\s]+(\s+[^\}\s]+)*)\s*\}/$self->getResolveOrNull( $1, undef, $unresolvedOk, $remainingDepth-1 )/ge;
    } else {
        $ret = undef;
    }
#    trace( ( '  ' x ( 16-$remainingDepth)), "Configuration::replaceVariables( ", $self->{name}, ', ', $unresolvedOk, ', ', $remainingDepth, " )" );

    return $ret;
}

##
# Dump this Configuration to string
sub dump {
    my $self = shift;

    my $ret = "Configuration( " . $self->{name} . ",\n" . join( '', map
        {
            my $key   = $_;
            my $value = $self->getResolve( $_, undef, 1 );
            if( defined( $value )) {
                "    $_ => $value\n";
            } else {
                "    $_ => <undef>\n";
            }
        } sort $self->keys() ) . ")";
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

##
# Helper method to apply a named function to a value
# $func: the named function
# $value: the value to apply the function to
# return: the value, after having been processed by the function
sub _applyFunc {
    my $func  = shift;
    my $value = shift;

    my $ret = $value;
    if( 'escapeSquote' eq $func ) {
        $ret =~ s/'/\\'/g;
    } elsif( 'escapeDquote' eq $func ) {
        $ret =~ s/"/\\"/g;
    } elsif( 'trim' eq $func ) {
        $ret =~ s/^\s*//g;
        $ret =~ s/\s*$//g;
    } elsif( 'cr2space' eq $func ) {
        $ret =~ s/\s+/ /g;
    } else {
        error( 'Unknown function', $func, 'in varsubst' );
    }
    return $ret;
}

1;
