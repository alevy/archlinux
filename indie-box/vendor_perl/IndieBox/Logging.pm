#!/usr/bin/perl
#
# Logging facilities.
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

package IndieBox::Logging;

use Exporter qw( import );
use Log::Log4perl qw( :easy );
use Log::Log4perl::Level;

our @EXPORT = qw( debug warn error fatal );
my $log;

BEGIN {
    my $logfile = '/etc/indie-box/log4perl.conf';

    if( -r $logfile ) {
        Log::Log4perl->init( $logfile );
    } else {
        my $config = q(
log4perl.rootLogger=INFO,CONSOLE

log4perl.appender.CONSOLE=Log::Log4perl::Appender::Screen
log4perl.appender.CONSOLE.stderr=1
log4perl.appender.CONSOLE.layout=PatternLayout
log4perl.appender.CONSOLE.layout.ConversionPattern=%-5p: %m%n
);
        Log::Log4perl->init( \$config );
    }

    $log = Log::Log4perl->get_logger( __FILE__ );
    $log->trace( "Initialized log4perl" );
}

##
# Avoid console output.
sub setQuiet {
    my $consoleAppender = Log::Log4perl->appenders()->{'CONSOLE'};

    if( $consoleAppender ) {
        $consoleAppender->threshold( $ERROR );
    }
}

##
# Emit a debug message.
# $msg: the message
sub debug {
    my $msg = shift;

    $log->debug( $msg );

    1;
}

##
# Emit an info message.
# $msg: the message
sub info {
    my $msg = shift;

    $log->info( $msg );

    1;
}

##
# Emit awarning message.
# $msg: the message
sub warn {
    my $msg = shift;

    $log->warn( $msg );

    1;
}

##
# Emit an error message.
# $msg: the message
sub error {
    my $msg = shift;

    $log->error( $msg );

    1;
}

##
# Emit a fatal error message and exit with code 1.
# $msg: the message
sub fatal {
    my $msg = shift;

    $log->fatal( $msg );

    exit 1;
}

1;
