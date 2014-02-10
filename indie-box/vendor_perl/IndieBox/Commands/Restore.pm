#!/usr/bin/perl
#
# Command that restores data from a backup.
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

package IndieBox::Commands::Restore;

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

    my $in           = undef;
    my @siteIds      = ();
    my @appConfigIds = ();
    my @translates   = ();

    my $parseOk = GetOptionsFromArray(
            \@args,
            'in=s'          => \$in,
            'siteid=s'      => \@siteIds,
            'appconfigid=s' => \@appConfigIds,
            'translate=s'   => \@translates );

    if( !$parseOk || @args || !$in ) {
        fatal( 'Invalid command-line arguments' );
    }

    debug( 'Parsing translation table (if any)' );

    my $translationTable = {};
    foreach my $translate ( @translates ) {
        if( $translate =~ m!^(.*)=>(.*)$! ) {
            my $from = $1;
            my $to   = $2;

            if( $translationTable->{$from} ) {
                fatal( "Have translation from $from already" );
            }
            $translationTable->{$from} = $to;
        } else {
            fatal( "Invalid translation: $translate" );
        }
    }

    my $backup             = newFromArchive IndieBox::Backup( $in );
    my $sitesInBackup      = $backup->sites();
    my $appConfigsInBackup = $backup->appConfigs();
    my $sites              = IndieBox::Host::sites();
    my $sitesToSuspend     = {};
    my $sitesToResume      = {};
    my $sitesOfAppConfigs  = {};

    debug( 'Checking arguments' );

    if( @siteIds ) {
        foreach my $siteId ( @siteIds ) {
            my $siteInBackup = $sitesInBackup->{$siteId};
            my $site         = $sites->{$siteId};
            unless( $siteInBackup ) {
                fatal( "No site with siteid $siteId found in backup file $in" );
            }
            if( $site ) {
                $sitesToSuspend->{$siteId} = $site;
            }
            $sitesToResume->{$siteId} = $siteInBackup;
        }

    } elsif( @appConfigIds == 0 ) {
        @siteIds = keys %$sitesInBackup;
    }
    if( @appConfigIds ) {
        foreach my $appConfigId ( @appConfigIds ) {
            unless( $appConfigsInBackup->{$appConfigId} ) {
                fatal( "No AppConfiguration with appconfigid $appConfigId found in backup file $in" );
            }
            my $foundSite;
            foreach my $site ( values %$sites ) {
                if( $site->appConfig( $appConfigId )) {
                    $foundSite = $site;
                    last;
                }
            }
            unless( $foundSite ) {
                fatal( "No AppConfiguration with appconfigid $appConfigId currently deployed" );
            }
            $sitesOfAppConfigs->{$appConfigId}    = $foundSite;
            $sitesToSuspend->{$foundSite->siteId} = $foundSite;
            $sitesToResume->{$foundSite->siteId}  = $foundSite;
        }
    }
    if( @siteIds || @appConfigIds ) {
        foreach my $from ( keys %$translationTable ) {
            my $found;
            foreach my $id ( @siteIds, @appConfigIds ) {
                if( $id eq $from ) {
                    $found = 1;
                    last;
                }
            }
            unless( $found ) {
                fatal( "Cannot find $from specified in translation among siteids or appconfigids" );
            }
        }
    }

    # make sure no AppConfiguration has moved from one site to another since the backup
    foreach my $siteId ( @siteIds ) {
        my $site = $sites->{$siteId};
        unless( $site ) {
            next;
        }
        foreach my $appConfig ( @{$site->appConfigs} ) {
            my $appConfigId = $appConfig->appConfigId;
            foreach my $siteInBackup ( values %$sitesInBackup ) {
                if( $siteInBackup->siteId eq $siteId ) {
                    next;
                }
                foreach my $appConfigInBackup ( @{$siteInBackup->appConfigs} ) {
                    if( $appConfigId eq $appConfigInBackup->appConfigId ) {
                        fatal( "AppConfiguration $appConfigId belongs to deployed site $siteId"
                               . " and to different site " . $siteInBackup->siteId . " in backup" );
                    }
                }
            }
        }
    }

    debug( 'Suspending sites' );

    my $suspendTriggers = {};
    foreach my $site ( values %$sitesToSuspend ) {
        $site->suspend( $suspendTriggers ); # replace with "in progress page"
    }
    IndieBox::Host::executeTriggers( $suspendTriggers );

    debug( 'Restoring sites' );

    foreach my $siteId ( @siteIds ) {
        my $site         = $sites->{$siteId};
        my $siteInBackup = $sitesInBackup->{$siteId};

        $site->undeploy();
        $siteInBackup->restoreSite( $backup, $site );
    }

    debug( 'Restoring AppConfigurations' );

    foreach my $appConfigId ( @appConfigIds ) {
        my $site = $sitesOfAppConfigs->{$appConfigId};
        $site->restoreAppConfiguration( $backup, $site->siteId, $site->appConfig( $appConfigId ));
    }

    debug( 'Resuming sites' );

    my $resumeTriggers = {};
    foreach my $site ( values %$sitesToResume ) {
        $site->resume( $resumeTriggers );
    }
    IndieBox::Host::executeTriggers( $resumeTriggers );

    debug( 'Running upgraders' );

    foreach my $site ( values %$sitesToResume ) {
        foreach my $appConfig ( @{$site->appConfigs} ) {
            $appConfig->runUpgrader();
        }
    }

    return 1;
}

##
# Return help text for this command.
# return: hash of synopsis to help text
sub synopsisHelp {
    return {
        <<SSS => <<HHH,
    --in <backupfile>
SSS
    Restore all sites contained in backupfile. This includes all
    applications and their data. This will overwrite the currently
    deployed sites and all of their data. Currently deployed sites not
    mentioned in backupfile will remain unchanged. 
HHH
        <<SSS => <<HHH,
    --siteid <siteid> --in <backupfile>
SSS
    Restore the site with siteid contained in backupfile. This includes
    all applications and their data. This will overwrite the currently
    deployed site with siteid and all of its data. No site other than
    the site with siteid will be affected.
HHH
        <<SSS => <<HHH,
    --siteid <fromsiteid> --translate <fromsiteid>=><tositeid> --in <backupfile>
SSS
    Restore the site with siteid tositeid from the backup contained in
    backupfile with siteid fromsiteid. This includes all applications
    and their data. This will overwrite the currently deployed site
    with tositeid and all of its data. No site other than the site with
    tositeid will be affacted.
    Note: there is no space before and after the =>, and the > may have
    to be escaped in your shell.
HHH
        <<SSS => <<HHH,
    --appconfigid <appconfigid> --in <backupfile>
SSS
    Restore AppConfiguration appconfigid on a currently deployed site to
    the configuration and data contained in the backup file. This will
    overwrite the currently deployed AppConfiguration and all of its data.
HHH
        <<SSS => <<HHH
    --appconfigid <fromappconfigid> --translate <fromappconfigid>=><toappconfigid> --in <backupfile>
SSS
    Restore AppConfiguration toappconfigid on a currently deployed site
    to the configuration and data contained in the backup file for
    AppConfiguration fromappconfigid. This will overwrite the currently 
    eployed AppConfiguration toappconfigid and all of its data.
    Note: there is no space before and after the =>, and the > may have
    to be escaped in your shell.
HHH
    };
}

1;
