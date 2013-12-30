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

use IndieBox::App;
use IndieBox::Logging;

use fields qw( packageName app description statesTransitions );

##
# Constructor.
# $packageName: name of the application's package to be tested
# $description: human-readable description of the test
# @_: sequence of CustomizationPointValues, StateChecks and StateTransitions that constitute the test
sub new {
    my $self         = shift;
    my $packageName = shift;
    my $description = shift;
    my @args        = @_;

    unless( $packageName ) {
        fatal( 'AppTest must identify the application package being tested.' );
    }
    if( ref( $packageName )) {
        fatal( 'AppTest package name must be a string.' );
    }
    my $app = new IndieBox::App( $packageName );
    unless( $app ) {
        fatal( 'Cannot load Manifest JSON for app', $app );
    }

    unless( $description ) {
        fatal( 'AppTest must have a description.' );
    }
    if( ref( $description )) {
        fatal( 'AppTest description name must be a string.' );
    }
    my $custPointValues   = [];
    my $statesTransitions = [];

    my $i = 0;
    foreach my $candidate ( @args ) {
        my $candidateRef = ref( $candidate );
        if( $candidateRef eq 'IndieBox::Testing::CustomizationPointValues' ) {
            if( $i == 0 ) {
                push @$custPointValues, $candidate;
            } else {
                fatal( 'CustomizationPointValues must be provided before StateChecks and StateTransitions' );
            }
            
        } elsif( $i % 2 ) {
            unless( $candidateRef eq 'IndieBox::Testing::StateTransition' ) {
                fatal( 'StateChecks and StateTransitions must alternate: expected StateTransition' );
            }
            push @$statesTransitions, $candidate;
            ++$i;
        } else {
            unless( $candidateRef eq 'IndieBox::Testing::StateCheck' ) {
                fatal( 'StateChecks and StateTransitions must alternate: expected StateCheck' );
            }
            push @$statesTransitions, $candidate;
            ++$i;
        }
    }    
    
    unless( @$statesTransitions % 2 ) {
        fatal( 'StateChecks and StateTransitions must alternate and end with a StateCheck.' );
    }

    unless( ref( $self )) {
        $self = fields::new( $self );
    }
    $self->{packageName}       = $packageName;
    $self->{app}               = $app;
    $self->{description}       = $description;
    $self->{statesTransitions} = $statesTransitions;

    return $self;
}

##
# Obtain the package name
# return: the package name
sub packageName {
    my $self = shift;

    return $self->{packageName};
}

##
# Obtain the description
# return: the description
sub description {
    my $self = shift;

    return $self->{description};
}

##
# Obtain the app that is being tested.
# return: the app
sub getApp {
    my $self = shift;

    return $self->{app};
}

##
# Obtain the StateTest for the virgin state
# return: the StateTest
sub getVirginStateTest {
    my $self = shift;

    return $self->{statesTransitions}->[0];
}

##
# Obtain the outgoing StateTransition from this State. May return undef.
# $state the starting state
# return: the Transition, or undef
sub getTransitionFrom {
    my $self  = shift;
    my $state = shift;

    for( my $i=0 ; $i<@{$self->{statesTransitions}} ; ++$i ) {
        if( $state == $self->{statesTransitions}->[$i] ) {
            return ( $self->{statesTransitions}->[$i+1], $self->{statesTransitions}->[$i+2] );
        }
    }
    return undef;
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

##
# Obtain the name of the StateCheck or StateTransition.
# return: the name
sub getName {
    my $self = shift;

    return $self->{name};
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
# $c: the TestContext
# return: 1 if check passed
sub check {
    my $self = shift;
    my $c    = shift;

    my $ret = 0;
    unless( eval { $ret = &{$self->{function}}( $c ); } ) {
        error( 'State', $self->{name}, ':', $@ );
        $ret = 0;
    }
        
    return $ret;
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

##
# Execute the state transition
# return: 1 if check passed
sub execute {
    my $self = shift;

    my $ret = 0;
    unless( eval { $ret = &{$self->{function}}(); } ) {
        error( 'StateTransition', $self->{name}, ':', $@ );
        $ret = 0;
    }
        
    return $ret;
}

1;
