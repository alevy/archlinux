#!/usr/bin/perl
#
# Provides the StateCheck and StateTransition abstractions for writing
# Indie Box tests.
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

package IndieBox::Testing::AppTest;

use IndieBox::Logging;

use fields qw( packageName description statesTransitions );

##
# Constructor.
# $packageName: name of the application's package to be tested
# $description: human-readable description of the test
# @_: sequence of StateChecks and StateTransitions that constitute the test
sub new {
    my $self              = shift;
    my $packageName       = shift;
    my $description       = shift;
    my @statesTransitions = @_;

    unless( $packageName ) {
        fatal( 'AppTest must identify the application package being tested.' );
    }
    if( ref( $packageName )) {
        fatal( 'AppTest package name must be a string.' );
    }
    unless( $description ) {
        fatal( 'AppTest must have a description.' );
    }
    if( ref( $description )) {
        fatal( 'AppTest description name must be a string.' );
    }
    unless( @statesTransitions ) {
        fatal( 'AppTest must define at least one StateCheck.' );
    }
    for( my $i=0 ; $i<@statesTransitions ; ++$i ) {
        if( $i % 2 ) {
            unless( ref( $statesTransitions[$i] ) eq 'IndieBox::Testing::StateTransition' ) {
                fatal( 'Entry', $i, 'in states and transition array must be a StateTransition (StateChecks and StateTransitions must alternate)' );
            }
        } else {
            unless( ref( $statesTransitions[$i] ) eq 'IndieBox::Testing::StateCheck' ) {
                fatal( 'Entry', $i, 'in states and transition array must be a StateCheck (StateChecks and StateTransitions must alternate)' );
            }
        }
    }
    unless( @statesTransitions % 2 ) {
        fatal( 'AppTest states and transitions array must end with a StateCheck.' );
    }

    unless( ref( $self )) {
        $self = fields::new( $self );
    }
    $self->{packageName}       = $packageName;
    $self->{description}       = $description;
    $self->{statesTransitions} = \@statesTransitions;

    return $self;
}

##
# Obtain the description
# return: the description
sub description {
    my $self = shift;

    return $self->{description};
}

################################################################################

package IndieBox::Testing::StatesTransitions;

use fields qw( name function );

##
# Superclass constructor.
# $name: name of the state
# $function: subroutine to check this state
sub new {
    my $self     = shift;
    my $name     = shift;
    my $function = shift;

    unless( ref $self ) {
        $self = fields::new( $self );
    }
    $self->{name}     = $name;
    $self->{function} = $function;

    return $self;
}

################################################################################

package IndieBox::Testing::StateCheck;

use base qw( IndieBox::Testing::StatesTransitions );
use fields;
use IndieBox::Logging;

##
# Instantiate the StateCheck.
# $name: name of the state
# $function: subroutine to check this state
sub new {
    my $self     = shift;
    my $name     = shift;
    my $function = shift;

    unless( $name ) {
        fatal( 'All StateChecks must have a name.' );
    }
    if( ref( $name )) {
        fatal( 'A StateCheck\'s name must be a string.' );
    }
    unless( $function ) {
        fatal( 'All StateChecks must have a check function.' );
    }
    unless( ref( $function ) eq 'CODE' ) {
        fatal( 'A StateCheck\'s check function must be a Perl subroutine.' );
    }

    unless( ref $self ) {
        $self = fields::new( $self );
    }
    $self->SUPER::new( $name, $function );

    return $self;
}

##
# Check this state
sub check {
    my $self = shift;

}

################################################################################

package IndieBox::Testing::StateTransition;

use base qw( IndieBox::Testing::StatesTransitions );
use fields;
use IndieBox::Logging;

##
# Instantiate the StateTransition.
# $name: name of the transition
# $function: subroutine to move to the next state
sub new {
    my $self     = shift;
    my $name     = shift;
    my $function = shift;

    unless( ref $self ) {
        $self = fields::new( $self );
    }
    $self->SUPER::new( $name, $function );

    return $self;
}

1;
