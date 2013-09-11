#!/usr/bin/perl
#
# Manifest checking routines. This is factored out to not clutter the main
# functionality.
#
# Copyright (C) 2013 Johannes Ernst
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

package IndieBox::InstallableManifest;

use Exporter qw( import );
use IndieBox::Logging;
use JSON;

our @EXPORT_OK = qw( validFilename );

##
# Check validity of the manifest JSON.
# $json: the JSON object
# $codeDir: path to the package's code directory
# return: 1 or exits with fatal error
sub checkManifest {
    my $json    = shift;
    my $codeDir = shift;

    unless( $json ) {
        fatal( "No manifest JSON present" );
    }
    unless( $json->{type} ) {
        fatal( "Manifest JSON: type: missing" );
    }

    if( $json->{roles} ) {
        unless( ref( $json->{roles} ) eq 'HASH' ) {
            fatal( "Manifest JSON: roles section: not a JSON object" );
        }
    }
    if( $json->{customizationpoints} ) {
        unless( ref( $json->{customizationpoints} ) eq 'HASH' ) {
            fatal( "Manifest JSON: customizationpoints section: not a JSON object" );
        }
    }
}

##
# Check whether a filename (which may be absolute or relative) refers to a valid file
# $filenameContext: if the filename is relative, this specifies the absolute path it is relative to
# $filename: the absolute or relative filename
# $name: the name
# return: 1 if valid
sub validFilename {
    my $filenameContext = shift;
    my $filename        = shift;
    my $name            = shift;

    my $testFile;
    if( $filename =~ m!^/! ) {
        # is absolute filename
        $testFile = $filename;
    } else {
        $testFile = "$filenameContext/$filename";
    }

    if( $name ) {
        my $localName  = $name;
        $localName =~ s!^.+/!!;

        $testFile =~ s!\$1!$name!g;      # $1: name
        $testFile =~ s!\$2!$localName!g; # $2: just the name without directories
    }

    unless( -e $testFile ) {
        die( "Manifest refers to file, but file cannot be found: $testFile" );
    }

    return 1; # FIXME
}

1;
