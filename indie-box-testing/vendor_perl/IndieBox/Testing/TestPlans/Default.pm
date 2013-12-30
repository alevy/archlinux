#!/usr/bin/perl
#
# Default test plan: walks through the states and transitions, and attempts to restore.
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

package IndieBox::Testing::TestPlans::Default;

use base qw( IndieBox::Testing::AbstractSingleSiteTestPlan );
use fields;
use IndieBox::Logging;
use IndieBox::Testing::TestContext;
use IndieBox::Utils;

##
# Instantiate the TestPlan.
sub new {
    my $self = shift;

    unless( ref $self ) {
        $self = fields::new( $self );
    }
    $self = $self->SUPER::new();

    return $self;
}

##
# Run this TestPlan
# $test: the AppTest to run
# $scaffold: the Scaffold to use
sub run {
    my $self     = shift;
    my $test     = shift;
    my $scaffold = shift;

    info( 'Running TestPlan Default' );

    my $appConfigJson = $self->_createAppConfiurationJson( $test );
    my $siteJson      = $self->_createSiteJson( $test, $appConfigJson );

    my $ret = 1;
    
    $ret &= $scaffold->deploy( $siteJson );

    my $c = new IndieBox::Testing::TestContext( $siteJson, $appConfigJson, $scaffold, $test, $self, $scaffold->getTargetIp() );

    my $currentState = $test->getVirginStateTest();

    my @statesBackupsReverse = ();

    # March forward, and create backups
    while( 1 ) {
        info( 'Checking StateCheck', $currentState->getName() );

        $ret &= $currentState->check( $c );

        my $backup = $scaffold->backup( $siteJson );
        unshift @statesBackupsReverse, [ $currentState, $backup ]; # insert at the beginning

        my( $transition, $nextState ) = $test->getTransitionFrom( $currentState );

        unless( $transition ) {
            last;
        }
    
        info( 'Taking StateTransition', $transition->getName() );

        $ret &= $transition->execute( $c );

        $currentState = $nextState;
    }

    # March backwards, restore from backups
    foreach my $stateBackup ( @statesBackupsReverse ) {
        my( $currentState, $currentBackup ) = @$stateBackup;

        if( $currentBackup ) {
            info( 'Restoring and checking StateCheck', $currentState->getName() );

            $scaffold->restore( $siteJson, $currentBackup );
            
            $ret &= $currentState->check( $c );

        } else {
            debug( 'Skipping restoring and checking StateCheck', $currentState->getName() );
        }
    }

    # And then do the last one again, because it wasn't fair to restore the current
    # state
    if( @statesBackupsReverse > 1 ) {
        my( $currentState, $currentBackup ) = @{$statesBackupsReverse[0]};
        if( $currentBackup ) {
            info( 'Restoring and checking (one more time) StateCheck', $currentState->getName() );

            $scaffold->restore( $siteJson, $currentBackup );
            
            $ret &= $currentState->check( $c );

        } else {
            debug( 'Skipping restoring and checking StateCheck', $currentState->getName() );
        }
    }

    $scaffold->undeploy( $siteJson );
    
    $c->destroy();

    foreach my $stateBackup ( @statesBackupsReverse ) {
        my( $currentState, $currentBackup ) = @$stateBackup;

        if( $currentBackup ) {
            $scaffold->destroyBackup( $siteJson, $currentBackup );
        }
    }

    info( 'End running TestPlan Default' );

    return $ret;
}

##
# Return help text.
# return: help text
sub help {
    return 'Walks through all States and Transitions, and attempts to backup and restore each State.';
}

##
# Return allowed arguments for this command.
# return: allowed arguments, as string
sub helpArguments {
    return undef;
}

1;


