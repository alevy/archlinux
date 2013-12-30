#!/usr/bin/perl
#
# Abstract superclass for all Scaffold implementations.
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

package IndieBox::Testing::AbstractScaffold;

use fields;
use IndieBox::Logging;
use IndieBox::Utils;

##
# Instantiate the Scaffold. This may take a long time.
# This method must be overridden by subclasses.
sub setup {
    my $self = shift;

    unless( ref $self ) {
        fatal( 'Must override Scaffold' );
    }

    return $self;
}

##
# Deploy a site
# $site: site JSON
sub deploy {
    my $self = shift;
    my $site = shift;

    $self->invokeOnTarget( 'indie-box-admin deploy', IndieBox::Utils::writeJsonToString( $site ));
}

##
# Undeploy a site
# $site: site JSON
sub undeploy {
    my $self = shift;
    my $site = shift;

    $self->invokeOnTarget( 'indie-box-admin undeploy --siteid ' . $site->{siteid} );
}

##
# Backup a site.
# $site: site JSON
# return: identifier of the backup, e.g. filename
sub backup {
    my $self = shift;
    my $site = shift;

    my $file;
    
    $self->invokeOnTarget( 'F=$(mktemp indie-box-testing-XXXXX.indie-backup); indie-box-admin backup --siteid ' . $site->{siteid} . ' --out $F; echo $F', undef, \$file );
    return $file;
}

##
# Restore a site
# $site: site JSON
# $identifier: identifier of the backupobtained earlier via backup
sub restore {
    my $self       = shift;
    my $site       = shift;
    my $identifier = shift;

    $self->invokeOnTarget( 'indie-box-admin restore --siteid ' . $site->{siteid} . ' --in ' . $identifier );
}

##
# Destroy a previously created backup
sub destroyBackup {
    my $self       = shift;
    my $site       = shift;
    my $identifier = shift;

    $self->invokeOnTarget( 'rm ' . $identifier );
}

##
# Teardown this Scaffold.
# This method must be overridden by subclasses.
sub teardown {
    my $self = shift;

    return 0;
}

##
# Helper method to invoke a command on the target. This must be overridden by subclasses.
# $cmd: command
# $stdin: content to pipe into stdin
sub invokeOnTarget {
    my $self  = shift;
    my $cmd   = shift;
    my $stdin = shift;

    error( 'Must override Scaffold::invokeOnTarget' );
}

##
# Obtain the IP address of the target.  This must be overridden by subclasses.
# return: target IP
sub getTargetIp {
    my $self  = shift;

    error( 'Must override Scaffold::getTargetIp' );
}
    
1;
