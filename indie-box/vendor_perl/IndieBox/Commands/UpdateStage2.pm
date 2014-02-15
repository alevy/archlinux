#!/usr/bin/perl
#
# This command is not directly invoked by the user, but by Update.pm
# to re-install sites with the new code, instead of the old code.
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

package IndieBox::Commands::UpdateStage2;

use Cwd;
use Getopt::Long qw( GetOptionsFromArray );
use IndieBox::Commands::Update;
use IndieBox::Host;
use IndieBox::Logging;
use IndieBox::Utils;

##
# Execute this command.
# return: desired exit code
sub run {
    my @args = @_;

    if( @args ) {
        error( 'Invalid command-line arguments' ); # but continuing, we want the sites back
    }

    my $backupManager = new IndieBox::BackupManagers::ZipFileBackupManager();

    debug( 'Recovering configuration' );
    
    my @candidateFiles = <$IndieBox::Commands::Update::updateStatusDir/*>;

    my $statusFile = undef;
    my $bestTs     = undef;
    foreach my $candidate ( @candidateFiles ) {
        if( $candidate =~ m!^\Q$IndieBox::Commands::Update::updateStatusDir/$IndieBox::Commands::Update::updateStatusPrefix\E(.*)\Q$IndieBox::Commands::Update::updateStatusSuffix\E$! ) {
            my $ts = $1;
            if( !$bestTs || $ts gt $bestTs ) {
                $bestTs     = $ts;
                $statusFile = $candidate;
            }
        }
    }
    unless( $statusFile ) {
        fatal( 'Cannot restore, no status file found in', $IndieBox::Commands::Update::updateStatusDir );
    }
    
    my $statusJson = IndieBox::Utils::readJsonFromFile( $statusFile );
    
    my $oldSites     = {};
    my $adminBackups = {};
    while( my( $siteId, $frag ) = each %{$statusJson->{sites}} ) {
        my $backupFile = $frag->{backupfile};
        my $backup     = $backupManager->newFromArchive( $backupFile );
        
        my $site = $backup->{sites}->{$siteId};
        $oldSites->{$siteId} = $site;
        $adminBackups->{$siteId} = $backup;
    }

    debug( 'Redeploying sites' );

    foreach my $site ( values %$oldSites ) {
        $site->deploy();
        
        $adminBackups->{$site->siteId}->restoreSite( $site );

        IndieBox::Host::siteDeployed( $site );
    }

    debug( 'Resuming sites' );

    my $resumeTriggers = {};
    foreach my $site ( values %$oldSites ) {
        $site->resume( $resumeTriggers ); # remove "upgrade in progress page"
    }
    IndieBox::Host::executeTriggers( $resumeTriggers );

    debug( 'Running upgraders' );

    foreach my $site ( values %$oldSites ) {
        foreach my $appConfig ( @{$site->appConfigs} ) {
            $appConfig->runUpgrader();
        }
    }
    
    IndieBox::Utils::deleteFile( $statusFile );

    $backupManager->purgeAdminBackups();

    debug( 'Purging cache' );
    
    IndieBox::Host::purgeCache();
}

##
# Return help text for this command.
# return: hash of synopsis to help text
sub synopsisHelp {
    return undef; # user is not supposed to invoke this
}

1;
