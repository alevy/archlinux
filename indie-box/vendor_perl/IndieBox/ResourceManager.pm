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

use strict;
use warnings;

package IndieBox::ResourceManager;

##
# Initialize this ResourceManager if needed. This involves creating the administrative tables
# if run for the first time.
sub initializeIfNeeded {

}

##
# Find an already-provisioned MySQL database for a given appconfigid and symbolic name.
# $appconfigid: the id of the AppConfiguration for which this database has been provisioned
# $name: the symbolic database name per application manifest
# return: hash of dbName, dbHost, dbUser, dbPassword, or undef
sub getMysqlDatabase {
    my $appconfigid = shift;
    my $name        = shift;


}

##
# Provision a MySQL database.
# $appconfigid: the id of the AppConfiguration for which this database has been provisioned
# $name: the symbolic database name per application manifest
# $privileges: string containing required database privileges, like "create, insert"
# $createSql: SQL that needs to be run to create tables etc. for the database
# return: hash of dbName, dbHost, dbUser, dbPassword, or undef
sub provisionMysqlDatabase {
    my $appconfigid = shift;
    my $name        = shift;
    my $privileges  = shift;
    my $createSql   = shift;

}

1;

