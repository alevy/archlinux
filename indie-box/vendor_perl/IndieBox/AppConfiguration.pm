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

use IndieBox::Logging;
use JSON;
use fields qw{json site};

##
# Constructor.
# $json: JSON object containing one appconfig section of a Site JSON
# $site: Site object representing the site that this AppConfiguration belongs to
# return: AppConfiguration object
sub new {
    my $self = shift;
    my $json = shift;
    my $site = shift;

    unless( ref $self ) {
        $self = fields::new( $self );
    }
    $self->{json} = $json;
    $self->{site} = $site;

    # No checking required, IndieBox::Site::new has done that already
    return $self;
}

##
# Obtain identifier of this AppConfiguration.
# return: string
sub appConfigId {
    my $self = shift;

    return $self->{json}->{appconfigid};
}

##
# Obtain the Site object that this AppConfiguration belongs to.
# return: Site object
sub site {
    my $self = shift;

    return $self->{site};
}

##
# Determine whether this AppConfiguration is the default AppConfiguration at this Site.
# return: 0 or 1
sub isDefault {
    my $self = shift;

    my $isDefault = $self->{json}->{isdefault};
    if( defined( $isDefault ) && JSON::is_bool( $isDefault ) && $isDefault ) {
        return 1;
    } else {
        return 0;
    }
}

1;
