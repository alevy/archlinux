#!/usr/bin/perl
#
# Provides the StateCheck and StateTransition abstractions for writing
# Indie Box tests.
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

package IndieBox::Testing::AppTest;

use IndieBox::App;
use IndieBox::Logging;

use fields qw( name description packageName app hostname customizationPointValues statesTransitions );

##
# Constructor.
# $packageName: name of the application's package to be tested
# $description: human-readable description of the test
# @_: parameters
sub new {
    my $self = shift;
    my %pars = @_;
    
    my $description       = $pars{description};
    my $packageName       = $pars{appToTest};
    my $name              = $pars{name} || ( 'Testing app ' . $packageName );
    my $custPointValues   = $pars{customizationPointValues};
    my $statesTransitions = $pars{checks};
    my $hostname          = $pars{hostname};

    unless( $packageName ) {
        fatal( 'AppTest must identify the application package being tested. Use parameter named "appToTest".' );
    }
    if( ref( $packageName )) {
        fatal( 'AppTest package name must be a string.' );
    }
    my $app = new IndieBox::App( $packageName );
    unless( $app ) {
        fatal( 'Cannot load Manifest JSON for app', $app );
    }

    if( ref( $name )) {
        fatal( 'AppTest name name must be a string.' );
    }
    if( ref( $description )) {
        fatal( 'AppTest description name must be a string.' );
    }
    if( $custPointValues ) {
        if( ref( $custPointValues ) ne 'HASH' ) {
            fatal( 'CustomizationPointValues must be a hash' );
        }
        while( my( $name, $value ) = each %$custPointValues ) {
            if( ref( $name ) || ref( $value )) {
                fatal( 'CustomizationPointValues must be a hash with simple name-value pairs in it.' );
            }
        }
    }
    if( !$statesTransitions || !@$statesTransitions ) {
        fatal( 'AppTest must provide at least a StateCheck for the virgin state' );
    }

    my $i = 0;
    foreach my $candidate ( @$statesTransitions ) {
        my $candidateRef = ref( $candidate );
        if( $i % 2 ) {
            unless( $candidateRef eq 'IndieBox::Testing::StateTransition' ) {
                fatal( 'Array of StateChecks and StateTransitions must alternate: expected StateTransition' );
            }
        } else {
            unless( $candidateRef eq 'IndieBox::Testing::StateCheck' ) {
                fatal( 'Array of StateChecks and StateTransitions must alternate: expected StateCheck' );
            }
        }
        ++$i;
    }    
    
    unless( @$statesTransitions % 2 ) {
        fatal( 'Array of StateChecks and StateTransitions must alternate and end with a StateCheck.' );
    }

    unless( ref( $self )) {
        $self = fields::new( $self );
    }
    $self->{name}                     = $name;
    $self->{description}              = $description;
    $self->{packageName}              = $packageName;
    $self->{app}                      = $app;
    $self->{hostname}                 = $hostname;
    $self->{customizationPointValues} = $custPointValues;
    $self->{statesTransitions}        = $statesTransitions;

    return $self;
}

##
# Obtain the name of the text
# return: name
sub name {
    my $self = shift;

    return $self->{name};
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
# Obtain the desired hostname at which to test.
# return: hostname
sub hostname {
    my $self = shift;

    return $self->{hostname};
}

##
# Obtain the customization point values as a hash, if any
# return: hash, or undef
sub getCustomizationPointValues {
    my $self = shift;

    return $self->{customizationPointValues};
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
# $pars{name}: name of the state
# $pars{function}: subroutine to check this state
sub new {
    my $self = shift;
    my %pars = @_;

    my $name     = $pars{name};
    my $function = $pars{check};

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

    $c->clearHttpSession(); # always before a new StateCheck
                        
    my $ret    = eval { &{$self->{function}}( $c ); };
    my $errors = $c->errorsAndClear;
    my $msg    = 'failed.';
    
    if( $errors ) {
        $ret = 0;
    } elsif( $@ ) {
        $msg = $@;
    } else {
        $msg = 'return value 0.';
    }

    unless( $ret ) {
        error( 'StateCheck', $self->{name}, ':', $msg );
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
# $pars{name}: name of the state
# $pars{function}: subroutine to check this state
sub new {
    my $self     = shift;
    my %pars = @_;

    my $name     = $pars{name};
    my $function = $pars{transition};

    unless( $name ) {
        fatal( 'All StateTransitions must have a name.' );
    }
    if( ref( $name )) {
        fatal( 'A StateTransition\'s name must be a string.' );
    }
    unless( $function ) {
        fatal( 'All StateTransitions must have a transition function.' );
    }
    unless( ref( $function ) eq 'CODE' ) {
        fatal( 'A StateTransition\'s transition function must be a Perl subroutine.' );
    }

    unless( ref $self ) {
        $self = fields::new( $self );
    }
    $self->SUPER::new( $name, $function );

    return $self;
}

##
# Execute the state transition
# $c: the TestContext
# return: 1 if check passed
sub execute {
    my $self = shift;
    my $c    = shift;

    $c->clearHttpSession(); # always before a new StateTransition

    my $ret    = eval { &{$self->{function}}( $c ); };
    my $errors = $c->errorsAndClear;
    my $msg    = 'failed.';

    if( $errors ) {
        $ret = 0;
    } elsif( $@ ) {
        $msg = $@;
        $ret = 0;
    } elsif( !$ret ) {
        $msg = 'return value 0.';
    }

    unless( $ret ) {
        error( 'StateTransition', $self->{name}, ':', $msg );
    }
    return $ret;
}

1;
