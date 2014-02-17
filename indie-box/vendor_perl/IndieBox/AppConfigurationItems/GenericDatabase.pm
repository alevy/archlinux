#!/usr/bin/perl
#
# An AppConfiguration item that is any kind of Database for Indie Box Project
#
# Copyright (C) 2013-2014 Indie Box Project http://indieboxproject.org/
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

package IndieBox::AppConfigurationItems::GenericDatabase;

use base   qw( IndieBox::AppConfigurationItems::AppConfigurationItem );
use fields qw( dbType );

use IndieBox::Logging;
use IndieBox::ResourceManager;
use IndieBox::Utils qw( saveFile slurpFile );

##
# Constructor
# $dbType: short name of the database type
# $json: the JSON fragment from the manifest JSON
# $appConfig: the AppConfiguration object that this item belongs to
# $installable: the Installable to which this item belongs to
# return: the created File object
sub new {
    my $self        = shift;
    my $dbType      = shift;
    my $json        = shift;
    my $appConfig   = shift;
    my $installable = shift;

    unless( ref $self ) {
        $self = fields::new( $self );
    }
    $self->SUPER::new( $json, $appConfig, $installable );
    
    $self->{dbType} = $dbType;

    return $self;
}

##
# Install this item, or check that it is installable.
# $doIt: if 1, install; if 0, only check
# $defaultFromDir: the directory to which "source" paths are relative to
# $defaultToDir: the directory to which "destination" paths are relative to
# $config: the Configuration object that knows about symbolic names and variables
sub installOrCheck {
    my $self           = shift;
    my $doIt           = shift;
    my $defaultFromDir = shift;
    my $defaultToDir   = shift;
    my $config         = shift;

    my $name   = $self->{json}->{name};
    my $dbType = $self->{dbType};

    my( $dbName, $dbHost, $dbPort, $dbUserLid, $dbUserLidCredential, $dbUserLidCredType )
            = IndieBox::ResourceManager::getDatabase(
                    $dbType,
                    $self->{appConfig}->appConfigId,
                    $self->{installable}->packageName,
                    $name );
    unless( $dbName ) {
        my $privs  = $self->{json}->{privileges};

        if( $doIt ) {
            ( $dbName, $dbHost, $dbPort, $dbUserLid, $dbUserLidCredential, $dbUserLidCredType )
                    = IndieBox::ResourceManager::provisionLocalDatabase(
                            $dbType,
                            $self->{appConfig}->appConfigId,
                            $self->{installable}->packageName,
                            $name,
                            $privs );
        } else {
            # put it some placeholder values, so the variables resolve
            ( $dbName, $dbHost, $dbPort, $dbUserLid, $dbUserLidCredential, $dbUserLidCredType )
                    = ( 'placeholderDbName', 'placeholderDbHost', '9999', 'placeholderUserLid', 'placeholderUserLidCredential', 'simple-password' );
        }
    }
    # now insert those values into the config object
    $config->put( "appconfig.$dbType.dbname.$name",           $dbName );
    $config->put( "appconfig.$dbType.dbhost.$name",           $dbHost );
    $config->put( "appconfig.$dbType.dbport.$name",           $dbPort );
    $config->put( "appconfig.$dbType.dbuser.$name",           $dbUserLid );
    $config->put( "appconfig.$dbType.dbusercredential.$name", $dbUserLidCredential );
}

##
# Uninstall this item, or check that it is uninstallable.
# $doIt: if 1, uninstall; if 0, only check
# $defaultFromDir: the directory to which "source" paths are relative to
# $defaultToDir: the directory to which "destination" paths are relative to
# $config: the Configuration object that knows about symbolic names and variables
sub uninstallOrCheck {
    my $self           = shift;
    my $doIt           = shift;
    my $defaultFromDir = shift;
    my $defaultToDir   = shift;
    my $config         = shift;

    my $name   = $self->{json}->{name};
    my $dbType = $self->{dbType};

    if( $doIt ) {
        IndieBox::ResourceManager::unprovisionLocalDatabase(
                $dbType,
                $self->{appConfig}->appConfigId,
                $self->{installable}->packageName,
                $name );
    }
}

##
# Back this item up.
# $dir: the directory in which the app was installed
# $config: the Configuration object that knows about symbolic names and variables
# $zip: the ZIP object
# $contextPathInZip: the directory, in the ZIP file, into which this item will be backed up
# $filesToDelete: array of filenames of temporary files that need to be deleted after backup
sub backup {
    my $self             = shift;
    my $dir              = shift;
    my $config           = shift;
    my $zip              = shift;
    my $contextPathInZip = shift;
    my $filesToDelete    = shift;

    my $name   = $self->{json}->{name};
    my $bucket = $self->{json}->{retentionbucket};
    my $dbType = $self->{dbType};
    my $tmpDir = $config->getResolve( 'host.tmpdir', '/tmp' );

    my $tmp = File::Temp->new( UNLINK => 0, DIR => $tmpDir );

    IndieBox::ResourceManager::exportLocalDatabase(
            $dbType,
            $self->{appConfig}->appConfigId,
            $self->{installable}->packageName,
            $name,
            $tmp->filename );

    $zip->addFile( $tmp->filename, "$contextPathInZip/$bucket" );

    push @$filesToDelete, $tmp->filename;
}

##
# Restore this item from backup.
# $dir: the directory in which the app was installed
# $config: the Configuration object that knows about symbolic names and variables
# $zip: the ZIP object
# $contextPathInZip: the directory, in the ZIP file, into which this item will be backed up
sub restore {
    my $self             = shift;
    my $dir              = shift;
    my $config           = shift;
    my $zip              = shift;
    my $contextPathInZip = shift;

    my $name   = $self->{json}->{name};
    my $bucket = $self->{json}->{retentionbucket};
    my $dbType = $self->{dbType};
    my $tmpDir = $config->getResolve( 'host.tmpdir', '/tmp' );

    my $member = $zip->memberNamed( "$contextPathInZip/$bucket" );
    if( $member ) {
        my $tmp = File::Temp->new( UNLINK => 1, DIR => $tmpDir );

        $zip->extractMember( $member, $tmp->filename );

        IndieBox::ResourceManager::importLocalDatabase(
                $dbType,
                $self->{appConfig}->appConfigId,
                $self->{installable}->packageName,
                $name,
                $tmp->filename );
    }
}

1;
