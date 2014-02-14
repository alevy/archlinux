#!/usr/bin/perl
#
# Utilities for the commands in this package.
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

package IndieBox::AdminUtils;

use IndieBox::Host;
use IndieBox::Logging;
use IndieBox::Utils;

##
# Find available commands.
# return: hash of command name to full package name
sub findCommands {
    my $ret = IndieBox::Utils::findPerlShortModuleNamesInPackage( 'IndieBox::Commands' );

    return $ret;
}

1;
