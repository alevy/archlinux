#!/usr/bin/perl
#
# A script-based TemplateProcessor for Indie Box Project
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

package IndieBox::TemplateProcessor::Perlscript;

use base qw( IndieBox::TemplateProcessor::TemplateProcessor );
use fields;

##
# Constructor
# return: the created File object
sub new {
    my $self = shift;

    unless( ref $self ) {
        $self = fields::new( $self );
    }
    $self->SUPER::new();

    return $self;
}

##
# Process content
# $raw: the input content
# $config: the applicable Configuration object
# $rawFileName: the source of the $raw content
# return: the output content
sub process {
    my $self        = shift;
    my $raw         = shift;
    my $config      = shift;
    my $rawFileName = shift;

    my $ret = eval $raw;
    unless( $ret ) {
        error( "Error when attempting to eval file $rawFileName: $@" );
    }

    return $ret;
}

1;
