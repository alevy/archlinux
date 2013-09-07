#!/usr/bin/perl
#
# Represents a Host for Indie Box Project
#
# Copyright (C) 2013 Johannes Ernst
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

use IndieBox::Logging;
use IndieBox::Site;
use IndieBox::Utils qw( readJsonFromFile );

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
# Update all the code currently installed on this host.
sub updateCode {
    print "Placeholder: update all code in this device.\n";
}

1;
