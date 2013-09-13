#!/usr/bin/perl
#
# Manages resources for the Indie Box Project
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

#
# Table `databases`:
#   appConfigurationId:  identifier of the AppConfiguration that the database is allocated to
#   installableId:       of the one or more Installables at this AppConfiguration, identify which
#   itemName:            the symbolic name of the database as per the manifest of the Installable
#   dbName:              actual provisioned database name
#   dbHost:              database host, usually 'localhost'
#   dbPort:              database port, usually 3306
#   dbUserLid:           database user created for this database
#   dbUserLidCredential: credential for the user created for this database
#   dbUserLidCredType:   type of credential, usually 'simple-password'
#

use strict;
use warnings;

package IndieBox::ResourceManager;

use IndieBox::Logging;
use IndieBox::MySql;
use IndieBox::Utils;

my $indieBoxDbName   = 'indie-box';
my $dbNamesTableName = 'databases';

##
# Initialize this ResourceManager if needed. This involves creating the administrative tables
# if run for the first time.
sub initializeIfNeeded {
    my( $rootUser, $rootPass ) = IndieBox::MySql::findRootUserPass();

    unless( $rootUser ) {
        error( "Cannot find MySQL root user credentials" );
        return 0;
    }

    my $dbh = IndieBox::MySql::dbConnect( undef, $rootUser, $rootPass );

    # We proceed even in case of errors
    IndieBox::MySql::sqlPrepareExecute( $dbh, <<SQL );
CREATE DATABASE `$indieBoxDbName` CHARACTER SET = 'utf8'
SQL

    IndieBox::MySql::sqlPrepareExecute( $dbh, <<SQL );
CREATE TABLE `$indieBoxDbName`.`$dbNamesTableName` (
    appConfigurationId       VARCHAR(64),
    installableId            VARCHAR(64),
    itemName                 VARCHAR(32),
    dbName                   VARCHAR(64),
    dbHost                   VARCHAR(128),
    dbPort                   SMALLINT,
    dbUserLid                VARCHAR(64),
    dbUserLidCredential      VARCHAR(41),
    dbUserLidCredType        VARCHAR(32),
    UNIQUE KEY( appConfigurationId, installableId, itemName )
);
SQL

}

##
# Find an already-provisioned MySQL database for a given id of an AppConfiguration, the
# id of an Installable at that AppConfiguration, and the symbolic database name per manifest.
# $appConfigId: the id of the AppConfiguration for which this database has been provisioned
# $installableId: the id of the Installable at the AppConfiguration for which this database has been provisioned
# $name: the symbolic database name per application manifest
# return: tuple of dbName, dbHost, dbPort, dbUser, dbPassword, dbCredentialType, or undef
sub getMySqlDatabase {
    my $appConfigId   = shift;
    my $installableId = shift;
    my $itemName      = shift;

    debug( "getDatabase ", $appConfigId, ", ", $installableId, ", ", $itemName );

    my $dbh = IndieBox::MySql::dbConnectAsRoot( $indieBoxDbName );
    my $sth = IndieBox::MySql::sqlPrepareExecute( <<SQL, $appConfigId, $installableId, $itemName );
SELECT dbName,
       dbHost,
       dbPort,
       dbUserLid,
       dbUserLidCredential
FROM   `$dbNamesTableName`
WHERE  appConfigurationId = ?
  AND  installableId = ?
  AND  itemName = ?
SQL

    my $dbName;
    my $dbHost;
    my $dbPort;
    my $dbUserLid;
    my $dbUserLidCredential;
    my $dbUserLidCredType;

    while( my $ref = $sth->fetchrow_hashref() ) {
        if( $dbName ) {
            error( "More than one found, not good: $dbName" );
            last;
        }
        $dbName              = $ref->{'dbName'};
        $dbHost              = $ref->{'dbHost'};
        $dbPort              = $ref->{'dbPort'};
        $dbUserLid           = $ref->{'dbUserLid'};
        $dbUserLidCredential = $ref->{'dbUserLidCredential'};
        $dbUserLidCredType   = $ref->{'dbUserLidCredType'};
    }
    $sth->finish();
    $dbh->disconnect();

    if( $dbName ) {
        return( $dbName, $dbHost, $dbPort, $dbUserLid, $dbUserLidCredential, $dbUserLidCredType );
    } else {
        return undef;
    }
}

##
# Provision a local MySQL database.
# $appConfigId: the id of the AppConfiguration for which this database has been provisioned
# $installableId: the id of the Installable at the AppConfiguration for which this database has been provisioned
# $itemName: the symbolic database name per application manifest
# $privileges: string containing required database privileges, like "create, insert"
# $createSqlFile: name of a SQL file that needs to be run to create tables etc. for the database
# return: hash of dbName, dbHost, dbUser, dbPassword, or undef
sub provisionLocalMySqlDatabase {
    my $appConfigId   = shift;
    my $installableId = shift;
    my $itemName      = shift;
    my $privileges    = shift;
    my $createSqlFile = shift;

    debug( "provisionLocalMySqlDatabase", $appConfigId, ", ", $installableId, ", ", $itemName, ", ", $privileges, ", ", $createSqlFile );

    my $dbName              = IndieBox::Utils::generateRandomIdentifier( 16 ); # unlikely to collide
    my $dbHost              = 'localhost';
    my $dbPort              = 3306;
    my $dbUserLid           = IndieBox::Utils::generateRandomPassword( 16 );
    my $dbUserLidCredential = IndieBox::Utils::generateRandomPassword( 16 );
    my $dbUserLidCredType   = 'simple-password';

    my $dbh = IndieBox::MySql::dbConnectAsRoot( $indieBoxDbName );
    my $sth = IndieBox::MySql::sqlPrepareExecute( <<SQL, $appConfigId, $installableId, $itemName, $dbName, $dbHost, $dbPort, $dbUserLid, $dbUserLidCredential, $dbUserLidCredType );
INSERT INTO `$dbNamesTableName`(
    appConfigurationId,
    installableId,
    itemName,
    dbName,
    dbHost,
    dbPort,
    dbUserLid,
    dbUserLidCredential,
    dbUserLidCredType )
) VALUES (
    ?,
    ?,
    ?,
    ?,
    ?,
    ?,
    ?,
    ?,
    ? )
SQL
    $sth->finish();

    $sth = IndieBox::MySql::sqlPrepareExecute( <<SQL );
CREATE DATABASE `$dbName` CHARACTER SET = 'utf8';
SQL
    $sth->finish();

    $sth = IndieBox::MySql::sqlPrepareExecute( <<SQL );
GRANT $privileges
   ON $dbName.*
   TO '$dbUserLid'\@'localhost'
   IDENTIFIED BY '$dbUserLidCredential';
SQL
    $sth->finish();

    $sth = IndieBox::MySql::sqlPrepareExecute( <<SQL );
FLUSH PRIVILEGES;
SQL
    $sth->finish();
    $dbh->disconnect();

    if( $createSqlFile ) {
        # from the command-line; that way we don't have to deal with messy statement splitting
        IndieBox::Utils::myexec(
                "mysql '--host=$dbHost' '--port=$dbPort'"
                        . " '--user=$dbUserLid' '--password=$dbUserLidCredential'"
                        . " '$dbName'",
                $createSqlFile );
    }
    return( $dbName, $dbHost, $dbPort, $dbUserLid, $dbUserLidCredential, $dbUserLidCredType );
}

1;
