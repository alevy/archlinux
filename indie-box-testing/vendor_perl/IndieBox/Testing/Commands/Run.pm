#!/usr/bin/perl
#
# Command that runs a TestSuite.
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

package IndieBox::Testing::Commands::Run;

use Cwd;
use Getopt::Long qw( GetOptionsFromArray );
use IndieBox::Host;
use IndieBox::Logging;
use IndieBox::Utils;

##
# Execute this command.
# $testSuiteName: name of the test suite to run
# return: desired exit code
sub run {
    my @args = @_;

    my $interactive;
    my $scaffoldName;
    my $testPlanName;
    my $parseOk = GetOptionsFromArray(
            \@args,
            'interactive' => \$interactive,
            'scaffold=s'  => \$scaffoldName,
            'testplan=s'  => \$testPlanName );

    unless( @args ) {
        fatal( 'Must provide name of at least one test suite.' );
    }

    unless( $scaffoldName ) {
        $scaffoldName  = 'here';
    }
    my $scaffoldPackageName = IndieBox::Testing::TestingUtils::findScaffold( $scaffoldName );
    unless( $scaffoldPackageName ) {
        fatal( 'Cannot find scaffold', $scaffoldName );
    }

    unless( $testPlanName ) {
        $testPlanName  = 'default';
    }
    my $testPlanPackage = IndieBox::Testing::TestingUtils::findTestPlan( $testPlanName );
    unless( $testPlanPackage ) {
        fatal( 'Cannot find test plan', $testPlanName );
    }

    my @appTestsToRun = ();
    foreach my $appTestName ( @args ) {
        my $appTestToRun = IndieBox::Testing::TestingUtils::findAppTestInDirectory( getcwd(), $appTestName );
        unless( $appTestToRun ) {
            fatal( 'Cannot find app test', $appTestName );
        }
        push @appTestsToRun, $appTestToRun;
    }
    
    my $ret = 1;

    my $testPlan = IndieBox::Utils::invokeMethod( $testPlanPackage     . '::new',   $testPlanPackage );

    my $scaffold = IndieBox::Utils::invokeMethod( $scaffoldPackageName . '::setup', $scaffoldPackageName );
    foreach my $appTest ( @appTestsToRun ) {
        $testPlan->run( $appTest, $scaffold, $interactive );
    }

    $scaffold->teardown();

    return $ret;
}

##
# Return help text for this command.
# return: help text
sub help {
    return <<END;
Run a test.
END
}

##
# Return allowed arguments for this command.
# return: allowed arguments, as string
sub helpArguments {
    return <<END;
[ --interactive ] [ --scaffold <scaffold> ] [ --testplan <testplan> ] <apptest>... 
END
}

1;
