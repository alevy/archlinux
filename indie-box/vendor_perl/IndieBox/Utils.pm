#!/usr/bin/perl
#
# Represents a Site for Indie Box Project
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

package IndieBox::Utils;

use IndieBox::Logging;
use Exporter qw( import myexec );
use File::Temp;
use JSON;
use POSIX;

our @EXPORT = qw( readJsonFromFile readJsonFromStdin myexec saveFile slurpFile );
my $jsonParser = JSON->new->relaxed->pretty->utf8();

##
# Read and parse JSON from a file
# $from: file to read from
# return: JSON object
sub readJsonFromFile {
    my $file = shift;

    my $fileContent = slurpFile( $file );

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
# Write a JSON file.
# $filename: the name of the file to create/write
# $content: the content of the file, as JSON object
# $mask: permissions on the file
# $uname: owner of the file
# $gname: group of the file
# return: 1 if successful
sub writeJsonToFile {
    my $fileName = shift;
    my $json     = shift;
    my $mask     = shift;
    my $uname    = shift;
    my $gname    = shift;

    saveFile( $fileName, $jsonParser->encode( $json ), $mask, $uname, $gname );
}

##
# Write JSON to STDOUT
# $content: the content of the file, as JSON object
sub writeJsonToStdout {
    my $json = shift;

    print $jsonParser->encode( $json );
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

    debug( "Exec: $cmd" );

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
# Slurp the content of a file
# $filename: the name of the file to read
# return: the content of the file
sub slurpFile {
    my $filename = shift;

    local $/;
    open( my $fh, '<', $filename ) || fatal( "Cannot read file $filename" );
    my $fileContent = <$fh>;
    close $fh;

    return $fileContent;
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
    my $mask     = shift;
    my $uname    = shift;
    my $gname    = shift;

    my $uid = getUid( shift );
    my $gid = getGid( shift );

    unless( defined( $mask )) {
        $mask = 0644;
    }
    debug( "About to save to file $filename (" . length( $content ) . " bytes, mask " . sprintf( "%o", $mask ) . ", uid $uid, gid $gid)" );

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
# Delete one or more files
# @files: the files to delete
# return: 1 if successful
sub deleteFile {
    my @files = @_;

    my $ret = 1;
    foreach my $f ( @files ) {
        if( -f $f || -l $f ) {
            unless( unlink( $f )) {
                error( "Failed to delete file $f: $!" );
                $ret = 0;
            }
        } elsif( -e $f ) {
            error( "Cannot delete file $f, it isn't a file or symlink" );
            $ret = 0;
        } else {
            error( "Cannot delete file $f, it doesn't exist" );
            $ret = 0;
        }
    }
    return $ret;
}

##
# Make a directory
# $filename: path to the directory
# $mask: permissions on the directory
# $uname: owner of the directory
# $gname: group of the directory
# return: 1 if successful
sub mkdir {
    my $filename = shift;
    my $mask     = shift;
    my $uid      = getUid( shift );
    my $gid      = getGid( shift );

    unless( defined( $mask )) {
        $mask = 0755;
    }

    if( -d $filename ) {
        warn( "Directory $filename exists already" );
        return 1;
    }
    if( -e $filename ) {
        error( "Failed to create directory $filename: something is there already" );
        return 0;
    }

    debug( "Creating directory $filename" );

    my $ret = mkdir $filename;
    unless( $ret ) {
        error( "Failed to create directory $filename: $!" );
    }

    chmod $mask, $filename;

    if( $uid >= 0 || $gid >= 0 ) {
        chown $uid, $gid, $filename;
    }

    return $ret;
}

##
# Delete one or more directories. They must be empty first
# @dirs: the directories to delete
sub deleteDirectory {
    my @dirs = @_;

    debug( "About to delete directories: " . join( ', ', @dirs ));

    my $ret = 1;
    foreach my $d ( @dirs ) {
        if( -d $d ) {
            unless( rmdir( $d )) {
                error( "Failed to delete directory $d: $!" );
                $ret = 0;
            }
        } elsif( -e $d ) {
            error( "Cannot delete directory $d, file exists but isn't a directory" );
            $ret = 0;
        } else {
            warn( "Cannot delete directory $d, does not exist" );
            next;
        }
    }
    return $ret;
}

##
# Delete one ore mor files or directories recursively.
# @files: the files or directories to delete recursively
sub deleteRecursively {
    my @files = @_;

    my $ret = 1;
    if( @files ) {
        debug( "About to recursively delete files: " . join( ', ', @files ));

        foreach my $f ( @files ) {
            if( -d $f ) {
                opendir( DIR, $f );
                my @files = readdir( DIR );
                closedir( DIR );

                deleteRecursively( map { "$f/$_"; } grep { !/^\.{1,2}$/ } @files );
                unless( rmdir( $f )) {
                    error( "Failed to delete directory $f: $!" );
                    $ret = 0;
                }
            } elsif( -f $f || -l $f ) {
                unless( unlink( $f )) {
                    error( "Failed to delete file $f: $!" );
                    $ret = 0;
                }
            } else {
                error( "Failed to delete file $f: does not exist" );
                $ret = 0;
            }
        }
    }
    return $ret;
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
