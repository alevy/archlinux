#!/usr/bin/perl
#
# Factors out operations common to many kinds of TestPlans.
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

package IndieBox::Testing::AbstractTestPlan;

use fields;
use IndieBox::Logging;

##
# Instantiate the TestPlan.
sub new {
    my $self = shift;

    unless( ref $self ) {
        $self = fields::new( $self );
    }

    return $self;
}

##
# If interactive, ask the user what to do next. If non-interactive, proceed.
# $question: the question to ask
# $interactive: if false, continue and do not ask
# $successOfLastStep: did the most recent step succeed?
# $successOfPlanSoFar: if true, all steps have been successful so far
sub askUser {
    my $self               = shift;
    my $question           = shift;
    my $interactive        = shift;
    my $successOfLastStep  = shift;
    my $successOfPlanSoFar = shift;

    my $repeat = 0;
    my $abort  = 0;   
    my $quit   = !$successOfLastStep;

    if( $interactive ) {
        my $fullQuestion;
        if( $question ) {
            $fullQuestion = $question . ' (' . ( $successOfLastStep ? 'success' : 'failure' ) . ').';
        } else {
            $fullQuestion = 'Last step ' . ( $successOfLastStep ? 'succeeded' : 'failed' ) . '.';
        }
        $fullQuestion .= " C(ontinue)/R(epeat)/A(bort)/Q(uit)? ";
        
        while( 1 ) {
            print STDERR $fullQuestion;

            my $userinput = <STDIN>;
            if( $userinput =~ /^\s*c\s*$/i ) {
                $repeat = 0;
                $abort  = 0;
                $quit   = 0;
                last;
            }
            if( $userinput =~ /^\s*r\s*$/i ) {
                $repeat = 1;
                $abort  = 0;
                $quit   = 0;
                last;
            }
            if( $userinput =~ /^\s*a\s*$/i ) {
                $repeat = 0;
                $abort  = 1;
                $quit   = 0;
                last;
            }
            if( $userinput =~ /^\s*q\s*$/i ) {
                $repeat = 0;
                $abort  = 0;
                $quit   = 1;
                last;
            }
        }
    }

    return( $repeat, $abort, $quit );
}

1;
