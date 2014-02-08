#!/usr/bin/perl
#
# Utilities for the commands in this package.
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

package IndieBox::AdminUtils;

use IndieBox::Host;
use IndieBox::Logging;
use IndieBox::Utils;

##
# Find available commands.
# return: hash of command name to full package name
sub findCommands {
    my $ret = IndieBox::Utils::findPerlShortModuleNamesInPackage( 'IndieBox::Commands' );

    return $ret;
}

##
# Purge backups on this device.
# $backups: array of Backup object
sub purgeBackups {
    my $backups = shift;

    debug( 'Purging backups' );

    my $backupLifetime = IndieBox::Host::config()->getResolve( 'host.adminbackuplifetime', -1 );
    if( $backupLifetime >= 0 ) {
        my $cutoff = time() - $backupLifetime;
        foreach my $backup ( $backups ) {
            if( $backup->startTime() < $cutoff ) {
                my $fileName = $backup->fileName();
                if( $fileName && -e $fileName ) {
                    IndieBox::Utils::deleteFile( $fileName );
                }
            }
        }
    }
    return 1;
}

1;
