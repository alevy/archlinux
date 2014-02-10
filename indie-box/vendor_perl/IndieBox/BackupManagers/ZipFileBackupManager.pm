#!/usr/bin/perl
#
# Manages Backups implemented as a ZIP file.
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

package IndieBox::BackupManagers::ZipFileBackupManager;

use fields;
use IndieBox::BackupManagers::ZipFileBackup;

##
# Constructor
sub new {
    my $self = shift;
    
    unless( ref( $self )) {
        $self = fields::new( $self );
    }

    return $self;
}

##
# Create a Backup.
# $siteIds: list of siteids to be contained in the backup
# $appConfigIds: list of appconfigids to be contained in the backup that aren't part of the sites with the siteids
# $outFile: the file to save the backup to
sub backup {
    my $self         = shift;
    my $siteIds      = shift;
    my $appConfigIds = shift;
    my $out          = shift;

    return new IndieBox::BackupManagers::ZipFileBackup( $siteIds, $appConfigIds, $out );
}

##
# Read a Backup
# $archive: the archive file name
sub newFromArchive {
    my $self    = shift;
    my $archive = shift;
    
    return IndieBox::BackupManagers::ZipFileBackup->newFromArchive( $archive );
}

1;
