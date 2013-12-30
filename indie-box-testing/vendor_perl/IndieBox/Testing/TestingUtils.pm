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
# Obtain all Perl module files in a particular parent package.
# $parentPackage: name of the parent package, such as IndieBox::AppConfigurationItems
# $inc: the path to search, or @INC if not given
# return: hash of file name to package name
sub findPerlModuleNamesInPackage {
    my $parentPackage = shift;
    my $inc           = shift || \@INC;

    my $parentDir = $parentPackage;
    $parentDir =~ s!::!/!g;

    my $ret = {};
    
    foreach my $inc2 ( @$inc ) {
        my $parentDir2 = "$inc2/$parentDir";

        if( -d $parentDir2 ) {
            opendir( DIR, $parentDir2 ) || error( $! );

            while( my $file = readdir( DIR )) {
               if( $file =~ m/^(.*)\.pm$/ ) {
                   my $fileName    = "$parentDir2/$file";
                   my $packageName = "$parentPackage::$1";

                   $ret->{$fileName} = $packageName;
               }
            }

            closedir(DIR);
        }
    }
    return $ret;
}

##
# Find the short, lowercase names of all Perl module files in a particular package.
# $parentPackage: name of the parent package, such as IndieBox::AppConfigurationItems
# $inc: the path to search, or @INC if not given
# return: hash of short package name to full package name
sub findPerlShortModuleNamesInPackage {
    my $parentPackage = shift;
    my $inc           = shift;

    my $full = findPerlModuleNamesInPackage( $parentPackage, $inc );
    my $ret  = {};

    while( my( $fileName, $packageName ) = each %$full ) {
        my $shortName = $packageName;
        $shortName =~ s!^.*::!!;
        $shortName =~ s!([A-Z])!-lc($1)!ge;
        $shortName =~ s!^-!!;

        $ret->{$shortName} = $packageName;
    }

    return $ret;
}

##
# Find the package names of all Perl files matching a pattern in a directory.
# $dir: directory to look in
# $pattern: the file name pattern, e.g. '\.pm$'
# return: hash of file name to package name
sub findModulesInDirectory {
    my $dir     = shift;
    my $pattern = shift || '\.pm$';

    my $ret = {};
    
    opendir( DIR, $dir ) || error( $! );

    while( my $file = readdir( DIR )) {
        if( $file =~ m/$pattern/ ) {
            my $fileName    = "$dir/$file";
            my $content     = IndieBox::Utils::slurpFile( $fileName );

            if( $content =~ m!package\s+([a-zA-Z0-9:_]+)\s*;! ) {
                my $packageName = $1;

                $ret->{$file} = $packageName;
            }
        }
    }
    closedir( DIR );

    return $ret;
}

##
# Read all files matching a pattern in a directory.
# $pattern: the file name pattern, e.g. '\.pm$'
# $dir: directory to look in
# return: hash of file name to file content
sub readFilesInDirectory {
    my $dir     = shift;
    my $pattern = shift || '\.pm$';

    my $ret = {};
    
    opendir( DIR, $dir ) || error( $! );

    while( my $file = readdir( DIR )) {
        if( $file =~ m/$pattern/ ) {
            my $fileName    = "$dir/$file";
            my $content     = IndieBox::Utils::slurpFile( $fileName );

            $ret->{$file} = $content;
        }
    }
    closedir( DIR );

    return $ret;
}

##
# Find all AppTests in a directory.
# $dir: directory to look in
# return: hash of file name to AppTest object
sub findAppTestsInDirectory {
    my $dir = shift;
    
    my $appTestCandidates = readFilesInDirectory( getcwd(), 'AppTest\.pm$' );
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
    my $ret = findPerlShortModuleNamesInPackage( 'IndieBox::Testing::Commands' );

    return $ret;
}

##
# Find available test plans
# return: hash of test plan name to full package name
sub findTestPlans {
    my $ret = findPerlShortModuleNamesInPackage( 'IndieBox::Testing::TestPlans' );

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
    my $ret = findPerlShortModuleNamesInPackage( 'IndieBox::Testing::Scaffolds' );
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

##
# Escape characters in URL. Inspired by http://cpansearch.perl.org/src/GAAS/URI-1.60/URI/Escape.pm,
# which does not seem to come with Arch.
sub uri_escape {
    my $s = shift;

    $s =~ s!([^-A-Za-z0-9\._~])!sprintf("%%%02X",$1)!ge;

    return $s;
}

1;
