#!/usr/bin/perl
#
# A general-purpose superclass for AppConfiguration items for Indie Box Project
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

package IndieBox::AppConfigurationItems::AppConfigurationItem;

use IndieBox::TemplateProcessor::Passthrough;
use IndieBox::TemplateProcessor::Varsubst;
use IndieBox::TemplateProcessor::Perlscript;
use IndieBox::TemplateProcessor::Passthrough;

use fields qw( json appConfig installable );

##
# Constructor
# $json: the JSON fragment from the manifest JSON
# $appConfig: the AppConfiguration object that this item belongs to
# $installable: the Installable to which this item belongs to
sub new {
    my $self      = shift;
    my $json      = shift;
    my $appConfig = shift;
    my $installable = shift;

    unless( ref $self ) {
        $self = fields::new( $self );
    }
    $self->{json}        = $json;
    $self->{appConfig}   = $appConfig;
    $self->{installable} = $installable;

    return $self;
}

##
# Default implementation for an installer.
# $dir: the directory in which the app was installed
# $config: the Configuration object that knows about symbolic names and variables
sub runInstaller {
    my $self   = shift;
    my $dir    = shift;
    my $config = shift;

    error( "Cannot perform runInstaller() on $self" );
}

##
# Convert a permission attribute given as string into octal
# $s: permission attribute as string
# $default: octal mode if $s is undef
# return: octal
sub permissionToMode {
    my $self       = shift;
    my $permission = shift;
    my $default    = shift;

    if( $permission ) {
        return oct( $permission );
    } else {
        return $default;
    }
}

##
# Internal helper to instantiate the right subclass of TemplateProcessor.
# return: instance of subclass of TemplateProcessor
sub _instantiateTemplateProcessor {
    my $self         = shift;
    my $templateLang = shift;
    my $ret;

    if( !defined( $templateLang )) {
        $ret = new IndieBox::TemplateProcessor::Passthrough();

    } elsif( 'varsubst' eq $templateLang ) {
        $ret = new IndieBox::TemplateProcessor::Varsubst();

    } elsif( 'perlscript' eq $templateLang ) {
        $ret = new IndieBox::TemplateProcessor::Perlscript();

    } else {
        error( "Unknown templatelang: $templateLang" );
        $ret = new IndieBox::TemplateProcessor::Passthrough();
    }
    return $ret;
}

1;
