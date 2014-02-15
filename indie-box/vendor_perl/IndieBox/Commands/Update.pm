#!/usr/bin/perl
#
# Update all code on this device. This command will perform all steps
# until the actual installation of a new code version, and then
# pass on to UpdateStage2 to complete with the update code instead of
# the old code.
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

package IndieBox::Commands::Update;

use Cwd;
use File::Basename;
use Getopt::Long qw( GetOptionsFromArray );
use IndieBox::BackupManagers::ZipFileBackupManager;
use IndieBox::Host;
use IndieBox::Logging;
use IndieBox::Utils;

# Do not change the following filenames and paths unless you also update
# UpdateStage2 so it can still find the old location and restore.
# They aren't in config.json so that nobody is tempted to change them accidentally
# Do not write them into /tmp or such, because we still want to be able to do
# UpdateStage2 even after reboot

our $updateStatusDir = '/var/lib/indie-box/backups/admin';
our $updateStatusPrefix = 'update.';
our $updateStatusSuffix = '.status';

##
# Execute this command.
# return: desired exit code
sub run {
    my @args = @_;

    my $quiet = 0;
    my $parseOk = GetOptionsFromArray(
            \@args,
            'quiet' => \$quiet );

    if( !$parseOk || @args ) {
        fatal( 'Invalid command-line arguments' );
    }

    my $ts         = IndieBox::Host::config->get( 'now.tstamp' );
    my $statusFile = "$updateStatusDir/$updateStatusPrefix$ts$updateStatusSuffix";
    if( -e $statusFile ) {
        if( ! -w $statusFile ) {
            fatal( 'Cannot write to status file', $statusFile, ', not updating' );
        }
    } else {
        if( ! -e dirname( $statusFile )) {
            fatal( 'Cannot create status file', $statusFile, ', not updating' );
        }
    }

    my $oldSites = IndieBox::Host::sites();
    foreach my $oldSite ( values %$oldSites ) {
        $oldSite->checkUndeployable();
        $oldSite->checkDeployable(); # FIXME: this should check against the new version of the code
                                     # to do that right, we'll have to implement some kind of package rollback
                                     # this is the best we can do so far
    }

    debug( 'Suspending sites' );

    my $suspendTriggers = {};
    foreach my $site ( values %$oldSites ) {
        $site->suspend( $suspendTriggers ); # replace with "upgrade in progress page"
    }
    IndieBox::Host::executeTriggers( $suspendTriggers );

    debug( 'Backing up and undeploying' );
    
    my $backupManager = new IndieBox::BackupManagers::ZipFileBackupManager();

    my $adminBackups = {};
    foreach my $site ( values %$oldSites ) {
        $adminBackups->{$site->siteId} = $backupManager->adminBackupSite( $site );
        $site->undeploy();
    }

    debug( 'Preserving current configuration' );
    
    my $statusJson = {};
    while( my( $siteId, $backup ) = each %$adminBackups ) {
        $statusJson->{sites}->{$siteId} = { 'backupfile' => $backup->fileName };
    }

    IndieBox::Utils::writeJsonToFile( $statusFile, $statusJson, '0600' );

    debug( 'Updating code' );

    IndieBox::Host::updateCode( $quiet );

    # Will look into the know spot and restore from there
    
    debug( 'Handing over to stage-2' );

    exec( "indie-box-admin update-stage2" ) || fatal( "Failed to run indie-box-admin update-stage-2" );
}

##
# Return help text for this command.
# return: hash of synopsis to help text
sub synopsisHelp {
    return {
        <<SSS => <<HHH
    [--quiet]
SSS
    Update all code installed on this device. This will perform
    package updates, configuration updates, database migrations
    et al as needed.
HHH
    };
}

1;
