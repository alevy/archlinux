#!/usr/bin/perl
#
# Factors out operations common to many kinds of TestPlans that use a single site.
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

package IndieBox::Testing::AbstractSingleSiteTestPlan;

use base qw( IndieBox::Testing::AbstractTestPlan );
use fields qw( siteId appConfigId hostName );
use IndieBox::Logging;

##
# Instantiate the TestPlan.
sub new {
    my $self = shift;

    unless( ref $self ) {
        $self = fields::new( $self );
    }
    $self->SUPER::new();

    my $hostName = ref $self;
    $hostName =~ s!^.*::!!;
    $hostName = 'testhost-' . lc( $hostName ) . IndieBox::Utils::generateRandomHex( 8 );
    
    # generate random identifiers and hostnames, so multiple tests can run at the same time
    $self->{siteId}      = 's' . IndieBox::Utils::generateRandomHex( 32 );
    $self->{appConfigId} = 'a' . IndieBox::Utils::generateRandomHex( 32 );
    $self->{hostName}    = $hostName;

    return $self;
}

##
# Obtain the siteId of the site currently being tested.
# return: the siteId
sub siteId {
    my $self = shift;

    return $self->{siteId};
}

##
# Obtain the hostname of the site currently being tested.
# return: the hostname
sub hostName {
    my $self = shift;

    return $self->{hostName};
}

##
# Obtain the appconfigid of the AppConfiguration currently being tested.
# return the appconfigid
sub appConfigId {
    my $self = shift;

    return $self->{appConfigId};
}

##
# Run this TestPlan
# $scaffold: the Scaffold to use
# $test: the AppTest to run
sub run {
    my $self     = shift;
    my $scaffold = shift;
    my $test     = shift;
    
    error( 'Must override AbstractTestPlan::run' );
    return 0;
}

##
# Helper to create the AppConfiguration JSON fragment for this test
# $test: the AppTest
# return: the AppConfiguration JSON fragment
sub _createAppConfiurationJson {
    my $self = shift;
    my $test = shift;

    my $app     = $test->getApp();
    my $context = $app->fixedContext();
    unless( defined( $context )) {
        $context = $app->defaultContext();
    }

    my $appconfig = {
        'context'     => $context,
        'appconfigid' => $self->{appConfigId},
        'appid'       => $test->{packageName}
    };

    my $custPointValues = $test->getCustomizationPointValues();
    if( $custPointValues ) {
        my $jsonHash = {};
        $appconfig->{customizationpoints}->{$app->packageName()} = $jsonHash;

        my $hash = $custPointValues->asHash();
        while( my( $name, $value ) = each %$hash ) {
            $jsonHash->{$name}->{value} = $value;
        }
    }
    return $appconfig;
}

##
# Helper to create the Site JSON for this test.
# $test: the AppTest
# $appConfigJson: the AppConfiguration JSON fragment for this test
# return: the site JSON
sub _createSiteJson {
    my $self          = shift;
    my $test          = shift;
    my $appConfigJson = shift;

    my $site = {
        'siteid'     => $self->{siteId},
        'hostname'   => $self->{hostName},
        'appconfigs' => [ $appConfigJson ]
    };

    return $site;
}

1;
