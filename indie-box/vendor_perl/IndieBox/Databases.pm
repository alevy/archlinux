#!/usr/bin/perl
#
# Knows about which database managers are available.
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

package IndieBox::Databases;

use IndieBox::Logging;
use IndieBox::Utils;

my $types           = {}; # cache
my $driverInstances = {}; # cache: maps short-name to host:port to instance of driver

##
# Return which database types are available.
# return: hash of short-name to package name
sub findDatabases {
    unless( %$types ) {
        my $full = IndieBox::Utils::findPerlModuleNamesInPackage( 'IndieBox::Databases' );
        while( my( $fileName, $packageName ) = each %$full ) {
            if( $packageName =~ m!::([A-Za-z0-9_]+)Driver$! ) {
                my $shortName = $1;
                $shortName =~ s!([A-Z])!lc($1)!ge;
                $types->{$shortName} = $packageName;
            }
        }
    }
    return $types;
}

##
# Return an instance of a database driver for the given short-name
# $shortName: short name of the database type, e.g. 'mysql'
# $dbHost: host on which the database runs
# $dbPort: port on which the database can be reached on that port
# return: database driver, e.g. an instance of IndieBox::Databases::MySqlDriver
sub obtainDbDriver {
    my $shortName = shift;
    my $dbHost    = shift;
    my $dbPort    = shift || 'default';
    
    my $ret = $driverInstances->{$shortName}->{"$dbHost:$dbPort"};
    unless( $ret ) {
        my $dbs = findDatabases();
        my $db  = $dbs->{$shortName};
        if( $db ) {
            $ret = IndieBox::Utils::invokeMethod( $db . '::new', $db, $dbHost, $dbPort );
            
            if( $dbPort eq 'default' ) {
                $driverInstances->{$shortName}->{"$dbHost:default"} = $ret;
                $dbPort = $ret->defaultPort();
            }
            $driverInstances->{$shortName}->{"$dbHost:$dbPort"} = $ret;
        }
    }
    return $ret;
}

1;
