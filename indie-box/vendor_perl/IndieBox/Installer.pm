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

package IndieBox::Installer;

use IndieBox::Mysql;
use IndieBox::ResourceManager;

##
# Invoked by pacman after this package has been installed for the first time
# $newVersion: identifier of the installed package version
sub post_install {
    my $version = shift;

    IndieBox::Mysql::ensureRunning();
    IndieBox::Mysql::ensureRootPassword();
    IndieBox::ResourceManager::initializeIfNeeded();
}

##
# Invoked by pacman after this package has been upgraded
# $newVersion: identifier of the new package version
# $oldVersion: identifier of the old package version
sub post_upgrade {
    my $newVersion = shift;
    my $oldVersion = shift;

    IndieBox::Mysql::ensureRunning();
    IndieBox::Mysql::ensureRootPassword();
    IndieBox::ResourceManager::initializeIfNeeded();
}

##
# Invoked by pacman before this package is being removed
# $newVersion: identifier of the new package version
# $oldVersion: identifier of the old package version
sub pre_remove {
    my $version = shift;

    print <<MSG;

Hey hacker,

Sorry to see you go.
Hope to see you again in the future.

Regards,
    Indie Box Project
    http://indieboxproject.org/

MSG
}
1;
