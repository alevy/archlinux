#!/usr/bin/perl
#
# Command that lists all available test suites in the current directory.
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

package IndieBox::Testing::Commands::ListTestSuites;

use Cwd;
use IndieBox::Host;
use IndieBox::Utils;

my $testSuites = IndieBox::Host::findModulesInDirectory( 'IndieBoxTest\.pm', getcwd() );

##
# Execute this command.
# @args: arguments to this command
# return: desired exit code
sub run {
    my @args = @_;

    while( my( $fileName, $packageName ) = each %$testSuites ) {
        
        my $help = IndieBox::Utils::invokeMethod( $packageName . '::help' );

        printf "%-8s - %s\n", $fileName, $help;
    }
    1;
}

##
# Return help text for this command.
# return: help text
sub help {
    return <<END;
Lists all available test suites in this directory.
END
}

##
# Return allowed arguments for this command.
# return: allowed arguments, as string
sub helpArguments {
    return undef;
}

1;
