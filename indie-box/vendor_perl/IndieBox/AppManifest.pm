#!/usr/bin/perl
#
# App manifest checking routines. This is factored out to not clutter the main
# functionality.
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

package IndieBox::AppManifest;

use IndieBox::InstallableManifest qw(validFilename);
use IndieBox::Logging;
use JSON;

##
# Check validity of the manifest JSON.
# $packageName: name of the package that this manifest JSON belongs to
# $json: the JSON object
# $config: Configuration object to use for resolving variables
# return: 1 or exits with myFatal error
sub checkManifest {
    my $packageName = shift;
    my $json        = shift;
    my $config      = shift;

    trace( 'Checking manifest for', $packageName );

    IndieBox::InstallableManifest::checkManifest( $packageName, $json, $config );

    unless( $json->{type} eq 'app' ) {
        myFatal( $packageName, 'type must be app, is', $json->{type} );
    }

    unless( $json->{info} ) {
        myFatal( $packageName, 'must have info section' );
    }
    unless( $json->{info}->{package} ) {
        myFatal( $packageName, "info section: must have field 'package'" );
    }
    unless( $json->{info}->{package} =~ m!^[-_a-z0-9]+$! ) {
        myFatal( $packageName, "info section: field 'package' must be a valid package name" );
    }
    unless( $json->{info}->{name} ) {
        myFatal( $packageName, "info section: must have field 'name'" );
    }
    if( ref( $json->{info}->{name} )) {
        myFatal( $packageName, "info section: field 'name' must be a string" );
    }
    unless( $json->{info}->{tagline} ) {
        myFatal( $packageName, "info section: must have field 'tagline'" );
    }
    if( ref( $json->{info}->{tagline} )) {
        myFatal( $packageName, "info section: field 'tagline' must be a string" );
    }
    if( $json->{info}->{description} && ref( $json->{info}->{description} )) {
        myFatal( $packageName, "info section: field 'description' must be a string" );
    }
    unless( $json->{info}->{developer} ) {
        myFatal( $packageName, "info section: must have field 'developer'" );
    }
    if( ref( $json->{info}->{developer} )) {
        myFatal( $packageName, "info section: field 'developer' must be a string" );
    }
    unless( $json->{info}->{maintainer} ) {
        myFatal( $packageName, "info section: must have field 'maintainer'" );
    }
    if( ref( $json->{info}->{maintainer} )) {
        myFatal( $packageName, "info section: field 'maintainer' must be a string" );
    }
    unless( $json->{info}->{upstreamversion} ) {
        myFatal( $packageName, "info section: must have field 'upstreamversion'" );
    }
    if( ref( $json->{info}->{upstreamversion} )) {
        myFatal( $packageName, "info section: field 'upstreamversion' must be a string" );
    }
    unless( $json->{info}->{packageversion} ) {
        myFatal( $packageName, "info section: must have field 'packageversion'" );
    }
    if( ref( $json->{info}->{packageversion} )) {
        myFatal( $packageName, "info section: field 'packageversion' must be a string" );
    }
    unless( $json->{info}->{licenses} ) {
        myFatal( $packageName, "info section: must have 'licenses'" );
    }
    if( ref( $json->{info}->{licenses} ) ne 'ARRAY' ) {
        myFatal( $packageName, "info section: field 'licenses' must be array" );
    }
    foreach my $license ( @{$json->{info}->{licenses}} ) {
        if( ref( $license )) {
            myFatal( $packageName, "info section: licenses section: license must be a string" );
        }
        unless( $license =~ m!^[a-zA-Z0-9]+$! ) {
            myFatal( $packageName, "info section: licenses section: invalid license string" );
        }
    }

    my %retentionBuckets = ();
    if( $json->{roles} ) {

        my $codeDir = $config->getResolve( 'package.codedir' );

        while( my( $roleName, $roleJson ) = each %{$json->{roles}} ) {
            if( $roleName eq 'apache2' ) {
                if( $roleJson->{defaultcontext} ) {
                    if( $roleJson->{fixedcontext} ) {
                        myFatal( $packageName, "roles section: role $roleName: must not specify both defaultcontext and fixedcontext" );
                    }
                    if( ref( $roleJson->{defaultcontext} )) {
                        myFatal( $packageName, "roles section: role $roleName: field 'defaultcontext' must be string" );
                    }
                    unless( $roleJson->{defaultcontext} =~ m!^(/[-a-z0-9]+)*$! ) {
                        myFatal( $packageName, "roles section: role $roleName: invalid defaultcontext: " . $roleJson->{defaultcontext} );
                    }

                } elsif( $roleJson->{fixedcontext} ) {
                    if( ref( $roleJson->{fixedcontext} )) {
                        myFatal( $packageName, "roles section: role $roleName: field 'fixedcontext' must be string" );
                    }
                    unless( $roleJson->{fixedcontext} =~ m!^(/[-a-z0-9]+)*$! ) {
                        myFatal( $packageName, "roles section: role $roleName: invalid fixedcontext: " . $roleJson->{fixedcontext} );
                    }
                } else {
                    # not a web app, that's fine
                }

                if( $roleJson->{depends} ) {
                    unless( ref( $roleJson->{depends} ) eq 'ARRAY' ) {
                        myFatal( $packageName, "roles section: role $roleName: depends is not an array" );
                    }
                    my $dependsIndex = 0;
                    foreach my $depends ( @{$roleJson->{depends}} ) {
                        if( ref( $depends )) {
                            myFatal( $packageName, "roles section: role $roleName: depends[$dependsIndex] must be string" );
                        }
                        unless( $depends =~ m!^[-a-z0-9]+$! ) {
                            myFatal( $packageName, "roles section: role $roleName: depends[$dependsIndex] invalid: $depends" );
                        }
                        ++$dependsIndex;
                    }
                }

                if( $roleJson->{apache2modules} ) {
                    unless( ref( $roleJson->{apache2modules} ) eq 'ARRAY' ) {
                        myFatal( $packageName, "roles section: role $roleName: apache2modules is not an array" );
                    }
                    my $modulesIndex = 0;
                    foreach my $module ( @{$roleJson->{apache2modules}} ) {
                        if( ref( $module )) {
                            myFatal( $packageName, "roles section: role $roleName: apache2modules[$modulesIndex] must be string" );
                        }
                        unless( $module =~ m!^[-a-z0-9]+$! ) {
                            myFatal( $packageName, "roles section: role $roleName: apache2modules[$modulesIndex] invalid: $module" );
                        }
                        ++$modulesIndex;
                    }
                }
                if( $roleJson->{phpmodules} ) {
                    unless( ref( $roleJson->{phpmodules} ) eq 'ARRAY' ) {
                        myFatal( $packageName, "roles section: role $roleName: phpmodules is not an array" );
                    }
                    my $modulesIndex = 0;
                    foreach my $module ( @{$roleJson->{phpmodules}} ) {
                        if( ref( $module )) {
                            myFatal( $packageName, "roles section: role $roleName: phpmodules[$modulesIndex] must be string" );
                        }
                        unless( $module =~ m!^[-a-z0-9]+$! ) {
                            myFatal( $packageName, "roles section: role $roleName: phpmodules[$modulesIndex] invalid: $module" );
                        }
                        ++$modulesIndex;
                    }
                }
                if( $roleJson->{appconfigitems} ) {
                    unless( ref( $roleJson->{appconfigitems} ) eq 'ARRAY' ) {
                        myFatal( $packageName, "roles section: role $roleName: not an array" );
                    }
                    my $appConfigIndex = 0;
                    foreach my $appConfigItem ( @{$roleJson->{appconfigitems}} ) {
                        if( ref( $appConfigItem->{type} )) {
                            myFatal( $packageName, "roles section: role $roleName: appconfigitem[$appConfigIndex]: field 'type' must be string" );
                        }
                        if( $appConfigItem->{type} eq 'perlscript' ) {
                            unless( $appConfigItem->{source} ) {
                                myFatal( $packageName, "roles section: role $roleName: appconfigitem[$appConfigIndex]: must specify source" );
                            }
                            if( ref( $appConfigItem->{source} )) {
                                myFatal( $packageName, "roles section: role $roleName: appconfigitem[$appConfigIndex]: field 'name' must be string" );
                            }
                            unless( validFilename( $codeDir, $appConfigItem->{source} )) {
                                myFatal( $packageName, "roles section: role $roleName: appconfigitem[$appConfigIndex] has invalid name: " . $appConfigItem->{name} );
                            }
                            if( $appConfigItem->{name} ) {
                                myFatal( $packageName, "roles section: role $roleName: appconfigitem[$appConfigIndex]: name not permitted for type perlscript" );
                            }
                            if( $appConfigItem->{names} ) {
                                myFatal( $packageName, "roles section: role $roleName: appconfigitem[$appConfigIndex]: names not permitted for type perlscript" );
                            }
                        } else {
                            my @names = ();
                            if( defined( $appConfigItem->{name} )) {
                                if( $appConfigItem->{names} ) {
                                    myFatal( $packageName, "roles section: role $roleName: appconfigitem[$appConfigIndex]: specify name or names, not both" );
                                }
                                if( ref( $appConfigItem->{name} )) {
                                    myFatal( $packageName, "roles section: role $roleName: appconfigitem[$appConfigIndex]: field 'name' must be string" );
                                }
                                # file does not exist yet
                                push @names, $appConfigItem->{name};

                            } else {
                                unless( $appConfigItem->{names} ) {
                                    myFatal( $packageName, "roles section: role $roleName: appconfigitem[$appConfigIndex]: must specify name or names" );
                                }
                                unless( ref( $appConfigItem->{names} ) eq 'ARRAY' ) {
                                    myFatal( $packageName, "roles section: role $roleName: appconfigitem[$appConfigIndex]: names must be an array" );
                                }
                                my $namesIndex = 0;
                                foreach my $name ( @{$appConfigItem->{names}} ) {
                                    if( ref( $name )) {
                                        myFatal( $packageName, "roles section: role $roleName: appconfigitem[$appConfigIndex]: names[$namesIndex] must be string" );
                                    }
                                    # file does not exist yet
                                    push @names, $name;
                                    ++$namesIndex;
                                }
                                unless( $namesIndex > 0 ) {
                                    myFatal( $packageName, "roles section: role $roleName: appconfigitem[$appConfigIndex]: must specify name or names" );
                                }
                            }

                            if( $appConfigItem->{type} eq 'file' ) {
                                if( $appConfigItem->{source} ) {
                                    if( $appConfigItem->{template} ) {
                                        myFatal( $packageName, "roles section: role $roleName: appconfigitem[$appConfigIndex] of type 'file': specify source or template, not both" );
                                    }
                                    if( ref( $appConfigItem->{source} )) {
                                        myFatal( $packageName, "roles section: role $roleName: appconfigitem[$appConfigIndex] of type 'file': field 'source' must be string" );
                                    }
                                    foreach my $name ( @names ) {
                                        unless( validFilename( $codeDir, $appConfigItem->{source}, $name )) {
                                            myFatal( $packageName, "roles section: role $roleName: appconfigitem[$appConfigIndex] of type 'file': invalid source: " . $appConfigItem->{source} . " for name $name" );
                                        }
                                    }
                                } elsif( $appConfigItem->{template} ) {
                                    unless( $appConfigItem->{templatelang} ) {
                                        myFatal( $packageName, "roles section: role $roleName: appconfigitem[$appConfigIndex] of type 'file': if specifying template, must specify templatelang as well" );
                                    }
                                    if( ref( $appConfigItem->{template} )) {
                                        myFatal( $packageName, "roles section: role $roleName: appconfigitem[$appConfigIndex] of type 'file': field 'template' must be string" );
                                    }
                                    foreach my $name ( @names ) {
                                        unless( validFilename( $codeDir, $appConfigItem->{template}, $name )) {
                                            myFatal( $packageName, "roles section: role $roleName: appconfigitem[$appConfigIndex] of type 'file': invalid template: " . $appConfigItem->{template} . " for name $name" );
                                        }
                                    }
                                    if( ref( $appConfigItem->{templatelang} )) {
                                        myFatal( $packageName, "roles section: role $roleName: appconfigitem[$appConfigIndex] of type 'file': field 'templatelang' must be string" );
                                    }
                                    unless( $appConfigItem->{templatelang} =~ m!^(varsubst|perlscript)$! ) {
                                        myFatal( $packageName, "roles section: role $roleName: appconfigitem[$appConfigIndex] of type 'file': invalid templatelang: " . $appConfigItem->{templatelang} );
                                    }
                                } else {
                                    myFatal( $packageName, "roles section: role $roleName: appconfigitem[$appConfigIndex] of type 'file': must specify source or template" );
                                }

                            } elsif( $appConfigItem->{type} eq 'directory' ) {

                            } elsif( $appConfigItem->{type} eq 'directorytree' ) {
                                unless( $appConfigItem->{source} ) {
                                    myFatal( $packageName, "roles section: role $roleName: appconfigitem[$appConfigIndex] of type 'directorytree': must specify source" );
                                }
                                if( ref( $appConfigItem->{source} )) {
                                    myFatal( $packageName, "roles section: role $roleName: appconfigitem[$appConfigIndex] of type 'directorytree': field 'source' must be string" );
                                }
                                foreach my $name ( @names ) {
                                    unless( validFilename( $codeDir, $appConfigItem->{source}, $name )) {
                                        myFatal( $packageName, "roles section: role $roleName: appconfigitem[$appConfigIndex] of type 'directorytree': invalid source: " . $appConfigItem->{source} . " for name $name" );
                                    }
                                }

                            } elsif( $appConfigItem->{type} eq 'symlink' ) {
                                unless( $appConfigItem->{source} ) {
                                    myFatal( $packageName, "roles section: role $roleName: appconfigitem[$appConfigIndex] of type 'symlink': must specify source" );
                                }
                                if( ref( $appConfigItem->{source} )) {
                                    myFatal( $packageName, "roles section: role $roleName: appconfigitem[$appConfigIndex] of type 'symlink': field 'source' must be string" );
                                }
                                foreach my $name ( @names ) {
                                    unless( validFilename( $codeDir, $appConfigItem->{source}, $name )) {
                                        myFatal( $packageName, "roles section: role $roleName: appconfigitem[$appConfigIndex] of type 'symlink': invalid source: " . $appConfigItem->{source} . " for name $name" );
                                    }
                                }

                            # perlscript handled above
                            } else {
                                myFatal( $packageName, "roles section: role $roleName: appconfigitem[$appConfigIndex] has unknown type: " . $appConfigItem->{type} );
                            }

                            if( $appConfigItem->{uname} ) {
                                if( ref( $appConfigItem->{uname} )) {
                                    myFatal( $packageName, "roles section: role $roleName: appconfigitem[$appConfigIndex]: field 'uname' must be string" );
                                }
                                unless( $config->replaceVariables( $appConfigItem->{uname} ) =~ m!^[-a-z0-9]+$! ) {
                                    myFatal( $packageName, "roles section: role $roleName: appconfigitem[$appConfigIndex]: invalid uname: " . $appConfigItem->{uname} );
                                }
                            }
                            if( $appConfigItem->{gname} ) {
                                if( ref( $appConfigItem->{gname} )) {
                                    myFatal( $packageName, "roles section: role $roleName: appconfigitem[$appConfigIndex]: field 'gname' must be string" );
                                }
                                unless( $config->replaceVariables( $appConfigItem->{gname} ) =~ m!^[-a-z0-9]+$! ) {
                                    myFatal( $packageName, "roles section: role $roleName: appconfigitem[$appConfigIndex]: invalid gname: " . $appConfigItem->{gname} );
                                }
                            }
                            if( $appConfigItem->{mode} ) {
                                if( ref( $appConfigItem->{mode} )) {
                                    myFatal( $packageName, "roles section: role $roleName: appconfigitem[$appConfigIndex]: field 'mode' must be string (octal)" );
                                }
                                unless( $config->replaceVariables( $appConfigItem->{mode} ) =~ m!^(preserve|[0-7]{3,4})$! ) {
                                    myFatal( $packageName, "roles section: role $roleName: appconfigitem[$appConfigIndex]: invalid mode: " . $appConfigItem->{mode} );
                                }
                            }
                            if( $appConfigItem->{retention} ) {
                                if( ref( $appConfigItem->{retention} )) {
                                    myFatal( $packageName, "roles section: role $roleName: appconfigitem[$appConfigIndex]: field 'retention' must be string" );
                                }
                                if( $appConfigItem->{retention} ne 'keep' ) {
                                    myFatal( $packageName, "roles section: role $roleName: appconfigitem[$appConfigIndex] has unknown retention value: " . $appConfigItem->{retention} );
                                }
                                unless( $appConfigItem->{retentionbucket} ) {
                                    myFatal( $packageName, "roles section: role $roleName: appconfigitem[$appConfigIndex]: if specifying retention, also specify retentionbucket" );
                                }
                                if( ref( $appConfigItem->{retentionbucket} )) {
                                    myFatal( $packageName, "roles section: role $roleName: appconfigitem[$appConfigIndex]: field 'retentionbucket' must be string" );
                                }
                                if( $retentionBuckets{$appConfigItem->{retentionbucket}} ) {
                                    myFatal( $packageName, "roles section: role $roleName: appconfigitem[$appConfigIndex]: field 'retentionbucket' must be unique: " . $appConfigItem->{retentionbucket} );
                                }
                                $retentionBuckets{$appConfigItem->{retentionbucket}} = 1;
                            }
                        }
                        ++$appConfigIndex;
                    }
                }
                if( $roleJson->{triggersactivate} ) {
                    unless( ref( $roleJson->{triggersactivate} ) eq 'ARRAY' ) {
                        myFatal( $packageName, "roles section: role $roleName: triggersactivate: not an array" );
                    }
                    my $triggersIndex = 0;
                    my %triggers = ();
                    foreach my $triggersJson ( @{$roleJson->{triggersactivate}} ) {
                        if( ref( $triggersJson )) {
                            myFatal( $packageName, "roles section: role $roleName: triggersactivate[$triggersIndex]: not an array" );
                        }
                        unless( $triggersJson =~ m/^[a-z][-a-z0-9]*$/ ) {
                            myFatal( $packageName, "roles section: role $roleName: triggersactivate[$triggersIndex]: invalid trigger name: $triggersJson" );
                        }
                        if( $triggers{$triggersJson} ) {
                            myFatal( $packageName, "roles section: role $roleName: triggersactivate[$triggersIndex] is not unique: $triggersJson" );
                            $triggers{$triggersJson} = 1;
                        }
                        ++$triggersIndex;
                    }
                }
                if( $roleJson->{installer} ) {
                    unless( ref( $roleJson->{installer} ) eq 'HASH' ) {
                        myFatal( $packageName, "roles section: role $roleName: installer: not a JSON object" );
                    }
                    if( ref( $roleJson->{installer}->{type} )) {
                        myFatal( $packageName, "roles section: role $roleName: installer: field 'type' must be string" );
                    }
                    if( $roleJson->{installer}->{type} ne 'perlscript' ) {
                        myFatal( $packageName, "roles section: role $roleName: installer: unknown type: " . $roleJson->{installer}->{type} );
                    }
                    if( ref( $roleJson->{installer}->{name} ) ) {
                        myFatal( $packageName, "roles section: role $roleName: installer: invalid name" );
                    }
                    ## FIXME: check for existence of file
                }

            } elsif( $roleName eq 'mysql' ) {
                my %databaseNames = ();
                if( $roleJson->{appconfigitems} ) {
                    unless( ref( $roleJson->{appconfigitems} ) eq 'ARRAY' ) {
                        myFatal( $packageName, "roles section: role $roleName: not an array" );
                    }
                    my $appConfigIndex = 0;
                    foreach my $appConfigItem ( @{$roleJson->{appconfigitems}} ) {
                        if( ref( $appConfigItem->{type} )) {
                            myFatal( $packageName, "roles section: role $roleName: appconfigitem[$appConfigIndex]: field 'type' must be string" );
                        }
                        if( $appConfigItem->{type} ne 'mysql-database' ) {
                            myFatal( $packageName, "roles section: role $roleName: appconfigitem[$appConfigIndex] has unknown type: " . $appConfigItem->{type} );
                        }
                        if( ref( $appConfigItem->{name} )) {
                            myFatal( $packageName, "roles section: role $roleName: appconfigitem[$appConfigIndex]: field 'name' must be string" );
                        }
                        unless( $appConfigItem->{name} =~ m/^[a-z][a-z0-9]*$/ ) {
                            myFatal( $packageName, "roles section: role $roleName: appconfigitem[$appConfigIndex] has invalid symbolic database name: " . $appConfigItem->{name} );
                        }
                        if( $databaseNames{$appConfigItem->{name}} ) {
                            myFatal( $packageName, "roles section: role $roleName: appconfigitem[$appConfigIndex] has non-unique symbolic database name" );
                            $databaseNames{$appConfigItem->{name}} = 1;
                        }
                        if( $appConfigItem->{retention} ) {
                            if( ref( $appConfigItem->{retention} )) {
                                myFatal( $packageName, "roles section: role $roleName: appconfigitem[$appConfigIndex]: field 'retention' must be string" );
                            }
                            if( $appConfigItem->{retention} ne 'keep' ) {
                                myFatal( $packageName, "roles section: role $roleName: appconfigitem[$appConfigIndex] has unknown retention value: " . $appConfigItem->{retention} );
                            }
                            unless( $appConfigItem->{retentionbucket} ) {
                                myFatal( $packageName, "roles section: role $roleName: appconfigitem[$appConfigIndex]: if specifying retention, also specify retentionbucket" );
                            }
                            if( ref( $appConfigItem->{retentionbucket} )) {
                                myFatal( $packageName, "roles section: role $roleName: appconfigitem[$appConfigIndex]: field 'retentionbucket' must be string" );
                            }
                            if( $retentionBuckets{$appConfigItem->{retentionbucket}} ) {
                                myFatal( $packageName, "roles section: role $roleName: appconfigitem[$appConfigIndex]: field 'retentionbucket' must be unique: " . $appConfigItem->{retentionbucket} );
                            }
                            $retentionBuckets{$appConfigItem->{retentionbucket}} = 1;
                        }
                        if( $appConfigItem->{privileges} ) {
                            if( ref( $appConfigItem->{privileges} )) {
                                myFatal( $packageName, "roles section: role $roleName: appconfigitem[$appConfigIndex]: field 'privileges' must be string" );
                            }
                        }
                        if( $appConfigItem->{createsql} ) {
                            if( ref( $appConfigItem->{createsql} )) {
                                myFatal( $packageName, "roles section: role $roleName: appconfigitem[$appConfigIndex]: field 'createsql' must be string" );
                            }
                            unless( validFilename( $codeDir, $appConfigItem->{createsql} )) {
                                myFatal( $packageName, "roles section: role $roleName: appconfigitem[$appConfigIndex]: invalid createsql: " . $appConfigItem->{createsql} );
                            }
                        }

                        ++$appConfigIndex;
                    }
                }

            } else {
                myFatal( $packageName, "roles section: unknown role $roleName" );
            }
        }
    }
    if( $json->{customizationpoints} ) {
        unless( ref( $json->{customizationpoints} ) eq 'HASH' ) {
            myFatal( $packageName, "customizationpoints section: not a JSON object" );
        }
        while( my( $custPointName, $custPointJson ) = each %{$json->{customizationpoints}} ) {
            unless( $custPointName =~ m/^[a-z][a-z0-9]*$/ ) {
                myFatal( $packageName, "customizationpoints section: invalid customizationpoint name: $custPointName" );
            }
            unless( ref( $custPointJson ) eq 'HASH' ) {
                myFatal( $packageName, "customizationpoints section: customizationpoint $custPointName: not a JSON object" );
            }
            unless( $custPointJson->{type} ) {
                myFatal( $packageName, "customizationpoints section: customizationpoint $custPointName: no type provided" );
            }
            if( ref( $custPointJson->{type} )) {
                myFatal( $packageName, "customizationpoints section: customizationpoint $custPointName: field 'type' must be string" );
            }
            unless( $custPointJson->{type} =~ m/^(string|password)$/ ) {
                myFatal( $packageName, "customizationpoints section: customizationpoint $custPointName: unknown type" );
            }
            if( $custPointJson->{required} && !JSON::is_bool( $custPointJson->{required} )) {
                myFatal( $packageName, "customizationpoints section: customizationpoint $custPointName: field 'required' must be boolean" );
            }
            if( $custPointJson->{default} ) {
                unless( ref( $custPointJson->{default} ) eq 'HASH' ) {
                    myFatal( $packageName, "customizationpoints section: customizationpoint $custPointName: default: not a JSON object" );
                }
                unless( $custPointJson->{default}->{value} ) {
                    myFatal( $packageName, "customizationpoints section: customizationpoint $custPointName: default: no value given" );
                }
                if( ref( $custPointJson->{default}->{value} )) {
                    myFatal( $packageName, "customizationpoints section: customizationpoint $custPointName: default: field 'value' must be string" );
                }
                if( $custPointJson->{default}->{encoding} ) {
                    if( ref( $custPointJson->{default}->{encoding} )) {
                        myFatal( $packageName, "customizationpoints section: customizationpoint $custPointName: default: field 'encoding' must be string" );
                    }
                    if( $custPointJson->{default}->{encoding} ne 'base64' ) {
                        myFatal( $packageName, "customizationpoints section: customizationpoint $custPointName: default: unknown encoding" );
                    }
                }
            }
        }
    }
}

##
# Emit customized error message.
# $packageName: name of the package whose manifest is checked
sub myFatal {
    my $packageName = shift;
    my $message     = shift;

    fatal( "Manifest JSON for package $packageName:", $message );
}

1;
