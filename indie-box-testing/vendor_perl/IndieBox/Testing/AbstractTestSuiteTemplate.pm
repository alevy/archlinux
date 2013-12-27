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
# Deploy the configuration to be tested.
sub runDeployConfigurationStep {
    my $self = shift;

    print( "TODO: runDeployConfigurationStep\n" );

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
sub undeployConfigurationStep {
    my $self = shift;

    print( "TODO: undeployConfigurationStep\n" );

    return 1;
}

##
# Check the content of the logs
sub checkLogs {
    my $self = shift;

    print( "TODO: checkLogs\n" );

    return 1;
}

1;
