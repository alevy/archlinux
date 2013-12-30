#!/usr/bin/perl
#
# Passed to an AppTest. Holds the run-time information the test needs to function.
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

package IndieBox::Testing::TestContext;

use fields qw( siteJson appConfigJson scaffold appTest testPlan ip );
use IndieBox::Logging;
use IndieBox::Testing::TestingUtils;
use IndieBox::Utils;
use WWW::Curl::Easy;

##
# Instantiate the TextContext.
# $scaffold: the scaffold used for the test
# $appTest: the AppTest being executed
# $testPlan: the TestPlan being execited
# $ip: the IP address at which the application being tested can be accessed
sub new {
    my $self          = shift;
    my $siteJson      = shift;
    my $appConfigJson = shift;
    my $scaffold      = shift;
    my $appTest       = shift;
    my $testPlan      = shift;
    my $ip            = shift;

    unless( ref $self ) {
        $self = fields::new( $self );
    }

    $self->{siteJson}      = $siteJson;
    $self->{appConfigJson} = $appConfigJson;
    $self->{scaffold}      = $scaffold;
    $self->{appTest}       = $appTest;
    $self->{testPlan}      = $testPlan;
    $self->{ip}            = $ip;

    return $self;
}

##
# Determine the hostname of the application being tested
# return: hostname
sub hostName {
    my $self = shift;

    return $self->{siteJson}->{hostname};
}

##
# Determine the context path of the application being tested
# return: context
sub context {
    my $self = shift;

    return $self->{appConfigJson}->{context};
}

##
# Perform an HTTP GET request on the host on which the application is being tested.
# $relativeUrl: appended to the host's URL
# return: HTTP response, including all headers
sub httpGetRelativeHost {
    my $self        = shift;
    my $relativeUrl = shift;

    my $url = 'http://' . $self->hostName . $relativeUrl;

    debug( 'Accessing url', $url );
    
    my $response;
    
    my $curl = WWW::Curl::Easy->new;

    $curl->setopt( CURLOPT_HEADER,  1 );
    $curl->setopt( CURLOPT_URL,     $url );
    # $curl->setopt( CURLOPT_RESOLVE, [ $self->hostName . ':80:' . $self->{ip}, $self->hostName . ':443:' . $self->{ip} ] );
    # This seems broken in perl-www-curl 4.15
    $curl->setopt( CURLOPT_WRITEDATA, \$response );

    my $retcode = $curl->perform;

    debug( 'curl produced retcode:', $retcode, 'response:', $response );

    if( $retcode == 0 ) {
        $self->reportError( 'HTTP request failed:', $curl->strerror( $retcode ), $curl->errbuf );
    }
    return $response;
}

##
# Perform an HTTP GET request on the application being tested, appending to the context URL.
# $relativeUrl: appended to the application's context URL
# return: HTTP response, including all headers
sub httpGetRelativeContext {
    my $self        = shift;
    my $relativeUrl = shift;

    return $self->httpGetRelativeHost( $self->context() . $relativeUrl );
}

##
# Perform an HTTP POST request on the host on which the application is being tested.
# $relativeUrl: appended to the host's URL
# $payload: hash of posted parameters
# return: HTTP response, including all headers
sub httpPostRelativeHost {
    my $self        = shift;
    my $relativeUrl = shift;
    my $postData    = shift;

    my $url = 'http://' . $self->hostName . $relativeUrl;
    my $response;

    my $postString = join(
            '&',
            map { IndieBox::Testing::TestingUtils::uri_escape( $_ ) . '=' . IndieBox::Testing::TestingUtils::uri_escape( $postData->{$_} ) } keys %$postData );
    
    my $curl = WWW::Curl::Easy->new;

    $curl->setopt( CURLOPT_HEADER, 1 );
    $curl->setopt( CURLOPT_URL, $url );
    # $curl->setopt( CURLOPT_RESOLVE, [ $self->hostName . ':80:' . $self->{ip}, $self->hostName . ':443:' . $self->{ip} ] );
    # This seems broken in perl-www-curl 4.15
    $curl->setopt( CURLOPT_POST, 1 );
    $curl->setopt( CURLOPT_POSTFIELDS, $postString );
    $curl->setopt( CURLOPT_POSTFIELDSIZE, length( $postString ));

    $curl->setopt( CURLOPT_WRITEDATA, \$response );

    my $retcode = $curl->perform;

    if( $retcode == 0 ) {
        $self->reportError( 'HTTP request failed:', $curl->strerror( $retcode ), $curl->errbuf );
    }
    return $response;
}

##
# Perform an HTTP POST request on the application being tested, appending to the context URL,
# with the provided payload.
# $relativeUrl: appended to the application's context URL
# $payload: hash of posted parameters
# return: HTTP response, including all headers
sub httpPostRelativeContext {
    my $self        = shift;
    my $relativeUrl = shift;
    my $postData    = shift;

    return $self->httpPostRelativeHost( $self->context() . $relativeUrl, $postData );
}
        
##
# Report an error.
# @args: error message
sub reportError {
    my $self = shift;
    my @args = @_;

    error( 'TestContext reports error:', @_ );
}

##
# Destroy this context.
sub destroy {
    my $self = shift;
}

1;
