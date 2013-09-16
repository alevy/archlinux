#!/usr/bin/perl
#
# Represents a Host for Indie Box Project
#
# Copyright (C) 2013 Indie Box Project http://indieboxproject.org/
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

package IndieBox::Host;

use IndieBox::Apache2;
use IndieBox::Logging;
use IndieBox::Site;
use IndieBox::Utils qw( readJsonFromFile myexec );

my $SITES_DIR = '/etc/indie-box/sites';

##
# Determine all Sites currently installed on this host.
# return: hash of siteId to Site
sub sites {
    my %ret = ();
    foreach my $f ( <$SITES_DIR/*.json> ) {
        my $siteJson = readJsonFromFile( $f );
        my $site     = new IndieBox::Site( $siteJson );
        $ret{$site->siteId()} = $site;
    }
    return \%ret;
}

##
# A site has been deployed.
# $site: the newly deployed or updated site
sub siteDeployed {
    my $site = shift;

    my $siteId   = $site->siteId;
    my $siteJson = $site->siteJson;

    IndieBox::Utils::writeJsonToFile( "$SITES_DIR/$siteId.json", $siteJson );
}

##
# A site has been undeployed.
# $site: the undeployed site
sub siteUndeployed {
    my $site = shift;

    my $siteId   = $site->siteId;

    IndieBox::Utils::deleteFile( "$SITES_DIR/$siteId.json" );
}

##
# Determine the applicable role names for this host. For now, this is
# fixed.
# return: the applicable role names
sub applicableRoleNames {
    return [ 'apache2', 'mysql' ];
}

##
# Execute the named triggers
# $triggers: array of trigger names
sub executeTriggers {
    my $triggers = shift;

    my @triggerList;
    if( ref( $triggers ) eq 'HASH' ) {
        @triggerList = keys %$triggers;
    } elsif( ref( $triggers ) eq 'ARRAY' ) {
        @triggerList = @$triggers;
    } else {
        die( "Unexpected type $triggers" );
    }
    foreach my $trigger ( @triggerList ) {
        if( 'httpd-reload' eq $trigger ) {
            IndieBox::Apache2::reload();
        } elsif( 'httpd-restart' eq $trigger ) {
            IndieBox::Apache2::restart();
        } else {
            warn( "Unknown trigger: $trigger" );
        }
    }
}

##
# Update all the code currently installed on this host.
sub updateCode {
    myexec( 'pacman -Syu' );
}

##
# Install the named packages.
# $packages: List of packages
sub installPackages {
    my $packages = shift;

    my @packageList;
    if( ref( $packages ) eq 'HASH' ) {
        @packageList = keys %$packages;
    } elsif( ref( $packages ) eq 'ARRAY' ) {
        @packageList = @$packages;
    } else {
        die( "Unexpected type $packages" );
    }
    if( @packageList ) {
        myexec( 'pacman -S --noconfirm ' . join( ' ', @packageList ));
    }
}

1;
