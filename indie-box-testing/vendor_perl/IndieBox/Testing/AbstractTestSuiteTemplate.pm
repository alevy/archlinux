#!/usr/bin/perl
#
# Factors out operations common to many kinds of TestSuites.
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

package IndieBox::Testing::AbstractTestSuiteTemplate;

use fields;
use IndieBox::Logging;

##
# Instantiate the TestSuite.
sub new {
    my $self  = shift;

    unless( ref $self ) {
        $self = fields::new( $self );
    }
    return $self;
}

##
# Obtain the steps taken by this test suite. This must be overridden by subclasses.
sub steps {
    fatal( 'Method not overridden: AbstractTestSuiteTemplate->steps()' );
}

##
# Run the TestSuite.
sub run {
    my $self = shift;
    my $ok   = 1;

    my $steps = $self->steps();
    foreach my $step ( @$steps ) {
        my $methodName = $step->[0];
        if( $ok ) {
            $ok = $self->advancingTo( $methodName ) && $self->$methodName();
            unless( $self->checkLogs() ) {
                $ok = 0;
            }
        } else {
            info( 'Skipping step', $methodName );
        }
    }

    return $ok;
}

##
# Advance to the next step. This can be overridden to ask for user permission to proceed, for example.
# $step: the next step
sub advancingTo {
    my $self = shift;
    my $step = shift;

    print "Advancing to: " . $step . "\n";

    return 1;
}

##
# Deploy the configuration to be tested.
sub runDeployStep {
    my $self = shift;

    print( "TODO: runDeployStep\n" );

    return 1;
}

##
# Update all code on the machine
sub runUpdateStep {
    my $self = shift;

    print( "TODO: runUpdateStep\n" );

    return 1;
}

##
# Undeploy the configuration to be tested.
sub runUndeployStep {
    my $self = shift;

    print( "TODO: runUndeployStep\n" );

    return 1;
}

##
# Redeploy the configuration to be tested.
sub runRedeployStep {
    my $self = shift;

    print( "TODO: runRedeployStep\n" );

    return 1;
}

##
# Redeploy a different configuration.
sub runRedeployAlternateStep {
    my $self = shift;

    print( "TODO: runRedeployAlternateStep\n" );

    return 1;
}
    
##
# Create a backup.
sub runBackupStep {
    my $self = shift;

    print( "TODO: runBackupStep\n" );

    return 1;
}

##
# Restore the backup.
sub runRestoreStep {
    my $self = shift;

    print( "TODO: runRestoreStep\n" );

    return 1;
}

##
# Check the content of the logs
sub checkLogs {
    my $self = shift;

    print( "TODO: checkLogs\n" );

    return 1;
}

##
# Invoked if a method is invoked that should be been overridden by the test suite implementation.
# $methodName: name of the method that should have been overridden
sub stepNotImplemented {
    my $self       = shift;
    my $methodName = shift;

    error( "Testsuite should be overriding method $methodName" );

    return 1; # still let the test continue
}

1;
