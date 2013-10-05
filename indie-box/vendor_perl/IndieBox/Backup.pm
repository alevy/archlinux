#!/usr/bin/perl
#
# Backup functionality.
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

package IndieBox::Backup;

use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
use IndieBox::Configuration;
use IndieBox::Logging;
use IndieBox::Utils qw( readJsonFromString writeJsonToString );
use JSON;

use fields qw( zip sites appConfigs startTime filesToDelete );

my $fileType                 = 'backup';
my $zipFileTypeEntry         = 'indie-filetype';
my $zipFileStartTimeEntry    = 'starttime';
my $zipFileSiteEntry         = 'sites';
my $zipFileInstallablesEntry = 'installables';
my $zipFileAppConfigsEntry   = 'appconfigs';

##
# Instantiate a Backup object that still needs to create an archive file
# $siteIds: list of siteids to be contained in the backup
# $appConfigIds: list of appconfigids to be contained in the backup that aren't part of the sites with the siteids
sub new {
    my $self         = shift;
    my $siteIds      = shift;
    my $appConfigIds = shift;

    unless( ref( $self )) {
        $self = fields::new( $self );
    }

    $self->{zip}           = undef;
    $self->{startTime}     = startTime();
    $self->{filesToDelete} = [];

    my $mySites    = IndieBox::Host::sites();
    my $sites      = {};
    my $appConfigs = {};

    if( defined( $siteIds ) && @$siteIds ) {
        foreach my $siteId ( @$siteIds ) {
            my $site = $mySites->{$siteId};
            unless( defined( $site )) {
                fatal( "This server does not run site $siteId" );
            }
            if( $sites->{$siteId}) {
                fatal( "Duplicate siteid $siteId" );
            }
            $sites->{$siteId} = $site;

            foreach my $appConfig ( @{$site->appConfigs} ) {
                $appConfigs->{$appConfig->appConfigId()} = $appConfig;
            }
        }
    }
    if( defined( $appConfigIds ) && @$appConfigIds ) {
        foreach my $appConfigId ( @$appConfigIds ) {
            if( $appConfigs->{$appConfigId} ) {
                fatal( "Duplicate appconfigid $appConfigId" );
            }
            my $foundAppConfig = undef;
            foreach my $mySite ( values %$mySites ) {
                $foundAppConfig = $mySite->appConfig( $appConfigId );
                if( $foundAppConfig ) {
                    $appConfigs->{$appConfigId} = $foundAppConfig;
                    last;
                }
            }
            unless( $foundAppConfig ) {
                fatal( "This server does not run a site that has an app with appconfigid $appConfigId" );
            }
        }
    }
    if( ( !defined( $siteIds ) || @$siteIds == 0 ) && ( !defined( $appConfigIds ) || @$appConfigIds == 0 )) {
        foreach my $mySite ( values %$mySites ) {
            $sites->{$mySite->siteId} = $mySite;
            foreach my $appConfig ( @{$mySite->appConfigs} ) {
                $appConfigs->{$appConfig->appConfigId()} = $appConfig;
            }
        }
    }

    $self->{sites}      = $sites;
    $self->{appConfigs} = $appConfigs;

    return $self;
}

##
# Instantiate a Backup object from an archive file
# $archive: the archive file name
# return: the Backup object
sub newFromArchive {
    my $self    = shift;
    my $archive = shift;

    unless( ref( $self )) {
        $self = fields::new( $self );
    }

    $self->{sites}      = {};
    $self->{appConfigs} = {};

    $self->{zip} = Archive::Zip->new();
    unless( $self->{zip}->read( $archive ) == AZ_OK ) {
        fatal( "Failed reading file $archive" );
    }

    my $foundFileType = $self->{zip}->contents( $zipFileTypeEntry );
    unless( $foundFileType eq $fileType ) {
        fatal( "Invalid file type: $foundFileType" );
    }

    foreach my $siteJsonFile ( $self->{zip}->membersMatching( "$zipFileSiteEntry/.*\.json" )) {
        my $siteJsonContent = $self->{zip}->contents( $siteJsonFile );
        my $siteJson        = readJsonFromString( $siteJsonContent );

        my $site = new IndieBox::Site( $siteJson );

        $self->{sites}->{$site->siteId()} = $site;
    }
    foreach my $appConfigJsonFile ( $self->{zip}->membersMatching( "$zipFileAppConfigsEntry/.*\.json" )) {
        my $appConfigJsonContent = $self->{zip}->contents( $appConfigJsonFile );
        my $appConfigJson        = readJsonFromString( $appConfigJsonContent );

        my $appConfig = new IndieBox::AppConfiguration( $appConfigJson );

        $self->{appConfigs}->{$appConfig->appConfigId()} = $appConfig;
    }

    $self->{startTime}     = $self->{zip}->contents( $zipFileStartTimeEntry );
    $self->{filesToDelete} = [];

    return $self;
}

##
# Export the backup
# $outFile: the file to write to
sub exportBackup {
    my $self    = shift;
    my $outFile = shift;

    my $zip = Archive::Zip->new;
    $self->{zip} = $zip;

    ##

    $zip->addString( $fileType,                 $zipFileTypeEntry );
    $zip->addString( $self->{startTime} . "\n", $zipFileStartTimeEntry );

    ##

    $zip->addDirectory( "$zipFileSiteEntry/" );

    foreach my $site ( values %{$self->{sites}} ) {
        my $siteId = $site->siteId();
        $zip->addString( writeJsonToString( $site->siteJson() ), "$zipFileSiteEntry/$siteId.json" );
    }

    ##

    $zip->addDirectory( "$zipFileInstallablesEntry/" );

    # construct table of installables
    my %installables = ();
    foreach my $appConfig ( values %{$self->{appConfigs}} ) {
        foreach my $installable ( $appConfig->installables ) {
            $installables{$installable->packageName} = $installable;
        }
    }
    while( my( $packageName, $installable ) = each %installables ) {
        $zip->addString( writeJsonToString( $installable->installableJson()), "$zipFileInstallablesEntry/$packageName.json" );
    }

    ##

    $zip->addDirectory( "$zipFileAppConfigsEntry/" );
    foreach my $appConfig ( values %{$self->{appConfigs}} ) {
        my $appConfigId = $appConfig->appConfigId;
        $zip->addString( writeJsonToString( $appConfig->appConfigurationJson()), "$zipFileAppConfigsEntry/$appConfigId.json" );
        $zip->addDirectory( "$zipFileAppConfigsEntry/$appConfigId/" );

        foreach my $installable ( $appConfig->installables ) {
            my $packageName = $installable->packageName;
            $zip->addDirectory( "$zipFileAppConfigsEntry/$appConfigId/$packageName/" );

            my $config = new IndieBox::Configuration(
                    "Installable=$packageName,AppConfiguration=" . $appConfigId,
                    {},
                    $installable->config,
                    $appConfig->config );

            foreach my $roleName ( @{$installable->roleNames} ) {
                my $appConfigPathInZip = "$zipFileAppConfigsEntry/$appConfigId/$packageName/$roleName";
                $zip->addDirectory( "$appConfigPathInZip/" );

                my $dir = $config->getResolveOrNull( "appconfig.$roleName.dir", undef, 1 );

                my $appConfigItems = $installable->appConfigItemsInRole( $roleName );
                if( $appConfigItems ) {

                    foreach my $appConfigItem ( @$appConfigItems ) {
                        if( !defined( $appConfigItem->{retention} ) || !$appConfigItem->{retention} ) {
                            # for now, we don't care what value this field has as long as it is non-empty
                            next;
                        }
                        my $item = $appConfig->instantiateAppConfigurationItem( $appConfigItem, $installable );
                        if( $item ) {
                            $item->backup( $dir, $config, $zip, $appConfigPathInZip, $self->{filesToDelete} );
                        }
                    }
                }
            }
        }
    }

    $self->{zip}->writeToFileNamed( $outFile );

    foreach my $current ( @{$self->{filesToDelete}} ) {
        unlink $current || myError( "Could not unlink $current" );
    }
    $self->{filesToDelete} = [];
    $self->{zip}           = undef;

    return 1;
}

##
# Format startTime correctly
# return: current time in startTime format
sub startTime {
    my ( $sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst ) = gmtime();
    my $ret = sprintf "%.4d%.2d%.2d-%.2d%.2d%.2d", ($year+1900), ( $mon+1 ), $mday, $hour, $min, $sec;
    return $ret;
}

1;
