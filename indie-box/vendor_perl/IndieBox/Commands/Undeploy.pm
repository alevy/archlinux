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
use Getopt::Long qw( GetOptionsFromArray );
use IndieBox::AdminUtils;
use IndieBox::Host;
use IndieBox::Logging;
use IndieBox::Utils;

##
# Execute this command.
# return: desired exit code
sub run {
    my @args = @_;

    my @siteIds = ();

    my $parseOk = GetOptionsFromArray(
            \@args,
            'siteid=s' => \@siteIds );

    if( !$parseOk || @args || !@siteIds ) {
        fatal( 'Invalid command-line arguments' );
    }
    
    debug( 'Looking for site(s)' );

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

    my $adminBackups = {};
    foreach my $oldSite ( values %$oldSites ) {
        my $backup  = $oldSite->backup();
        $oldSite->undeploy();
        $adminBackups->{$oldSite->siteId} = $backup;
    }
    
    IndieBox::AdminUtils::purgeBackups( values %$adminBackups );
    
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
    };
}

1;
