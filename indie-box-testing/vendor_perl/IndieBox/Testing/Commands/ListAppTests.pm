#!/usr/bin/perl
#
# Command that lists all available tests in the current directory.
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

package IndieBox::Testing::Commands::ListAppTests;

use Cwd;
use IndieBox::Logging;
use IndieBox::Host;
use IndieBox::Testing::TestingUtils;
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

    my $appTestCandidates = IndieBox::Testing::TestingUtils::readFilesInDirectory( getcwd(), 'AppTest\.pm$' );
    my $appTests = {};
    
    while( my( $fileName, $content ) = each %$appTestCandidates ) {
        my $appTest = eval $content;

        if( defined( $appTest ) && ref( $appTest ) eq 'IndieBox::Testing::AppTest' ) {
            $appTests->{$fileName} = $appTest;

        } elsif( $@ ) {
            error( 'Failed to parse', $fileName, ':', $@ );
            
        } else {
            info( 'Skipping', $fileName, '-- not an AppTest' );
        }
    }
    foreach my $fileName ( keys %$appTests ) {
        my $appTest = $appTests->{$fileName};
        
        printf "%-8s - %s\n", $fileName, $appTest->description();
    }
    1;
}

##
# Return help text for this command.
# return: help text
sub help {
    return <<END;
Lists the available app tests in this directory.
END
}

##
# Return allowed arguments for this command.
# return: allowed arguments, as string
sub helpArguments {
    return undef;
}

1;
