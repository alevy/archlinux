#!/usr/bin/perl
#
# Apache2 abstraction for the Indie Box Project
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

package IndieBox::Apache2;

use DBI;
use IndieBox::Logging;
use IndieBox::Utils;

my $mainConfigFile   = '/etc/httpd/conf/httpd.conf';
my $ourConfigFile    = '/etc/httpd/conf/httpd-indie-box.conf';
my $modsAvailableDir = '/etc/httpd/indie-box/mods-available';
my $modsEnabledDir   = '/etc/httpd/indie-box/mods-enabled';

##
# Ensure that Apache is running and config file is correct
sub ensureRunning {
    debug( "Apache2::ensureRunning" );

    fixConfigFiles();
    activateModules( 'alias', 'authz_host', 'deflate', 'dir', 'mime' ); # always need those

    IndieBox::Utils::myexec( 'systemctl enable httpd' );
    IndieBox::Utils::myexec( 'systemctl restart httpd' );

    1;
}

##
# Reload configuration
sub reload {
    debug( "Apache2::reload" );

    IndieBox::Utils::myexec( 'systemctl reload httpd' );

    1;
}

##
# Make the changes to Apache configuration files that are needed by Indie Box.
sub fixConfigFiles {
    debug( "Apache2::fixConfigFiles" );

    if( -e $ourConfigFile ) {
        IndieBox::Utils::myexec( "cp -f '$ourConfigFile' '$mainConfigFile'" );
    } else {
        warn( "Config file $ourConfigFile is missing" );
    }
}

##
# Activate one ore more Apache modules
sub activateModules {
    my @modules = @_;

    foreach my $module ( @modules ) {
        debug( "Activating Apache2 module: $module" );

        if( -e "$modsEnabledDir/$module.load" ) {
            next; # enabled already
        }
        unless( -e "$modsAvailableDir/$module.load" ) {
            warn( "Cannot find Apache2 module $module; not enabling" );
            next;
        }
        IndieBox::Utils::myexec( "ln -s '$modsAvailableDir/$module.load' '$modsEnabledDir/$module.load'" );
    }
    1;
}

1;
