#!/usr/bin/perl
#
# Command that lists the currently deployed sites.
#
# Copyright (C) 2013-2014 Indie Box Project http://indieboxproject.org/
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

package IndieBox::Commands::Listsites;

use Cwd;
use Getopt::Long qw( GetOptionsFromArray );
use IndieBox::Host;
use IndieBox::Logging;
use IndieBox::Utils;

##
# Execute this command.
# return: desired exit code
sub run {
    my @args = @_;

    my $json    = 0;
    my $brief   = 0;
    my @siteIds = ();

    my $parseOk = GetOptionsFromArray(
            \@args,
            'json'     => \$json,
            'brief'    => \$brief,
            'siteid=s' => \@siteIds );

    if( !$parseOk || ( $json && $brief ) || @args ) {
        fatal( 'Invalid command-line arguments' );
    }

    my $sites = IndieBox::Host::sites();
    if( $json ) {
        my $sitesJson = {};
        if( @siteIds ) {
            foreach my $siteId ( @siteIds ) {
                my $site = $sites->{$siteId};
                if( $site ) {
                    $sitesJson->{$site->siteId} = $site->siteJson;
                } else {
                    fatal( "Cannot find site with siteid $siteId." );
                }
            }
        } else {
            foreach my $site ( values %$sites ) {
                $sitesJson->{$site->siteId} = $site->siteJson;
            }
        }
        IndieBox::Utils::writeJsonToStdout( $sitesJson );
    } elsif( $brief ) {
        if( @siteIds ) {
            foreach my $siteId ( @siteIds ) {
                my $site = $sites->{$siteId};
                if( $site ) {
                    print $site->siteId . "\n";
                } else {
                    fatal( "Cannot find site with siteid $siteId." );
                }
            }
        } else {
            foreach my $site ( values %$sites ) {
                print $site->siteId . "\n";
            }
        }
    } else { # human-readable
        if( @siteIds ) {
            foreach my $siteId ( @siteIds ) {
                my $site = $sites->{$siteId};
                if( $site ) {
                    print "Site: " . $site->siteId . "\n";
                    if( $site->hasSsl ) {
                        print "    Hostname: " . $site->hostName . " (SSL)\n";
                    } else {
                        print "    Hostname: " . $site->hostName . "\n";
                    }
                    foreach my $appConfig ( @{$site->appConfigs} ) {
                        if( $appConfig->isDefault ) {
                            my $context = $appConfig->context;
                            print "    (default) Context: " . ( $context ? $context : '(root)' ) . " : " . $appConfig->app->packageName . "\n";
                        }
                    }
                    foreach my $appConfig ( @{$site->appConfigs} ) {
                        unless( $appConfig->isDefault ) {
                            my $context = $appConfig->context;
                            print "              Context: " . ( $context ? $context : '(root)' ) . " : " . $appConfig->app->packageName . "\n";
                        }
                    }
                } else {
                    fatal( "Cannot find site with siteid $siteId." );
                }
            }
        } else {
            foreach my $site ( values %$sites ) {
                print "Site: " . $site->siteId . "\n";
                if( $site->hasSsl ) {
                    print "    Hostname: " . $site->hostName . " (SSL)\n";
                } else {
                    print "    Hostname: " . $site->hostName . "\n";
                }
                foreach my $appConfig ( @{$site->appConfigs} ) {
                    if( $appConfig->isDefault ) {
                        my $context = $appConfig->context;
                        print "    (default) Context: " . ( $context ? $context : '(root)' ) . " : " . $appConfig->app->packageName . "\n";
                    }
                }
                foreach my $appConfig ( @{$site->appConfigs} ) {
                    unless( $appConfig->isDefault ) {
                        my $context = $appConfig->context;
                        print "              Context: " . ( $context ? $context : '(root)' ) . " : " . $appConfig->app->packageName . "\n";
                    }
                }
            }
        }
    }
    
    return 1;
}

##
# Return help text for this command.
# return: hash of synopsis to help text
sub synopsisHelp {
    return {
        <<SSS => <<HHH
    [--json | --brief] [--siteid <siteid>]...
SSS
    Show the sites with siteid, or if not given, show all sites currently
    deployed to this device.
    --json: show them in JSON format
    --brief: only show the site ids.
HHH
    };
}

1;
