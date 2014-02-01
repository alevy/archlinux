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
use IndieBox::Configuration;
use IndieBox::Logging;
use IndieBox::Site;
use IndieBox::Utils qw( readJsonFromFile myexec );
use Sys::Hostname;

my $SITES_DIR      = '/var/lib/indie-box/sites';
my $HOST_CONF_FILE = '/etc/indie-box/config.json';
my $hostConf       = undef;
my $now            = time();

##
# Ensure that all essential services run on this Host.
sub ensureEssentialServicesRunning {
    trace( 'Host::ensureEssentialServicesRunning' );

    my @services = qw( cronie ntpd );
    foreach my $service ( @services ) {
        IndieBox::Utils::myexec( 'systemctl enable ' . $service );
        IndieBox::Utils::myexec( 'systemctl restart ' . $service );
    }

    1;
}

##
# Obtain the host Configuration object.
# return: Configuration object
sub config {
    unless( $hostConf ) {
        my $raw = readJsonFromFile( $HOST_CONF_FILE );

        $raw->{hostname}        = hostname;
        $raw->{now}->{unixtime} = $now;
        $raw->{now}->{tstamp}   = IndieBox::Utils::time2string( $now );

        $hostConf = new IndieBox::Configuration( 'Host', $raw );
    }
}

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
# Find a particular Site currently installed on this host.
# $siteId: the Site identifier
# return: the Site
sub findSiteById {
    my $siteId = shift;

    my $jsonFile = "$SITES_DIR/$siteId.json";
    if( -r $jsonFile ) {
        my $siteJson = readJsonFromFile( $jsonFile );
        my $site     = new IndieBox::Site( $siteJson );

        return $site;
    }
    return undef;
}

##
# A site has been deployed.
# $site: the newly deployed or updated site
sub siteDeployed {
    my $site = shift;

    my $siteId   = $site->siteId;
    my $siteJson = $site->siteJson;

    trace( 'Host::siteDeployed', $siteId );

    IndieBox::Utils::writeJsonToFile( "$SITES_DIR/$siteId.json", $siteJson );
}

##
# A site has been undeployed.
# $site: the undeployed site
sub siteUndeployed {
    my $site = shift;

    my $siteId   = $site->siteId;

    trace( 'Host::siteUndeployed', $siteId );

    IndieBox::Utils::deleteFile( "$SITES_DIR/$siteId.json" );
}

##
# Determine the applicable role names for this host. For now, this is
# fixed. This is returned in the sequence in which installation typically
# takes place: provision database before setting up the web server.
# return: the applicable role names
sub applicableRoleNames {
    return [ 'mysql', 'apache2' ];
}

##
# Execute the named triggers
# $triggers: array of trigger names
sub executeTriggers {
    my $triggers = shift;

    trace( 'Host::executeTriggers' );

    my @triggerList;
    if( ref( $triggers ) eq 'HASH' ) {
        @triggerList = keys %$triggers;
    } elsif( ref( $triggers ) eq 'ARRAY' ) {
        @triggerList = @$triggers;
    } else {
        fatal( 'Unexpected type:', $triggers );
    }
    foreach my $trigger ( @triggerList ) {
        if( 'httpd-reload' eq $trigger ) {
            IndieBox::Apache2::reload();
        } elsif( 'httpd-restart' eq $trigger ) {
            IndieBox::Apache2::restart();
        } else {
            IndieBox::Logging::warn( 'Unknown trigger:', $trigger );
        }
    }
}

##
# Update all the code currently installed on this host.
sub updateCode {
    trace( 'Host::updateCode' );

    myexec( 'pacman -Syu --noconfirm' );
}

##
# Clean package cache
sub purgeCache {
    trace( 'Host::purgeCache' );

    myexec( 'pacman -Sc --noconfirm > /dev/null' );
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
        fatal( 'Unexpected type:', $packages );
    }

    # only install what isn't installed yet
    my @filteredPackageList = grep { myexec( "pacman -Q $_ > /dev/null 2>&1" ) } @packageList;

    trace( 'Host::installPackages', @filteredPackageList );

    if( @filteredPackageList ) {
        my $err;
        if( myexec( 'pacman -S --noconfirm ' . join( ' ', @filteredPackageList ), undef, undef, \$err )) {
            fatal( 'Failed to install package(s). Pacman says:', $err );
        }
    }
}

1;
