#!/usr/bin/perl
#
# Command that backs up data on this device.
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

package IndieBox::Commands::Backup;

use Cwd;
use Getopt::Long qw( GetOptionsFromArray );
use IndieBox::Host;
use IndieBox::Logging;
use IndieBox::Utils;

##
# Execute this command.
# return: desired exit code
sub run {
    my @args = @_;

    my $out          = undef;
    my @siteIds      = ();
    my @appConfigIds = ();

    my $parseOk = GetOptionsFromArray(
            \@args,
            'out=s',        => \$out,
            'siteid=s'      => \@siteIds,
            'appconfigid=s' => \@appConfigIds );

    if( !$parseOk || @args || !$out ) {
        fatal( 'Invalid command-line arguments' );
    }

    my $oldSites = IndieBox::Host::sites();
    my $resumeSites = ();
    my $suspendTriggers = {};

    debug( 'Suspending sites' );

    if( @siteIds != 0 || @appConfigIds != 0 ) {
        # first make sure there is no overlap between them
        foreach my $siteId ( @siteIds ) {
            my $oldSite = $oldSites->{$siteId};
            if( $oldSite ) {
                if( @appConfigIds ) {
                    foreach my $oldSiteAppConfig ( $oldSite->appConfigs ) {
                        foreach my $appConfigId ( @appConfigIds ) {
                            if( $oldSiteAppConfig->appConfigId eq $appConfigId ) {
                                fatal( "AppConfiguration $appConfigId is already part of site $siteId" );
                            }
                        }
                    }
                }
            } else {
                fatal( "Cannot find site $siteId" );
            }
        }
        foreach my $siteId ( @siteIds ) {
            my $oldSite = $oldSites->{$siteId};
            if( $oldSite ) {
                $oldSite->suspend( $suspendTriggers );
                $resumeSites->{$siteId} = $oldSite;
            }
        }
        foreach my $appconfigId ( @appConfigIds ) {
            foreach my $oldSite ( values %$oldSites ) {
                my $foundAppConfig;
                foreach my $oldAppconfig ( @{$oldSite->appconfigs()} ) {
                    if( $appconfigId eq $oldAppconfig->appConfigId() ) {
                        my $foundAppConfig = $oldAppconfig;
                        last;
                    }
                }
                if( $foundAppConfig ) {
                    $oldSite->suspend( $suspendTriggers );
                    $resumeSites->{$oldSite->siteId} = $oldSite;
                } else {
                    fatal( "Cannot find appconfiguration $appconfigId" );
                }
            }
        }
    } else {
        foreach my $oldSite ( values %$oldSites ) {
            $oldSite->suspend( $suspendTriggers );
            $resumeSites->{$oldSite->siteId} = $oldSite;
        }
    }
    IndieBox::Host::executeTriggers( $suspendTriggers );

    debug( 'Creating and exporting backup' );

    my $backupManager = new IndieBox::BackupManagers::ZipFileBackupManager();
    my $backup        = $backupManager->backup( \@siteIds, \@appConfigIds, $out );

    debug( 'Resuming sites' );

    my $resumeTriggers = {};
    foreach my $site ( values %$resumeSites ) {
        $site->resume( $resumeTriggers );
    }
    IndieBox::Host::executeTriggers( $resumeTriggers );
    
    return 1;
}

##
# Return help text for this command.
# return: hash of synopsis to help text
sub synopsisHelp {
    return {
        <<SSS => <<HHH,
    --siteid <siteid> --out <backupfile>
SSS
    Back up all data from all applications installed at a currently
    deployed site with siteid to backupfile.
HHH
        <<SSS => <<HHH,
    --appconfigid <appconfigid> --out <backupfile>
SSS
    Back up all data from the currently deployed application at
    AppConfiguration appconfigid to backupfile.
HHH
        <<SSS => <<HHH
    --out <backupfile>
SSS
    Back up all data from all currently deployed applications at all
    deployed sites to backupfile.
HHH
    };
}

1;
