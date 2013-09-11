#!/usr/bin/perl
#
# Represents a Site for Indie Box Project
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

package IndieBox::Utils;

use IndieBox::Logging;
use Exporter qw( import myexec );
use File::Temp;
use JSON;

our @EXPORT = qw( readJsonFromFile readJsonFromStdin myexec );
my $jsonParser = JSON->new->relaxed->pretty->utf8();

##
# Read and parse JSON from a file
# $from: file to read from
# return: JSON object
sub readJsonFromFile {
    my $file = shift;

    local $/;
    open( my $fh, '<', $file ) || fatal( "Cannot read file $file" );
    my $fileContent = <$fh>;

    my $json;
    eval {
        $json = $jsonParser->decode( $fileContent );
    } or fatal( "JSON parsing error in file $file: $@" );

    return $json;
}

##
# Read and parse JSON from STDIN
# return: JSON object
sub readJsonFromStdin {
    local $/;
    my $fileContent = <STDIN>;

    my $json;
    eval {
        $json = $jsonParser->decode( $fileContent );
    } or fatal( "JSON parsing error from <stdin>: $@" );

    return $json;
}

##
# Execute a command, and optionally read/write standard stream to/from strings
# $cmd: the commaand
# $inContent: optional string containing what will be sent to stdin
# $outContentP: optional reference to variable into which stdout output will be written
# $errContentP: optional reference to variable into which stderr output will be written
sub myexec {
    my $cmd         = shift;
    my $inContent   = shift;
    my $outContentP = shift;
    my $errContentP = shift;

    my $inFile;
    my $outFile;
    my $errFile;

    if( $inContent ) {
        $inFile = File::Temp->new();
        print $inFile $inContent;
        close $inFile;

        $cmd .= " <" . $inFile->filename;
    }
    if( defined( $outContentP )) {
        $outFile = File::Temp->new();
        $cmd .= " >" . $outFile->filename;
    }
    if( defined( $errContentP )) {
        $errFile = File::Temp->new();
        $cmd .= " 2>" . $errFile->filename;
    }

    system( $cmd );
    my $ret = $?;

    if( defined( $outContentP )) {
        ${$outContentP} = slurp( $outFile->filename );
    }
    if( defined( $errContentP )) {
        ${$errContentP} = slurp( $errFile->filename );
    }

    if( $ret == -1 || $ret & 127) {
        error( "Failed to execute $cmd (error code $ret): $!" );
    }
    return $ret;
}

1;
