#!/usr/bin/perl
#
# Command that lists all available Scaffolds.
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

package IndieBox::Testing::Commands::ListScaffolds;

use IndieBox::Host;
use IndieBox::Utils;

##
# Execute this command.
# @args: arguments to this command
# return: desired exit code
sub run {
    my @args = @_;
    if( @args ) {
        fatal( 'No arguments are recognized for this command' );
    }

    my $scaffolds = IndieBox::Testing::TestingUtils::findScaffolds();
    IndieBox::Testing::TestingUtils::printHashAsColumns( $scaffolds, sub { IndieBox::Utils::invokeMethod( shift . '::help' ); } );

    1;
}

##
# Return help text for this command.
# return: hash of synopsis to help text
sub synopsisHelp {
    return {
        '' => <<HHH
    Lists all available scaffolds.
HHH
    };
}

1;
