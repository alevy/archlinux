#!/usr/bin/perl
#
# A Backup implemented as a ZIP file.
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

package IndieBox::BackupManagers::ZipFileBackup;

use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
use IndieBox::AppConfiguration;
use IndieBox::Configuration;
use IndieBox::Logging;
use IndieBox::Site;
use IndieBox::Utils qw( readJsonFromString writeJsonToString );
use JSON;

use fields qw( zip sites appConfigs startTime file );

my $fileType                 = 'backup';
my $zipFileTypeEntry         = 'indie-filetype';
my $zipFileStartTimeEntry    = 'starttime';
my $zipFileSiteEntry         = 'sites';
my $zipFileInstallablesEntry = 'installables';
my $zipFileAppConfigsEntry   = 'appconfigs';

##
# Save the specified sites and AppConfigurations to a file, and return the corresponding Backup object
# $siteIds: list of siteids to be contained in the backup
# $appConfigIds: list of appconfigids to be contained in the backup that aren't part of the sites with the siteids
# $outFile: the file to save the backup to
sub new {
    my $self         = shift;
    my $siteIds      = shift;
    my $appConfigIds = shift;
    my $outFile      = shift;

    trace( 'ZipFileBackup::new' );

    my $mySites       = IndieBox::Host::sites();
    my $sites         = {};
    my $appConfigs    = {};
    my @filesToDelete = ();

    if( defined( $siteIds ) && @$siteIds ) {
        foreach my $siteId ( @$siteIds ) {
            my $site = $mySites->{$siteId};
            unless( defined( $site )) {
                fatal( 'This server does not run site', $siteId );
            }
            if( $sites->{$siteId}) {
                fatal( 'Duplicate siteid', $siteId );
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
                fatal( 'Duplicate appconfigid', $appConfigId );
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
                fatal( 'This server does not run a site that has an app with appconfigid', $appConfigId );
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

    ##
    my $zip = Archive::Zip->new();
    $zip->addString( $fileType,                                     $zipFileTypeEntry );
    $zip->addString( IndieBox::Utils::time2string( time() ) . "\n", $zipFileStartTimeEntry );

    ##

    $zip->addDirectory( "$zipFileSiteEntry/" );

    foreach my $site ( values %{$sites} ) {
        my $siteId = $site->siteId();
        $zip->addString( writeJsonToString( $site->siteJson() ), "$zipFileSiteEntry/$siteId.json" );
    }

    ##

    $zip->addDirectory( "$zipFileInstallablesEntry/" );

    # construct table of installables
    my %installables = ();
    foreach my $appConfig ( values %{$appConfigs} ) {
        foreach my $installable ( $appConfig->installables ) {
            $installables{$installable->packageName} = $installable;
        }
    }
    while( my( $packageName, $installable ) = each %installables ) {
        $zip->addString( writeJsonToString( $installable->installableJson()), "$zipFileInstallablesEntry/$packageName.json" );
    }

    ##

    $zip->addDirectory( "$zipFileAppConfigsEntry/" );
    foreach my $appConfig ( values %{$appConfigs} ) {
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
                        if( !defined( $appConfigItem->{retentionpolicy} ) || !$appConfigItem->{retentionpolicy} ) {
                            # for now, we don't care what value this field has as long as it is non-empty
                            next;
                        }
                        my $item = $appConfig->instantiateAppConfigurationItem( $appConfigItem, $installable );
                        if( $item ) {
                            $item->backup( $dir, $config, $zip, $appConfigPathInZip, \@filesToDelete );
                        }
                    }
                }
            }
        }
    }

    trace( 'Writing zip file', $outFile );

    $zip->writeToFileNamed( $outFile );

    foreach my $current ( @filesToDelete ) {
        unlink $current || error( 'Could not unlink', $current );
    }

    return IndieBox::BackupManagers::ZipFileBackup->newFromArchive( $outFile );
}

##
# Instantiate a Backup object from an archive file
# $archive: the archive file name
# return: the Backup object
sub newFromArchive {
    my $self    = shift;
    my $archive = shift;

    trace( 'ZipFileBackup::newFromArchive' );

    unless( ref( $self )) {
        $self = fields::new( $self );
    }

    $self->{sites}      = {};
    $self->{appConfigs} = {};
    $self->{file}       = $archive;

    $self->{zip} = Archive::Zip->new();
    unless( $self->{zip}->read( $archive ) == AZ_OK ) {
        fatal( 'Failed reading file', $archive );
    }

    my $foundFileType = $self->{zip}->contents( $zipFileTypeEntry );
    unless( $foundFileType eq $fileType ) {
        fatal( 'Invalid file type:', $foundFileType );
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

    $self->{startTime} = $self->{zip}->contents( $zipFileStartTimeEntry );

    return $self;
}

##
# Determine the start time in UNIX time format
sub startTime {
    my $self = shift;

    return IndieBox::Utils::string2time( $self->{startTime} );
}

##
# Determine the sites contained in this Backup.
# return: hash of siteid to Site
sub sites {
    my $self = shift;

    return $self->{sites};
}

##
# Determine the AppConfigurations contained in this Backup.
# return: hash of appconfigid to AppConfiguration
sub appConfigs {
    my $self = shift;

    return $self->{appConfigs};
}

##
# Obtain the file that holds this Backup, if any
# return: file name
sub fileName {
    my $self = shift;

    return $self->{file};
}

##
# Restore a site from a backup
# $site: the Site to restore
# $backup: the Backup from where to restore
sub restoreSite {
    my $self    = shift;
    my $site    = shift;

    debug( 'ZipFileBackup->restoreSite( ', $site->siteId );

    foreach my $appConfig ( @{$site->appConfigs} ) {
        $self->restoreAppConfiguration( $site, $appConfig );
    }

    1;
}

##
# Restore a single AppConfiguration from Backup
# $site: the Site of the AppConfiguration
# $appConfig: the AppConfiguration to restore
sub restoreAppConfiguration {
    my $self      = shift;
    my $site      = shift;
    my $appConfig = shift;

    debug( 'Backup::restoreAppConfiguration', $site->siteId, $appConfig->appConfigId );

    $appConfig->deploy();

    my $zip         = $self->{zip};
    my $appConfigId = $appConfig->appConfigId;

    foreach my $installable ( $appConfig->installables ) {
        my $packageName = $installable->packageName;

        unless( $zip->memberNamed( "$zipFileAppConfigsEntry/$appConfigId/$packageName/" )) {
            next;
        }

        my $config = new IndieBox::Configuration(
                "Installable=$packageName,AppConfiguration=" . $appConfigId,
                {},
                $installable->config,
                $appConfig->config );

        foreach my $roleName ( @{$installable->roleNames} ) {
            my $appConfigPathInZip = "$zipFileAppConfigsEntry/$appConfigId/$packageName/$roleName";
            unless( $zip->memberNamed( "$appConfigPathInZip/" )) {
                next;
            }

            my $appConfigItems = $installable->appConfigItemsInRole( $roleName );
            if( $appConfigItems ) {
                my $dir = $config->getResolveOrNull( "appconfig.$roleName.dir", undef, 1 );

                foreach my $appConfigItem ( @$appConfigItems ) {
                    if( !defined( $appConfigItem->{retentionpolicy} ) || !$appConfigItem->{retentionpolicy} ) {
                        # for now, we don't care what value this field has as long as it is non-empty
                        next;
                    }
                    my $item = $appConfig->instantiateAppConfigurationItem( $appConfigItem, $installable );
                    if( $item ) {
                        $item->restore( $dir, $config, $zip, $appConfigPathInZip );
                    }
                }
            }
        }
    }
}

1;
