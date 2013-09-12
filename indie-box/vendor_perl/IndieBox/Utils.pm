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
use POSIX;

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

##
# Save content to a file.
# $filename: the name of the file to create/write
# $content: the content of the file
# $mask: permissions on the file
# $uname: owner of the file
# $gname: group of the file
# return: 1 if successful
sub saveFile {
    my $filename = shift;
    my $content  = shift;
    my $mask     = shift || -1;
    my $uname    = shift;
    my $gname    = shift;

    my $uid = getUid( shift );
    my $gid = getGid( shift );

    debug( "About to save to file $filename (" . length( $content ) . " bytes, mask " . sprintf( "%o", $mask ) . ", uid $uid, gid $gid)" );

    if( $mask == -1 ) {
        $mask = 0644;
    }
    unless( sysopen( F, $filename, O_CREAT | O_WRONLY | O_TRUNC )) {
        error( "Could not write to file $filename: $!" );
        return 0;
    }

    print F $content;
    close F;

    chmod $mask, $filename;

    if( $uid >= 0 || $gid >= 0 ) {
        chown $uid, $gid, $filename;
    }

    return 1;
}

##
# Get numerical user id, given user name. If already numerical, pass through.
# $uname: the user name
# return: numerical user id
sub getUid {
    my $uname = shift;

    my $uid;
    if( !$uname ) {
        $uid = 0; # default is root
    } elsif( $uname =~ /^[0-9]+$/ ) {
        $uid = $uname;
    } else {
        my @uinfo = getpwnam( $uname );
        unless( @uinfo ) {
            error( "Cannot find user '$uname'. Using 'nobody' instead." );
            @uinfo = getpwnam( 'nobody' );
        }
        $uid = $uinfo[2];
    }
    return $uid;
}

##
# Get numerical group id, given group name. If already numerical, pass through.
# $uname: the group name
# return: numerical group id
sub getGid {
    my $gname = shift;

    my $gid;
    if( !$gname ) {
        $gid = 0; # default is root
    } elsif( $gname =~ /^[0-9]+$/ ) {
        $gid = $gname;
    } else {
        my @ginfo = getgrnam( $gname );
        unless( @ginfo ) {
            error( "Cannot find group '$gname'. Using 'nogroup' instead." );
            @ginfo = getgrnam( 'nogroup' );
        }
        $gid = $ginfo[2];
    }
    return $gid;
}

##
# Generate a random password
# $length: length of password
# return: password
sub generateRandomPassword {
    my $length = shift || 8;

    my $ret = '';
    for( my $i=0 ; $i<$length ; ++$i ) {
        $ret .= ("a".."z", "A".."Z", 0..9)[rand 62];
    }
    return $ret;
}

1;
