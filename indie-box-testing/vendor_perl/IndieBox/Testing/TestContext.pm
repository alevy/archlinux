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

use fields qw( siteJson appConfigJson scaffold appTest testPlan ip curl cookieFile );
use IndieBox::Logging;
use IndieBox::Testing::TestingUtils;
use IndieBox::Utils;

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

    my $hostName   = $self->hostName;
    my $cookieFile = File::Temp->new();

    $self->{cookieFile} = $cookieFile->filename;
    
    $self->{curl} = "curl -s -v --cookie-jar '$cookieFile' -b '$cookieFile' --resolve '$hostName:80:$ip' --resolve '$hostName:443:$ip'";
    # -v to get HTTP headers

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
# return: hash containing content and headers of the HTTP response
sub httpGetRelativeHost {
    my $self        = shift;
    my $relativeUrl = shift;

    my $url = 'http://' . $self->hostName . $relativeUrl;

    debug( 'Accessing url', $url );

    my $cmd = $self->{curl};
    $cmd .= " '$url'";
    
    my $stdout;
    my $stderr;
    if( IndieBox::Utils::myexec( $cmd, undef, \$stdout, \$stderr )) {
        $self->reportError( 'HTTP request failed:', $stderr );
    }

    return { 'content' => $stdout, 'headers' => $stderr };
}

##
# Perform an HTTP GET request on the application being tested, appending to the context URL.
# $relativeUrl: appended to the application's context URL
# return: hash containing content and headers of the HTTP response
sub httpGetRelativeContext {
    my $self        = shift;
    my $relativeUrl = shift;

    return $self->httpGetRelativeHost( $self->context() . $relativeUrl );
}

##
# Perform an HTTP POST request on the host on which the application is being tested.
# $relativeUrl: appended to the host's URL
# $payload: hash of posted parameters
# return: hash containing content and headers of the HTTP response
sub httpPostRelativeHost {
    my $self        = shift;
    my $relativeUrl = shift;
    my $postData    = shift;

    my $url = 'http://' . $self->hostName . $relativeUrl;
    my $response;

    debug( 'Posting to url', $url );

    my $postString = join(
            '&',
            map { IndieBox::Testing::TestingUtils::uri_escape( $_ ) . '=' . IndieBox::Testing::TestingUtils::uri_escape( $postData->{$_} ) } keys %$postData );
    
    my $cmd = $self->{curl};
    $cmd .= " -d '$postString'";
    $cmd .= " '$url'";
    
    my $stdout;
    my $stderr;
    if( IndieBox::Utils::myexec( $cmd, undef, \$stdout, \$stderr )) {
        $self->reportError( 'HTTP request failed:', $stderr );
    }
    return { 'content' => $stdout, 'headers' => $stderr };
}

##
# Perform an HTTP POST request on the application being tested, appending to the context URL,
# with the provided payload.
# $relativeUrl: appended to the application's context URL
# $payload: hash of posted parameters
# return: hash containing content and headers of the HTTP response
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

    # could be used to delete cookie files, but right now Perl does this itself
}

1;
