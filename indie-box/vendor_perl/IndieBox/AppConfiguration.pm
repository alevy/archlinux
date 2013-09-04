#!/usr/bin/perl
#
# Represents an AppConfiguration on a Site for Indie Box Project
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

package IndieBox::AppConfiguration;

use JSON;

use fields qw{json};

##
# Constructor.
# $json: JSON object containing one appconfig section of a Site JSON
# return: AppConfiguration object
sub new {
    my $self = shift;
    my $json = shift;

    unless( ref $self ) {
        $self = fields::new( $self );
    }
    $self->{json} = $json;

    # No checking required, IndieBox::Site::new has done that already
    return $self;
}

1;
