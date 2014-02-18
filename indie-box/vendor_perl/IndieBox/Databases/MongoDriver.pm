#!/usr/bin/perl
#
# Mongo database driver for the Indie Box Project.
#
# Copyright (C) 2014 Indie Box Project http://indieboxproject.org/
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

package IndieBox::Databases::MongoDriver;

use File::Basename;
use IndieBox::Logging;
use IndieBox::Utils;
use fields qw( dbHost dbPort );

my $running = 0;
my $rootConfiguration = '/etc/mongodb/root-defaults.cnf';

## Note that this driver has both 'static' and 'instance' methods

## ---- STATIC METHODS ---- ##

##
# Ensure that mongo is configured correctly and running
sub ensureRunning {
    if( $running ) {
        return 1;
    }

    debug( 'Installing mongo' );
    
    IndieBox::Host::installPackages( 'mongodb' );

    # make sure we have a root user
    unless( -r $rootConfiguration ) {
        unless( -d dirname( $rootConfiguration )) {
            IndieBox::Utils::mkdir( dirname( $rootConfiguration ), 0755 );
        }
        
        my $password = IndieBox::Utils::randomPassword( 16 );
        my $cnf = <<END;
user     = root
password = $password
END
        IndieBox::Utils::saveFile( $rootConfiguration, $cnf, 0600 );

        IndieBox::Utils::myexec( 'systemctl daemon-reload' ); # Needed, apparently
        IndieBox::Utils::myexec( 'systemctl restart mongodb' );
        sleep( 3 ); # Needed, otherwise might not be able to connect

        my $stderr;
        IndieBox::Utils::myexec( 'mongo admin', <<CMD, undef, \$stderr ) && IndieBox::Logging::warn( 'Adding mongo root user:', $stderr );
db.addUser( { user: "root",
              pwd: "$password",
              roles: [
                  "userAdminAnyDatabase",
                  "dbAdminAnyDatabase",
                  "clusterAdmin",
                  "readWriteAnyDatabase" ]
            } )
CMD
        # clusterAdmin is needed to list databases

        IndieBox::Utils::myexec( 'systemctl stop mongodb' );
    }

    # make sure authentication is on
    my $confFile     = '/etc/mongodb.conf';
    my $confContent  = IndieBox::Utils::slurpFile( $confFile );
    my $confAuth     = 'auth = true';
    my $confNoBypass = 'setParameter = enableLocalhostAuthBypass=0';
    
    my $doWrite = 0;
    foreach my $line ( $confAuth, $confNoBypass ) {
        unless( $confContent =~ m!^$line$!m ) {
            $confContent .= "\n$line";
            $doWrite = 1;
        }
    }
    if( $doWrite ) {
        IndieBox::Utils::saveFile( $confFile, $confContent, 0644 );
    }
       
    IndieBox::Utils::myexec( 'systemctl enable mongodb' );
    IndieBox::Utils::myexec( 'systemctl start mongodb' );
    sleep( 3 ); # Needed, otherwise might not be able to connect

    $running = 1;
    1;
}

##
# Execute a command as root
# $cmd: command
sub executeCmdAsRoot {
    my $cmd = shift;
    
    ensureRunning();
    
    my( $rootUser, $rootPass ) = findRootUserPass();
    
    # must connect to admin database for auth to work
    IndieBox::Utils::myexec( "mongo -u '$rootUser' -p '$rootPass' admin", $cmd );
}

##
# Find the root password for the database.
sub findRootUserPass {
    my $user;
    my $pass;

    open CNF, '<', $rootConfiguration || return undef;
    foreach my $line ( <CNF> ) {
        if( $line =~ m/\s*user\s*=\s*(\S+)/ ) {
            $user = $1;
        } elsif( $line =~ m/\s*password\s*=\s*(\S+)/ ) {
            $pass = $1;
        }
    }
    close CNF;
    if( $user && $pass ) {
        return( $user, $pass );
    } else {
        error( 'Cannot find root credentials to access mongodb. Perhaps you need to run as root?' );
        return undef;
    }
}
              
## ---- INSTANCE METHODS ---- ##

##
# Constructor
# $dbHost: the host to connect to
# $dbPort: the port to connect to
# return: instance of MySqlDriver
sub new {
    my $self   = shift;
    my $dbHost = shift;
    my $dbPort = shift;

    unless( ref $self ) {
        $self = fields::new( $self );
    }
    $self->{dbHost} = $dbHost;
    $self->{dbPort} = $dbPort;

    return $self;
}

##
# Obtain the default port.
# return: default port
sub defaultPort {
    my $self = shift;
    
    return 27017;
}

##
# Provision a local database
# $dbName: name of the database to provision
# $dbUserLid: identifier of the database user that is allowed to access it
# $dbUserLidCredential: credential for the database user
# $dbUserLidCredType: credential type
# $privileges: string containing required database privileges, like "readWrite, dbAdmin"
sub provisionLocalDatabase {
    my $self                = shift;
    my $dbName              = shift;
    my $dbUserLid           = shift;
    my $dbUserLidCredential = shift;
    my $dbUserLidCredType   = shift;
    my $privileges          = shift;

    my $privString = join( ', ', map( { s/^\s+//; s/\s+$//; "\"$_\""; } split /,/, $privileges ));
    
    executeCmdAsRoot( <<CMD );
use $dbName
db.dummy.insert( { dummy : "dummy" } )
db.dummy.drop()
db.addUser( { user: "$dbUserLid",
              pwd: "$dbUserLidCredential",
              roles: [ $privString ]
            } )
CMD
}

##
# Unprovision a local database
# $dbName: name of the database to unprovision
sub unprovisionLocalDatabase {
    my $self                = shift;
    my $dbName              = shift;

    executeCmdAsRoot( <<CMD );
use $dbName
db.dropDatabase()
CMD
}

##
# Export the data at a local database
# $dbName: name of the database to unprovision
# $fileName: name of the file to create with the exported data
sub exportLocalDatabase {
    my $self     = shift;
    my $dbName   = shift;
    my $fileName = shift;

    my( $rootUser, $rootPass ) = findRootUserPass();

    IndieBox::Utils::myexec( "mongodump -u '$rootUser' -p '$rootPass' -d '$dbName' -o '$fileName'" );
}

##
# Import data into a local database, overwriting its previous content
# $dbName: name of the database to unprovision
# $fileName: name of the file to create with the exported data
sub importLocalDatabase {
    my $self     = shift;
    my $dbName   = shift;
    my $fileName = shift;
    
    my( $rootUser, $rootPass ) = findRootUserPass();

    IndieBox::Utils::myexec( "mongorestore -u '$rootUser' -p '$rootPass' -d '$dbName' --drop '$fileName'" );
}

1;
