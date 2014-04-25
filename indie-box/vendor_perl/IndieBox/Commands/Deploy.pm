#!/usr/bin/perl
#
# Command that deploys one or more sites.
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

package IndieBox::Commands::Deploy;

use Cwd;
use File::Basename;
use Getopt::Long qw( GetOptionsFromArray );
use IndieBox::AdminUtils;
use IndieBox::BackupManagers::ZipFileBackupManager;
use IndieBox::Host;
use IndieBox::Logging;
use IndieBox::Utils;

##
# Execute this command.
# return: desired exit code
sub run {
    my @args = @_;

    my @siteIds = ();
    my $quiet   = 0;
    my $file    = undef;

    my $parseOk = GetOptionsFromArray(
            \@args,
            'siteid=s' => \@siteIds,
            'quiet'    => \$quiet,
            'file=s'   => \$file );

    if( !$parseOk || @args) {
        fatal( 'Invalid command-line arguments' );
    }

    debug( 'Parsing site JSON and checking' );

    my $json;
    if( $file ) {
        $json = readJsonFromFile( $file );
        $json = IndieBox::Utils::insertSlurpedFiles( $json, dirname( $file ) );
    } else {
        $json = readJsonFromStdin();
        $json = IndieBox::Utils::insertSlurpedFiles( $json, getcwd() );
    }

    my $newSitesHash = {};
    if( ref( $json ) eq 'HASH' && %$json ) {
        $json = [ $json ];
    }
    if( ref( $json ) eq 'ARRAY' ) {
        if( !@$json ) {
            fatal( 'No site given' );

        } elsif( @siteIds ) {
            foreach my $siteJson ( @$json ) {
                my $site = new IndieBox::Site( $siteJson );

                foreach my $siteId ( @siteIds ) {
                    if( $site->siteId eq $siteId ) {
                        if( $newSitesHash->{$siteId} ) {
                            fatal( "Duplicate site definition: $siteId" );
                        }
                        $newSitesHash->{$siteId} = $site;
                        @siteIds = grep { $_ != $siteId } @siteIds;
                        last;
                    }
                }
            }
            if( @siteIds > 1 ) {
                fatal( "Site definitions not found in JSON: " . join( ' ', @siteIds ));
            } elsif( @siteIds ) {
                fatal( "Site definitions not found in JSON: " . join( ' ', @siteIds ));
            }
        } else {
            foreach my $siteJson ( @$json ) {
                my $site   = new IndieBox::Site( $siteJson );
                my $siteId = $site->siteId;
                if( $newSitesHash->{$siteId} ) {
                    fatal( "Duplicate site definition: $siteId" );
                }
                $newSitesHash->{$siteId} = $site;
            }
        }
    } else {
        fatal( "Not a Site JSON file" );
    }

    my $applicableRoleNames = IndieBox::Host::applicableRoleNames();

    my $oldSites = IndieBox::Host::sites();
    my @newSites = values %$newSitesHash;

    # make sure AppConfigIds, SiteIds and hostnames are unique, and that all Sites are deployable
    my $haveIdAlready   = {};
    my $haveHostAlready = {};
    
    foreach my $newSite ( @newSites ) {
        my $newSiteId = $newSite->siteId;
        if( $haveIdAlready->{$newSiteId} ) {
            fatal( 'More than one site or appconfig with id', $newSiteId );
        }
        $haveIdAlready->{$newSiteId} = $newSite;

        my $newSiteHostName = $newSite->hostName;
        if( $haveHostAlready->{$newSiteHostName} ) {
            fatal( 'More than one site with hostname', $newSiteHostName );
        }
        $haveHostAlready->{$newSiteHostName} = $newSite;

        foreach my $newAppConfig ( @{$newSite->appConfigs} ) {
            my $newAppConfigId = $newAppConfig->appConfigId;
            if( $haveIdAlready->{$newAppConfigId} ) {
                fatal( 'More than one site or appconfig with id', $newAppConfigId );
            }
            $haveIdAlready->{$newSiteId} = $newSite;
        
            foreach my $oldSite ( values %$oldSites ) {
                foreach my $oldAppConfig ( @{$oldSite->appConfigs} ) {
                    if( $newAppConfigId eq $oldAppConfig->appConfigId ) {
                        if( $newSiteId ne $oldSite->siteId ) {
                            fatal(    'Non-unique appconfigid ' . $newAppConfigId
                                    . ' in sites ' . $newSiteId . ' and ' . $oldSite->siteId );
                        }
                    }
                }
            }
        }

        my $oldSite = $oldSites->{$newSiteId};
        if( defined( $oldSite )) {
            $oldSite->checkUndeployable;
        }
    }

    debug( 'Installing prerequisites' );
    # This is a two-step process: first we need to install the applications that haven't been
    # installed yet, and then we need to install their dependencies

    my $prerequisites = {};
    foreach my $site ( @newSites ) {
        $site->addInstallablesToPrerequisites( $applicableRoleNames, $prerequisites );
    }
    IndieBox::Host::installPackages( $prerequisites );

    $prerequisites = {};
    foreach my $site ( @newSites ) {
        $site->addDependenciesToPrerequisites( $applicableRoleNames, $prerequisites );
    }
    IndieBox::Host::installPackages( $prerequisites );

    debug( 'Checking customization points' );
    
    foreach my $newSite ( @newSites ) {
        foreach my $newAppConfig ( @{$newSite->appConfigs} ) {
            my $appConfigCustPoints = $newAppConfig->customizationPoints();
            
            foreach my $installable ( $newAppConfig->installables ) {
                my $packageName           = $installable->packageName;
                my $installableCustPoints = $installable->customizationPoints;
                if( $installableCustPoints ) {
                    while( my( $custPointName, $custPointDef ) = each( %$installableCustPoints )) {
                        # check data type
                        my $value = $appConfigCustPoints->{$packageName}->{$custPointName}->{value};
                        if( defined( $value )) {
                            if( $custPointDef->{type} =~ m/^(string|password|image)$/ ) {
                                if( ref( $value )) {
                                    fatal(   'Site ' . $newSite->siteId
                                           . ', AppConfiguration ' . $newAppConfig->appConfigId
                                           . ', package ' . $packageName
                                           . ', string value required for customizationpoint: ' .  $custPointName
                                           . ', is ' . ref( $value ));
                                }
                            } else {
                                # $custPointDef->{type} =~ m/^boolean$/
                                unless( ref( $value ) =~ m/^JSON.*[Bb]oolean$/ ) {
                                    fatal(   'Site ' . $newSite->siteId
                                           . ', AppConfiguration ' . $newAppConfig->appConfigId
                                           . ', package ' . $packageName
                                           . ', boolean value required for customizationpoint: ' .  $custPointName
                                           . ', is ' . ref( $value ));
                                }
                            }
                        }
                        
                        # now check that required values are indeed provided
                        unless( $custPointDef->{required} ) {
                            next;
                        }
                        if( !defined( $custPointDef->{default} ) || !defined( $custPointDef->{default}->{value} )) {
                            # make sure the Site JSON file provided one
                            unless( defined( $value )) {
                                fatal(   'Site ' . $newSite->siteId
                                       . ', AppConfiguration ' . $newAppConfig->appConfigId
                                       . ', package ' . $packageName
                                       . ', required value not provided for customizationpoint: ' .  $custPointName );
                            }
                        }
                    }
                }
            }
        }
    }

    # Now that we have prerequisites, we can check whether the site is deployable
    foreach my $newSite ( @newSites ) {
        $newSite->checkDeployable();
    }

    debug( 'Setting up placeholder sites' );

    my $suspendTriggers = {};
    foreach my $site ( @newSites ) {
        my $oldSite = $oldSites->{$site->siteId};
        if( $oldSite ) {
            $oldSite->suspend( $suspendTriggers ); # replace with "upgrade in progress page"
        } else {
            $site->setupPlaceholder( $suspendTriggers ); # show "coming soon"
        }
    }
    IndieBox::Host::executeTriggers( $suspendTriggers );

    debug( 'Backing up, undeploying and redeploying' );

    my $backupManager = new IndieBox::BackupManagers::ZipFileBackupManager();

    my $adminBackups = {};
    foreach my $site ( @newSites ) {
        my $oldSite = $oldSites->{$site->siteId};
        if( $oldSite ) {
            my $backup = $backupManager->adminBackupSite( $oldSite );
            $oldSite->undeploy();
            
            $site->deploy();
            $backup->restoreSite( $site );
            $adminBackups->{$site->siteId} = $backup;
        } else {
            $site->deploy();
        }
    }

    debug( 'Resuming sites' );

    my $resumeTriggers = {};
    foreach my $site ( @newSites ) {
        $site->resume( $resumeTriggers ); # remove "upgrade in progress page"
    }
    IndieBox::Host::executeTriggers( $resumeTriggers );

    debug( 'Running installers/upgraders' );

    foreach my $site ( @newSites ) {
        my $oldSite = $oldSites->{$site->siteId};
        if( $oldSite ) {
            foreach my $appConfig ( @{$site->appConfigs} ) {
                if( $oldSite->appConfig( $appConfig->appConfigId() )) {
                    $appConfig->runUpgrader();
                } else {
                    $appConfig->runInstaller();
                }
            }
        } else {
            foreach my $appConfig ( @{$site->appConfigs} ) {
                $appConfig->runInstaller();
            }
        }
    }

    $backupManager->purgeAdminBackups();

    return 1;
}

##
# Return help text for this command.
# return: hash of synopsis to help text
sub synopsisHelp {
    return {
        <<SSS => <<HHH,
    [--quiet] [--siteid <siteid>]...
SSS
    Deploy or update one or more websites. This includes setting up the
    virtual host(s), installing and configuring all web applications for
    the website(s). The website configuration(s) will be provided as a
    JSON file from stdin. If one or more siteids are given, only deploy
    the sites with those siteids.
HHH
        <<SSS => <<HHH
    [--quiet] [--siteid <siteid>] ... --file <site.json>
SSS
    Deploy or update one or more websites. This includes setting up the
    virtual host(s), installing and configuring all web applications for
    the website(s). The website configuration(s) will be provided as JSON
    file <site.json>. If one or more siteids are given, only deploy
    the sites with those siteids.
HHH
    };
}

1;
