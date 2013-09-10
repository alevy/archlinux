#!/usr/bin/perl
#
# Manifest checking routines. This is factored out to not clutter the main
# functionality.
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

package IndieBox::InstallableManifest;

use Exporter qw( import );
use IndieBox::Logging;
use JSON;

our @EXPORT_OK = qw( validFilename );

##
# Check validity of the manifest JSON.
# return: 1 or exits with fatal error
sub checkManifest {
    my $json = shift;

    unless( $json ) {
        fatal( "No manifest JSON present" );
    }
    unless( $json->{type} ) {
        fatal( "Manifest JSON: type: missing" );
    }

    if( $json->{roles} ) {
        unless( ref( $json->{roles} ) eq 'HASH' ) {
            fatal( "Manifest JSON: roles section: not a JSON object" );
        }
    }
    if( $json->{customizationpoints} ) {
        unless( ref( $json->{customizationpoints} ) eq 'HASH' ) {
            fatal( "Manifest JSON: customizationpoints section: not a JSON object" );
        }
    }
}

##
# Check validity of an absolute and relative filename
# return: 1 if valid
sub validFilename {
    my $relativeFilename = shift;
    my $allowRegexSubst  = shift || 0;

    return 1; # FIXME
}

1;
