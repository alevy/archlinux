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
use IndieBox::Host;
use IndieBox::Logging;
use IndieBox::Utils;

my $testSuites = IndieBox::Host::findModulesInDirectory( 'IndieBoxTest\.pm', getcwd() );

##
# Execute this command.
# $testSuiteName: name of the test suite to run
# return: desired exit code
sub run {
    my @args = @_;
    unless( @args ) {
        fatal( 'Must provide name of at least one test suite.' );
    }
    my @toRun = ();

    foreach my $testSuiteName ( @args ) {
        my $testSuitePackage = $testSuites->{$testSuiteName};
        if( !$testSuitePackage && $testSuitePackage !~ m!\.pm$! ) {
            $testSuitePackage = $testSuites->{"$testSuiteName.pm"};
        }
        unless( $testSuitePackage ) {
            fatal( 'Unknown test suite', $testSuiteName );
        }

        my $testSuite = IndieBox::Utils::invokeMethod( $testSuitePackage . '::new', $testSuitePackage );

        push @toRun, $testSuite;
    }
    my $ret = 1;
    foreach my $testSuite ( @toRun ) {
        $ret &= $testSuite->run();
    }
    return $ret;
}

##
# Return help text for this command.
# return: help text
sub help {
    return <<END;
Run a test suite
END
}

##
# Return allowed arguments for this command.
# return: allowed arguments, as string
sub helpArguments {
    return undef;
}

1;
