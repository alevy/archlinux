#!/usr/bin/perl
#
# Command that undeploys one or more sites.
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

package IndieBox::Commands::Undeploy;

use Cwd;
use File::Basename;
use Getopt::Long qw( GetOptionsFromArray );
use IndieBox::AdminUtils;
use IndieBox::BackupManagers::ZipFileBackupManager;
use IndieBox::Host;
use IndieBox::Logging;
use IndieBox::Utils;

##
# Execute this command.
# return: desired exit code
sub run {
    my @args = @_;

    my @siteIds = ();
    my $file    = undef;

    my $parseOk = GetOptionsFromArray(
            \@args,
            'siteid=s' => \@siteIds,
            'file=s'   => \$file );

    if( !$parseOk || @args || ( !@siteIds && !$file ) || ( @siteIds && $file )) {
        fatal( 'Invalid command-line arguments' );
    }
    
    debug( 'Looking for site(s)' );

    if( $file ) {
        # if $file is given, construct @siteIds from there
        my $json = readJsonFromFile( $file );
        $json = IndieBox::Utils::insertSlurpedFiles( $json, dirname( $file ) );

        if( ref( $json ) eq 'HASH' && %$json ) {
            @siteIds = ( $json->{siteid} );
        } elsif( ref( $json ) eq 'ARRAY' ) {
            if( !@$json ) {
                fatal( 'No site given' );
            } else {
                @siteIds = map { $_->{siteid} || fatal( 'No siteid found in JSON file' ) } @$json;
            }
        }
    }

    my $sites    = IndieBox::Host::sites();
    my $oldSites = {};
    foreach my $siteId ( @siteIds ) {
        my $site = $sites->{$siteId};
        if( $site ) {
            $oldSites->{$siteId} = $site;
        } else {
            fatal( "Cannot find site with siteid $siteId. Not undeploying any site." );
        }
        $site->checkUndeployable;
    }

    debug( 'Disabling site(s)' );

    my $disableTriggers = {};
    foreach my $oldSite ( values %$oldSites ) {
        $oldSite->disable( $disableTriggers ); # replace with "404 page"
    }
    IndieBox::Host::executeTriggers( $disableTriggers );

    debug( 'Backing up and undeploying' );

    my $backupManager = new IndieBox::BackupManagers::ZipFileBackupManager();

    my $adminBackups = {};
    foreach my $oldSite ( values %$oldSites ) {
        my $backup  = $backupManager->adminBackupSite( $oldSite );
        $oldSite->undeploy();
        $adminBackups->{$oldSite->siteId} = $backup;
    }

    $backupManager->purgeAdminBackups();
    
    return 1;
}

##
# Return help text for this command.
# return: hash of synopsis to help text
sub synopsisHelp {
    return {
        <<SSS => <<HHH,
    --siteid <siteid> [--siteid <siteid>]...
SSS
    Undeploy one or more previously deployed website(s).
HHH
        <<SSS => <<HHH
    --file <site.json>
SSS
    Undeploy one or more previously deployed website(s) whose site JSON
    file is given. This is a convenience invocation.
HHH
    };
}

1;
