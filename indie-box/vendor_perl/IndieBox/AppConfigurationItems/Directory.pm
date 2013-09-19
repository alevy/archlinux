#!/usr/bin/perl
#
# An AppConfiguration item that is a directory for Indie Box Project
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

package IndieBox::AppConfigurationItems::Directory;

use base qw( IndieBox::AppConfigurationItems::AppConfigurationItem );
use fields;

use IndieBox::Logging;

##
# Constructor
# $json: the JSON fragment from the manifest JSON
# $appConfig: the AppConfiguration object that this item belongs to
# return: the created Directory object
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

    my $permissions  = $self->{json}->{permissions};
    my $uname        = $self->{json}->{uname};
    my $gname        = $self->{json}->{gname};
    my $mode         = $self->permissionToMode( $permissions, 0755 );

    foreach my $name ( @$names ) {
        my $fullName = $name;
        unless( $fullName =~ m#^/# ) {
            $fullName = "$defaultToDir/$fullName";
        }
        if( -e $fullName ) {
            error( "Directory $fullName exists already" );

        } else {
            if( IndieBox::Utils::mkdir( $fullName, $mode, $uname, $gname ) != 1 ) {
                error( "Directory could not be created: $fullName" );
            }
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
        IndieBox::Utils::deleteDirectory( $fullName );
    }
}

1;


