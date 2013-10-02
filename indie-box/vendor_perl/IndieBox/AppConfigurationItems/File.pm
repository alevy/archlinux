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
# $installable: the Installable to which this item belongs to
# return: the created File object
sub new {
    my $self        = shift;
    my $json        = shift;
    my $appConfig   = shift;
    my $installable = shift;

    unless( ref $self ) {
        $self = fields::new( $self );
    }
    $self->SUPER::new( $json, $appConfig, $installable );

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

        my $fromName = $sourceOrTemplate;
        $fromName =~ s!\$1!$name!g;      # $1: name
        $fromName =~ s!\$2!$localName!g; # $2: just the name without directories
        $fromName = $config->replaceVariables( $fromName );

        my $toName = $name;
        $toName = $config->replaceVariables( $toName );

        unless( $fromName =~ m#^/# ) {
            $fromName = "$defaultFromDir/$fromName";
        }
        unless( $toName =~ m#^/# ) {
            $toName = "$defaultToDir/$toName";
        }
        if( -r $fromName ) {
            my $content           = slurpFile( $fromName );
            my $templateProcessor = $self->_instantiateTemplateProcessor( $templateLang );

            my $contentToSave = $templateProcessor->process( $content, $config, $sourceOrTemplate );

            unless( saveFile( $toName, $contentToSave, $mode, $uname, $gname )) {
                error( "Writing file failed: $toName" );
            }

        } else {
            error( "File does not exist: $fromName" );
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
        my $toName = $name;
        $toName = $config->replaceVariables( $toName );

        unless( $toName =~ m#^/# ) {
            $toName = "$defaultToDir/$toName";
        }
        IndieBox::Utils::deleteFile( $toName );
    }
}

1;