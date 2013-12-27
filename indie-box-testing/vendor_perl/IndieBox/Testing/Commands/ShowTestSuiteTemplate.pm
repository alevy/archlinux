#!/usr/bin/perl
#
# Command that shows details on a test suite.
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

package IndieBox::Testing::Commands::ShowTestSuiteTemplate;

use IndieBox::Logging;
use IndieBox::Utils;

##
# Execute this command.
# @args: arguments to this command
# return: desired exit code
sub run {
    my @args = @_;
    unless( @args eq 1 ) {
        fatal( 'Must provide name of exactly one test suite template.' );
    }

    my $templateName = shift @args;

    my $templates       = IndieBox::Host::findPerlShortModuleNamesInPackage( 'IndieBox::Testing::TestSuiteTemplates' );
    my $templatePackage = $templates->{$templateName};

    unless( $templatePackage ) {
        fatal( 'Cannot find test suite template named', $templateName );
    }

    my $steps = IndieBox::Utils::invokeMethod( $templatePackage . '::steps' );
    
    print "Test suites using this template will perform the following steps:\n";

    my $i=1;
    foreach my $step ( @$steps ) {
        my $text = $step->[1];
        $text =~ s!^!\n        !g;
        $text =~ s!^\s+!!;
        printf( "  %2d: %-32s %s\n", $i++, $step->[0], $text );
    }
    
    1;
}

##
# Return help text for this command.
# return: help text
sub help {
    return <<END;
Shows details on a named test suite template.
END
}

##
# Return allowed arguments for this command.
# return: allowed arguments, as string
sub helpArguments {
    return ( '<test-suite-template-name>' );
}

1;





