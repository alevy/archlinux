#!/usr/bin/perl
#
# Represents an App for Indie Box Project
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

package IndieBox::App;

use base qw( IndieBox::Installable );
use fields;

use IndieBox::Configuration;
use IndieBox::Logging;
use IndieBox::Utils qw( readJsonFromFile );
use JSON;

##
# Constructor.
# $packageName: unique identifier of the package
sub new {
    my $self        = shift;
    my $packageName = shift;

    unless( ref $self ) {
        $self = fields::new( $self );
    }
    $self->SUPER::new( $packageName );

    if( $self->{config}->get( 'indiebox.checkmanifest', 1 )) {
        use IndieBox::AppManifest;

        my $codeDir = $self->{config}->getResolve( 'package.codedir' );

        IndieBox::AppManifest::checkManifest( $self->{json}, $codeDir );
    }
    return $self;
}

##
# If this app can only be run at a particular context path, return that context path
# return: context path
sub fixedContext {
    my $self = shift;

    return $self->{json}->{roles}->{apache2}->{fixedcontext};
}

##
# If this app can be run at any context, return the default context path
# return: context path
sub defaultContext {
    my $self = shift;

    return $self->{json}->{roles}->{apache2}->{defaultcontext};
}

1;
