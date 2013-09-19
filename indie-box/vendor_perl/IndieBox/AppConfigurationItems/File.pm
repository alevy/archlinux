#!/usr/bin/perl
#
# An AppConfiguration item that is a file for Indie Box Project
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

package IndieBox::AppConfigurationItems::File;

use base qw( IndieBox::AppConfigurationItems::AppConfigurationItem );
use fields;

use IndieBox::Logging;
use IndieBox::Utils qw( saveFile slurpFile );

##
# Constructor
# $json: the JSON fragment from the manifest JSON
# $appConfig: the AppConfiguration object that this item belongs to
# return: the created File object
sub new {
    my $self      = shift;
    my $json      = shift;
    my $appConfig = shift;

    unless( ref $self ) {
        $self = fields::new( $self );
    }
    $self->SUPER::new( $json, $appConfig );

    return $self;
}

##
# Install this item
# $defaultFromDir: the directory to which "source" paths are relative to
# $defaultToDir: the directory to which "destination" paths are relative to
# $config: the Configuration object that knows about symbolic names and variables
sub install {
    my $self           = shift;
    my $defaultFromDir = shift;
    my $defaultToDir   = shift;
    my $config         = shift;

    my $names = $self->{json}->{names};
    unless( $names ) {
        $names = [ $self->{json}->{name} ];
    }

    my $sourceOrTemplate = $self->{json}->{template};
    unless( $sourceOrTemplate ) {
        $sourceOrTemplate = $self->{json}->{source};
    }
    my $templateLang = $self->{json}->{templatelang};
    my $permissions  = $self->{json}->{permissions};
    my $uname        = $self->{json}->{uname};
    my $gname        = $self->{json}->{gname};
    my $mode         = $self->permissionToMode( $permissions, 0644 );

    foreach my $name ( @$names ) {
        my $localName  = $name;
        $localName =~ s!^.+/!!;

        $sourceOrTemplate =~ s!\$1!$name!g;      # $1: name
        $sourceOrTemplate =~ s!\$2!$localName!g; # $2: just the name without directories

        unless( $sourceOrTemplate =~ m#^/# ) {
            $sourceOrTemplate = "$defaultFromDir/$sourceOrTemplate";
        }
        my $fullName = $name;
        unless( $fullName =~ m#^/# ) {
            $fullName = "$defaultToDir/$fullName";
        }
        if( -r $sourceOrTemplate ) {
            my $content = slurpFile( $sourceOrTemplate );
            my $contentToSave;

            if( !defined( $templateLang )) {
                $contentToSave = $content;

            } elsif( 'varsubst' eq $templateLang ) {
                $contentToSave = $config->replaceVariables( $content );

            } elsif( 'perlscript' eq $templateLang ) {
                $contentToSave = eval $content;
                unless( $contentToSave ) {
                    error( "Error when attempting to eval file $sourceOrTemplate: $@" );
                }

            } else {
                warn( "Unknown templatelang: $templateLang" );
            }

            unless( saveFile( $fullName, $contentToSave, $mode, $uname, $gname )) {
                error( "Writing file failed: $fullName" );
            }

        } else {
            error( "File does not exist: $sourceOrTemplate" );
        }
    }
}

##
# Uninstall this item
# $defaultFromDir: the directory to which "source" paths are relative to
# $defaultToDir: the directory to which "destination" paths are relative to
# $config: the Configuration object that knows about symbolic names and variables
sub uninstall {
    my $self           = shift;
    my $defaultFromDir = shift;
    my $defaultToDir   = shift;
    my $config         = shift;

    my $names = $self->{json}->{names};
    unless( $names ) {
        $names = [ $self->{json}->{name} ];
    }

    foreach my $name ( reverse @$names ) {
        my $fullName = $name;
        unless( $fullName =~ m#^/# ) {
            $fullName = "$defaultToDir/$fullName";
        }
        IndieBox::Utils::deleteFile( $fullName );
    }
}

1;
