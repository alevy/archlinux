#!/usr/bin/perl
#
# Collection of utility methods for Indie Box testing.
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

package IndieBox::Testing::TestingUtils;

use Cwd;
use IndieBox::Logging;
use IndieBox::Utils;

##
# Helper method to print name-value pairs, with the value optionally processed
# $hash: hash of first column to second column
# $f: optional method to invoke on the second column before printing

sub printHashAsColumns {
    my $hash = shift;
    my $f    = shift || sub { shift; };

    my $indent = 0;
    foreach my $name ( keys %$hash ) {
        my $length = length( $name );
        if( $length > $indent ) {
            $indent = $length;
        }
    }

    my $s = ' ' x $indent;
    foreach my $name ( sort keys %$hash ) {
        my $obj            = $hash->{$name};
        my $formattedValue = &$f( $obj );
        $formattedValue =~ s!^\s*!$s!gm;
        $formattedValue =~ s!^\s+!!;
        $formattedValue =~ s!\s+$!!;

        printf( '%-' . $indent . "s - %s\n", $name, $formattedValue );
    }
}

##
# Find all AppTests in a directory.
# $dir: directory to look in
# return: hash of file name to AppTest object
sub findAppTestsInDirectory {
    my $dir = shift;
    
    my $appTestCandidates = IndieBox::Utils::readFilesInDirectory( getcwd(), 'AppTest\.pm$' );
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
    return $appTests;
}

##
# Find available commands.
# return: hash of command name to full package name
sub findCommands {
    my $ret = IndieBox::Utils::findPerlShortModuleNamesInPackage( 'IndieBox::Testing::Commands' );

    return $ret;
}

##
# Find available test plans
# return: hash of test plan name to full package name
sub findTestPlans {
    my $ret = IndieBox::Utils::findPerlShortModuleNamesInPackage( 'IndieBox::Testing::TestPlans' );

    return $ret;
}

##
# Find a named test plan
# $name: name of the test plan
# return: test plan template, or undef
sub findTestPlan {
    my $name = shift;

    my $plans = findTestPlans();
    my $ret   = $plans->{$name};

    return $ret;
}

##
# Find available test scaffolds.
# return: hash of scaffold name to full package name
sub findScaffolds {
    my $ret = IndieBox::Utils::findPerlShortModuleNamesInPackage( 'IndieBox::Testing::Scaffolds' );
    return $ret;
}

##
# Find a named scaffold
# $name: name of the scaffold
# return: scaffold package, or undef
sub findScaffold {
    my $name = shift;

    my $scaffolds = findScaffolds();
    my $ret       = $scaffolds->{$name};

    return $ret;
}

##
# Find a named AppTest in a directory.
# $dir: directory to look in
# $name: name of the test
# return: the AppTest object, or undef
sub findAppTestInDirectory {
    my $dir  = shift;
    my $name = shift;

    my $fileName = getcwd() . "/$name";
    if( !-r $fileName && $fileName !~ m!\.pm$! ) {
        $fileName = "$fileName.pm";
    }
    if( -r $fileName ) {
        my $content = IndieBox::Utils::slurpFile( $fileName );
        
        my $appTest = eval $content;

        if( defined( $appTest ) && ref( $appTest ) eq 'IndieBox::Testing::AppTest' ) {
            return $appTest;

        } elsif( $@ ) {
            error( 'Failed to parse', $fileName, ':', $@ );
            
        } else {
            error( 'Not an AppTest:', $fileName );
        }
    }        
    return undef;
}

1;
