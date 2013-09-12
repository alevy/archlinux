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

package IndieBox::Mysql;

use DBI;
use IndieBox::Utils;

my $rootConfiguration = '/etc/mysql/root-defaults.cnf';

##
# Ensure that mysqld is running
sub ensureRunning() {
    IndieBox::Utils::myexec( 'systemctl enable mysqld' );
    IndieBox::Utils::myexec( 'systemctl start mysqld' );

    1;
}

##
# Ensure that the mysql installation on this host has a root password.
sub ensureRootPassword {
    unless( -r $rootConfiguration ) {
        my $dbh = DBI->connect( "DBI:mysql:host=localhost", 'root', '' );
print "Dbh is $dbh\n";
        if( defined( $dbh )) {
            # can connect to database without a password
            my $password = IndieBox::Utils::generateRandomPassword( 16 );

            my $cnf = <<END;
[client]
host     = localhost
user     = root
password = $password
socket   = /run/mysqld/mysqld.sock
END
            IndieBox::Utils::saveFile( $rootConfiguration, $cnf, 0600 );

            my $sth = $dbh->prepare( <<SQL );
UPDATE mysql.user SET Password=PASSWORD( '$password' ) WHERE User='root';
SQL
            $sth->execute();

            $sth = $dbh->prepare( <<SQL );
FLUSH PRIVILEGES;
SQL
            $sth->execute();

            $dbh->disconnect();
        }
    }
}

1;
