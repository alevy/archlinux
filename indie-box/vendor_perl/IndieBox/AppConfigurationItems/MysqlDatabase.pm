#!/usr/bin/perl
#
# An AppConfiguration item that is a MySQL Database for Indie Box Project
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

package IndieBox::AppConfigurationItems::MysqlDatabase;

use base qw( IndieBox::AppConfigurationItems::AppConfigurationItem );
use fields;

use IndieBox::Logging;
use IndieBox::ResourceManager;
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

    my $name = $self->{json}->{name};

    my( $dbName, $dbHost, $dbPort, $dbUserLid, $dbUserLidCredential, $dbUserLidCredType )
            = IndieBox::ResourceManager::getMySqlDatabase(
                    $self->{appConfig}->appConfigId,
                    $self->{installable}->packageName,
                    $name );
    unless( $dbName ) {
        my $privs  = $self->{json}->{privileges};
        my $create = $self->{json}->{create};

        ( $dbName, $dbHost, $dbPort, $dbUserLid, $dbUserLidCredential, $dbUserLidCredType )
                = IndieBox::ResourceManager::provisionLocalMySqlDatabase(
                        $self->{appConfig}->appConfigId,
                        $self->{installable}->packageName,
                        $name,
                        $privs );

        if( $create ) {
            my( $rootUser, $rootPass ) = IndieBox::MySql::findRootUserPass();
            if( $rootUser ) {
                if( ref( $create ) eq 'ARRAY' ) {
                    foreach my $section ( @$create ) {
                        $self->_createDb( $defaultFromDir, $config, $section, $dbName, $dbHost, $dbPort, $rootUser, $rootPass );
                    }
                } else {
                    $self->_createDb( $defaultFromDir, $config, $create, $dbName, $dbHost, $dbPort, $rootUser, $rootPass );
                }
            } else {
                error( "Failed to find MySQL root user/pass" );
            }
        }
    }
    # now insert those values into the config object
    $config->put( "appconfig.mysql.dbname.$name",           $dbName );
    $config->put( "appconfig.mysql.dbhost.$name",           $dbHost );
    $config->put( "appconfig.mysql.dbport.$name",           $dbPort );
    $config->put( "appconfig.mysql.dbuser.$name",           $dbUserLid );
    $config->put( "appconfig.mysql.dbusercredential.$name", $dbUserLidCredential );
}

##
# Helper method to run a SQL init script for a new database.
# $defaultFromDir: the directory to which "source" paths are relative to
# $config: the Configuration object that knows about symbolic names and variables
# $json: applicable JSON fragment from the manifest JSON
# $dbName: database name
# $dbHost: host on which the database runs
# $dbPort: port at which the database can be reached
# $dbUserLid: username of the database user
# $dbUserLidCredential: credential of the database user
sub _createDb {
    my $self                = shift;
    my $defaultFromDir      = shift;
    my $config              = shift;
    my $json                = shift;
    my $dbName              = shift;
    my $dbHost              = shift;
    my $dbPort              = shift;
    my $dbUserLid           = shift;
    my $dbUserLidCredential = shift;

    my $sourceOrTemplate = $json->{template};
    unless( $sourceOrTemplate ) {
        $sourceOrTemplate = $json->{source};
    }
    my $templateLang = $json->{templatelang};
    my $delimiter    = $json->{delimiter};

    unless( $sourceOrTemplate =~ m#^/# ) {
        $sourceOrTemplate = "$defaultFromDir/$sourceOrTemplate";
    }

    my $content = slurpFile( $sourceOrTemplate );
    my $sql;
    if( $templateLang ) {
        my $templateProcessor = $self->_instantiateTemplateProcessor( $templateLang );
        $sql = $templateProcessor->process( $content, $config, $sourceOrTemplate );
    } else {
        $sql = $content;
    }

    # from the command-line; that way we don't have to deal with messy statement splitting
    my $cmd = "mysql '--host=$dbHost' '--port=$dbPort'";
    $cmd .= " '--user=$dbUserLid' '--password=$dbUserLidCredential'";
    if( $delimiter ) {
        $cmd .= " '--delimiter=$delimiter'";
    }
    $cmd .= " '$dbName'";

    IndieBox::Utils::myexec( $cmd, $sql );
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

    my $name = $self->{json}->{name};

    IndieBox::ResourceManager::unprovisionLocalMySqlDatabase(
            $self->{appConfig}->appConfigId,
            $self->{installable}->packageName,
            $name );
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
    my $tmpDir = $config->getResolve( 'host.tmpdir', '/tmp' );

    my $tmp = File::Temp->new( UNLINK => 0, DIR => $tmpDir );

    IndieBox::ResourceManager::exportLocalMySqlDatabase(
            $self->{appConfig}->appConfigId,
            $self->{installable}->packageName,
            $name,
            $tmp->filename );

    $zip->addFile( $tmp->filename, "$contextPathInZip/$bucket" );

    push @$filesToDelete, $tmp->filename;
}

1;
