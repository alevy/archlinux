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
# $json: the JSON object
# $codeDir: path to the package's code directory
# return: 1 or exits with fatal error
sub checkManifest {
    my $json    = shift;
    my $codeDir = shift;

    IndieBox::InstallableManifest::checkManifest( $json, $codeDir );

    unless( $json->{type} eq 'app' ) {
        fatal( "Manifest JSON: type must be app, is " . $json->{type} );
    }

    my %retentionBuckets = ();
    if( $json->{roles} ) {
        while( my( $roleName, $roleJson ) = each %{$json->{roles}} ) {
            if( $roleName eq 'apache2' ) {
                if( $roleJson->{defaultcontext} ) {
                    if( $roleJson->{fixedcontext} ) {
                        fatal( "Manifest JSON: roles section: role $roleName: must not specify both defaultcontext and fixedcontext" );
                    }
                    if( ref( $roleJson->{defaultcontext} )) {
                        fatal( "Manifest JSON: roles section: role $roleName: field 'defaultcontext' must be string" );
                    }
                    if( $roleJson->{defaultcontext} !~ m!^(/[-a-z0-9]+)*$! ) {
                        fatal( "Manifest JSON: roles section: role $roleName: invalid defaultcontext: " . $roleJson->{defaultcontext} );
                    }

                } elsif( $roleJson->{fixedcontext} ) {
                    if( ref( $roleJson->{fixedcontext} )) {
                        fatal( "Manifest JSON: roles section: role $roleName: field 'fixedcontext' must be string" );
                    }
                    if( $roleJson->{fixedcontext} !~ m!^(/[-a-z0-9]+)*$! ) {
                        fatal( "Manifest JSON: roles section: role $roleName: invalid fixedcontext: " . $roleJson->{fixedcontext} );
                    }
                } else {
                    # not a web app, that's fine
                }

                if( $roleJson->{depends} ) {
                    unless( ref( $roleJson->{depends} ) eq 'ARRAY' ) {
                        fatal( "Manifest JSON: roles section: role $roleName: depends is not an array" );
                    }
                    my $dependsIndex = 0;
                    foreach my $depends ( @{$roleJson->{depends}} ) {
                        if( ref( $depends )) {
                            fatal( "Manifest JSON: roles section: role $roleName: depends[$dependsIndex] must be string" );
                        }
                        if( $depends !~ m!^[-a-z0-9]+$! ) {
                            fatal( "Manifest JSON: roles section: role $roleName: depends[$dependsIndex] invalid: $depends" );
                        }
                        ++$dependsIndex;
                    }
                }

                if( $roleJson->{apache2modules} ) {
                    unless( ref( $roleJson->{apache2modules} ) eq 'ARRAY' ) {
                        fatal( "Manifest JSON: roles section: role $roleName: apache2modules is not an array" );
                    }
                    my $modulesIndex = 0;
                    foreach my $module ( @{$roleJson->{apache2modules}} ) {
                        if( ref( $module )) {
                            fatal( "Manifest JSON: roles section: role $roleName: apache2modules[$modulesIndex] must be string" );
                        }
                        if( $module !~ m!^[-a-z0-9]+$! ) {
                            fatal( "Manifest JSON: roles section: role $roleName: apache2modules[$modulesIndex] invalid: $module" );
                        }
                        ++$modulesIndex;
                    }
                }
                if( $roleJson->{phpmodules} ) {
                    unless( ref( $roleJson->{phpmodules} ) eq 'ARRAY' ) {
                        fatal( "Manifest JSON: roles section: role $roleName: phpmodules is not an array" );
                    }
                    my $modulesIndex = 0;
                    foreach my $module ( @{$roleJson->{phpmodules}} ) {
                        if( ref( $module )) {
                            fatal( "Manifest JSON: roles section: role $roleName: phpmodules[$modulesIndex] must be string" );
                        }
                        if( $module !~ m!^[-a-z0-9]+$! ) {
                            fatal( "Manifest JSON: roles section: role $roleName: phpmodules[$modulesIndex] invalid: $module" );
                        }
                        ++$modulesIndex;
                    }
                }
                if( $roleJson->{appconfigitems} ) {
                    unless( ref( $roleJson->{appconfigitems} ) eq 'ARRAY' ) {
                        fatal( "Manifest JSON: roles section: role $roleName: not an array" );
                    }
                    my $appConfigIndex = 0;
                    foreach my $appConfigItem ( @{$roleJson->{appconfigitems}} ) {
                        if( ref( $appConfigItem->{type} )) {
                            fatal( "Manifest JSON: roles section: role $roleName: appconfigitem[$appConfigIndex]: field 'type' must be string" );
                        }
                        if( $appConfigItem->{type} eq 'perlscript' ) {
                            unless( $appConfigItem->{source} ) {
                                fatal( "Manifest JSON: roles section: role $roleName: appconfigitem[$appConfigIndex]: must specify source" );
                            }
                            if( ref( $appConfigItem->{source} )) {
                                fatal( "Manifest JSON: roles section: role $roleName: appconfigitem[$appConfigIndex]: field 'name' must be string" );
                            }
                            unless( validFilename( $codeDir, $appConfigItem->{source} )) {
                                fatal( "Manifest JSON: roles section: role $roleName: appconfigitem[$appConfigIndex] has invalid name: " . $appConfigItem->{name} );
                            }
                            if( $appConfigItem->{name} ) {
                                fatal( "Manifest JSON: roles section: role $roleName: appconfigitem[$appConfigIndex]: name not permitted for type perlscript" );
                            }
                            if( $appConfigItem->{names} ) {
                                fatal( "Manifest JSON: roles section: role $roleName: appconfigitem[$appConfigIndex]: names not permitted for type perlscript" );
                            }
                        } else {
                            my @names = ();
                            if( defined( $appConfigItem->{name} )) {
                                if( $appConfigItem->{names} ) {
                                    fatal( "Manifest JSON: roles section: role $roleName: appconfigitem[$appConfigIndex]: specify name or names, not both" );
                                }
                                if( ref( $appConfigItem->{name} )) {
                                    fatal( "Manifest JSON: roles section: role $roleName: appconfigitem[$appConfigIndex]: field 'name' must be string" );
                                }
                                # file does not exist yet
                                push @names, $appConfigItem->{name};

                            } else {
                                unless( $appConfigItem->{names} ) {
                                    fatal( "Manifest JSON: roles section: role $roleName: appconfigitem[$appConfigIndex]: must specify name or names" );
                                }
                                unless( ref( $appConfigItem->{names} ) eq 'ARRAY' ) {
                                    fatal( "Manifest JSON: roles section: role $roleName: appconfigitem[$appConfigIndex]: names must be an array" );
                                }
                                my $namesIndex = 0;
                                foreach my $name ( @{$appConfigItem->{names}} ) {
                                    if( ref( $name )) {
                                        fatal( "Manifest JSON: roles section: role $roleName: appconfigitem[$appConfigIndex]: names[$namesIndex] must be string" );
                                    }
                                    # file does not exist yet
                                    push @names, $name;
                                    ++$namesIndex;
                                }
                                unless( $namesIndex > 0 ) {
                                    fatal( "Manifest JSON: roles section: role $roleName: appconfigitem[$appConfigIndex]: must specify name or names" );
                                }
                            }

                            if( $appConfigItem->{type} eq 'file' ) {
                                if( $appConfigItem->{source} ) {
                                    if( $appConfigItem->{template} ) {
                                        fatal( "Manifest JSON: roles section: role $roleName: appconfigitem[$appConfigIndex] of type 'file': specify source or template, not both" );
                                    }
                                    if( ref( $appConfigItem->{source} )) {
                                        fatal( "Manifest JSON: roles section: role $roleName: appconfigitem[$appConfigIndex] of type 'file': field 'source' must be string" );
                                    }
                                    foreach my $name ( @names ) {
                                        unless( validFilename( $codeDir, $appConfigItem->{source}, $name )) {
                                            fatal( "Manifest JSON: roles section: role $roleName: appconfigitem[$appConfigIndex] of type 'file': invalid source: " . $appConfigItem->{source} . " for name $name" );
                                        }
                                    }
                                } elsif( $appConfigItem->{template} ) {
                                    unless( $appConfigItem->{templatelang} ) {
                                        fatal( "Manifest JSON: roles section: role $roleName: appconfigitem[$appConfigIndex] of type 'file': if specifying template, must specify templatelang as well" );
                                    }
                                    if( ref( $appConfigItem->{template} )) {
                                        fatal( "Manifest JSON: roles section: role $roleName: appconfigitem[$appConfigIndex] of type 'file': field 'template' must be string" );
                                    }
                                    foreach my $name ( @names ) {
                                        unless( validFilename( $codeDir, $appConfigItem->{template}, $name )) {
                                            fatal( "Manifest JSON: roles section: role $roleName: appconfigitem[$appConfigIndex] of type 'file': invalid template: " . $appConfigItem->{template} . " for name $name" );
                                        }
                                    }
                                    if( ref( $appConfigItem->{templatelang} )) {
                                        fatal( "Manifest JSON: roles section: role $roleName: appconfigitem[$appConfigIndex] of type 'file': field 'templatelang' must be string" );
                                    }
                                    unless( $appConfigItem->{templatelang} =~ m!^(varsubst|perlscript)$! ) {
                                        fatal( "Manifest JSON: roles section: role $roleName: appconfigitem[$appConfigIndex] of type 'file': invalid templatelang: " . $appConfigItem->{templatelang} );
                                    }
                                } else {
                                    fatal( "Manifest JSON: roles section: role $roleName: appconfigitem[$appConfigIndex] of type 'file': must specify source or template" );
                                }

                            } elsif( $appConfigItem->{type} eq 'directory' ) {

                            } elsif( $appConfigItem->{type} eq 'directorytree' ) {
                                unless( $appConfigItem->{source} ) {
                                    fatal( "Manifest JSON: roles section: role $roleName: appconfigitem[$appConfigIndex] of type 'directorytree': must specify source" );
                                }
                                if( ref( $appConfigItem->{source} )) {
                                    fatal( "Manifest JSON: roles section: role $roleName: appconfigitem[$appConfigIndex] of type 'directorytree': field 'source' must be string" );
                                }
                                foreach my $name ( @names ) {
                                    unless( validFilename( $codeDir, $appConfigItem->{source}, $name )) {
                                        fatal( "Manifest JSON: roles section: role $roleName: appconfigitem[$appConfigIndex] of type 'directorytree': invalid source: " . $appConfigItem->{source} . " for name $name" );
                                    }
                                }

                            } elsif( $appConfigItem->{type} eq 'symlink' ) {
                                unless( $appConfigItem->{source} ) {
                                    fatal( "Manifest JSON: roles section: role $roleName: appconfigitem[$appConfigIndex] of type 'symlink': must specify source" );
                                }
                                if( ref( $appConfigItem->{source} )) {
                                    fatal( "Manifest JSON: roles section: role $roleName: appconfigitem[$appConfigIndex] of type 'symlink': field 'source' must be string" );
                                }
                                foreach my $name ( @names ) {
                                    unless( validFilename( $codeDir, $appConfigItem->{source}, $name )) {
                                        fatal( "Manifest JSON: roles section: role $roleName: appconfigitem[$appConfigIndex] of type 'symlink': invalid source: " . $appConfigItem->{source} . " for name $name" );
                                    }
                                }

                            # perlscript handled above
                            } else {
                                fatal( "Manifest JSON: roles section: role $roleName: appconfigitem[$appConfigIndex] has unknown type" );
                            }

                            if( $appConfigItem->{uname} ) {
                                if( ref( $appConfigItem->{uname} )) {
                                    fatal( "Manifest JSON: roles section: role $roleName: appconfigitem[$appConfigIndex]: field 'uname' must be string" );
                                }
                                if( $appConfigItem->{uname} !~ m!^[-a-z0-9]+$! ) {
                                    fatal( "Manifest JSON: roles section: role $roleName: appconfigitem[$appConfigIndex]: invalid uname: " . $appConfigItem->{uname} );
                                }
                            }
                            if( $appConfigItem->{gname} ) {
                                if( ref( $appConfigItem->{gname} )) {
                                    fatal( "Manifest JSON: roles section: role $roleName: appconfigitem[$appConfigIndex]: field 'gname' must be string" );
                                }
                                if( $appConfigItem->{gname} !~ m!^[-a-z0-9]+$! ) {
                                    fatal( "Manifest JSON: roles section: role $roleName: appconfigitem[$appConfigIndex]: invalid gname: " . $appConfigItem->{gname} );
                                }
                            }
                            if( $appConfigItem->{mode} ) {
                                if( ref( $appConfigItem->{mode} )) {
                                    fatal( "Manifest JSON: roles section: role $roleName: appconfigitem[$appConfigIndex]: field 'mode' must be string (octal)" );
                                }
                                if( $appConfigItem->{mode} !~ m!^(preserve|[0-7]{3,4})$! ) {
                                    fatal( "Manifest JSON: roles section: role $roleName: appconfigitem[$appConfigIndex]: invalid mode: " . $appConfigItem->{mode} );
                                }
                            }
                            if( $appConfigItem->{retention} ) {
                                if( ref( $appConfigItem->{retention} )) {
                                    fatal( "Manifest JSON: roles section: role $roleName: appconfigitem[$appConfigIndex]: field 'retention' must be string" );
                                }
                                if( $appConfigItem->{retention} ne 'keep' ) {
                                    fatal( "Manifest JSON: roles section: role $roleName: appconfigitem[$appConfigIndex] has unknown retention value: " . $appConfigItem->{retention} );
                                }
                                unless( $appConfigItem->{retentionbucket} ) {
                                    fatal( "Manifest JSON: roles section: role $roleName: appconfigitem[$appConfigIndex]: if specifying retention, also specify retentionbucket" );
                                }
                                if( ref( $appConfigItem->{retentionbucket} )) {
                                    fatal( "Manifest JSON: roles section: role $roleName: appconfigitem[$appConfigIndex]: field 'retentionbucket' must be string" );
                                }
                                if( $retentionBuckets{$appConfigItem->{retentionbucket}} ) {
                                    fatal( "Manifest JSON: roles section: role $roleName: appconfigitem[$appConfigIndex]: field 'retentionbucket' must be unique: " . $appConfigItem->{retentionbucket} );
                                }
                                $retentionBuckets{$appConfigItem->{retentionbucket}} = 1;
                            }
                        }
                        ++$appConfigIndex;
                    }
                }
                if( $roleJson->{triggersactivate} ) {
                    unless( ref( $roleJson->{triggersactivate} ) eq 'ARRAY' ) {
                        fatal( "Manifest JSON: roles section: role $roleName: triggersactivate: not an array" );
                    }
                    my $triggersIndex = 0;
                    my %triggers = ();
                    foreach my $triggersJson ( @{$roleJson->{triggersactivate}} ) {
                        if( ref( $triggersJson )) {
                            fatal( "Manifest JSON: roles section: role $roleName: triggersactivate[$triggersIndex]: not an array" );
                        }
                        unless( $triggersJson =~ m/^[a-z][-a-z0-9]*$/ ) {
                            fatal( "Manifest JSON: roles section: role $roleName: triggersactivate[$triggersIndex]: invalid trigger name: $triggersJson" );
                        }
                        if( $triggers{$triggersJson} ) {
                            fatal( "Manifest JSON: roles section: role $roleName: triggersactivate[$triggersIndex] is not unique: $triggersJson" );
                            $triggers{$triggersJson} = 1;
                        }
                        ++$triggersIndex;
                    }
                }
                if( $roleJson->{installer} ) {
                    unless( ref( $roleJson->{installer} ) eq 'HASH' ) {
                        fatal( "Manifest JSON: roles section: role $roleName: installer: not a JSON object" );
                    }
                    if( ref( $roleJson->{installer}->{type} )) {
                        fatal( "Manifest JSON: roles section: role $roleName: installer: field 'type' must be string" );
                    }
                    if( $roleJson->{installer}->{type} ne 'perlscript' ) {
                        fatal( "Manifest JSON: roles section: role $roleName: installer: unknown type: " . $roleJson->{installer}->{type} );
                    }
                    if( ref( $roleJson->{installer}->{name} ) ) {
                        fatal( "Manifest JSON: roles section: role $roleName: installer: invalid name" );
                    }
                    ## FIXME: check for existence of file
                }

            } elsif( $roleName eq 'mysql' ) {
                my %databaseNames = ();
                if( $roleJson->{appconfigitems} ) {
                    unless( ref( $roleJson->{appconfigitems} ) eq 'ARRAY' ) {
                        fatal( "Manifest JSON: roles section: role $roleName: not an array" );
                    }
                    my $appConfigIndex = 0;
                    foreach my $appConfigItem ( @{$roleJson->{appconfigitems}} ) {
                        if( ref( $appConfigItem->{type} )) {
                            fatal( "Manifest JSON: roles section: role $roleName: appconfigitem[$appConfigIndex]: field 'type' must be string" );
                        }
                        if( $appConfigItem->{type} ne 'mysql-database' ) {
                            fatal( "Manifest JSON: roles section: role $roleName: appconfigitem[$appConfigIndex] has unknown type: " . $appConfigItem->{type} );
                        }
                        if( ref( $appConfigItem->{name} )) {
                            fatal( "Manifest JSON: roles section: role $roleName: appconfigitem[$appConfigIndex]: field 'name' must be string" );
                        }
                        if( $appConfigItem->{name} !~ m/^[a-z][a-z0-9]*$/ ) {
                            fatal( "Manifest JSON: roles section: role $roleName: appconfigitem[$appConfigIndex] has invalid symbolic database name: " . $appConfigItem->{name} );
                        }
                        if( $databaseNames{$appConfigItem->{name}} ) {
                            fatal( "Manifest JSON: roles section: role $roleName: appconfigitem[$appConfigIndex] has non-unique symbolic database name" );
                            $databaseNames{$appConfigItem->{name}} = 1;
                        }
                        if( $appConfigItem->{retention} ) {
                            if( ref( $appConfigItem->{retention} )) {
                                fatal( "Manifest JSON: roles section: role $roleName: appconfigitem[$appConfigIndex]: field 'retention' must be string" );
                            }
                            if( $appConfigItem->{retention} ne 'keep' ) {
                                fatal( "Manifest JSON: roles section: role $roleName: appconfigitem[$appConfigIndex] has unknown retention value: " . $appConfigItem->{retention} );
                            }
                            unless( $appConfigItem->{retentionbucket} ) {
                                fatal( "Manifest JSON: roles section: role $roleName: appconfigitem[$appConfigIndex]: if specifying retention, also specify retentionbucket" );
                            }
                            if( ref( $appConfigItem->{retentionbucket} )) {
                                fatal( "Manifest JSON: roles section: role $roleName: appconfigitem[$appConfigIndex]: field 'retentionbucket' must be string" );
                            }
                            if( $retentionBuckets{$appConfigItem->{retentionbucket}} ) {
                                fatal( "Manifest JSON: roles section: role $roleName: appconfigitem[$appConfigIndex]: field 'retentionbucket' must be unique: " . $appConfigItem->{retentionbucket} );
                            }
                            $retentionBuckets{$appConfigItem->{retentionbucket}} = 1;
                        }
                        if( $appConfigItem->{privileges} ) {
                            if( ref( $appConfigItem->{privileges} )) {
                                fatal( "Manifest JSON: roles section: role $roleName: appconfigitem[$appConfigIndex]: field 'privileges' must be string" );
                            }
                        }
                        if( $appConfigItem->{createsql} ) {
                            if( ref( $appConfigItem->{createsql} )) {
                                fatal( "Manifest JSON: roles section: role $roleName: appconfigitem[$appConfigIndex]: field 'createsql' must be string" );
                            }
                            unless( validFilename( $codeDir, $appConfigItem->{createsql} )) {
                                fatal( "Manifest JSON: roles section: role $roleName: appconfigitem[$appConfigIndex]: invalid createsql: " . $appConfigItem->{createsql} );
                            }
                        }

                        ++$appConfigIndex;
                    }
                }

            } else {
                fatal( "Manifest JSON: roles section: unknown role $roleName" );
            }
        }
    }
    if( $json->{customizationpoints} ) {
        unless( ref( $json->{customizationpoints} ) eq 'HASH' ) {
            fatal( "Manifest JSON: customizationpoints section: not a JSON object" );
        }
        while( my( $custPointName, $custPointJson ) = each %{$json->{customizationpoints}} ) {
            unless( $custPointName =~ m/^[a-z][a-z0-9]*$/ ) {
                fatal( "Manifest JSON: customizationpoints section: invalid customizationpoint name: $custPointName" );
            }
            unless( ref( $custPointJson ) eq 'HASH' ) {
                fatal( "Manifest JSON: customizationpoints section: customizationpoint $custPointName: not a JSON object" );
            }
            unless( $custPointJson->{type} ) {
                fatal( "Manifest JSON: customizationpoints section: customizationpoint $custPointName: no type provided" );
            }
            if( ref( $custPointJson->{type} )) {
                fatal( "Manifest JSON: customizationpoints section: customizationpoint $custPointName: field 'type' must be string" );
            }
            unless( $custPointJson->{type} =~ m/^(string|password)$/ ) {
                fatal( "Manifest JSON: customizationpoints section: customizationpoint $custPointName: unknown type" );
            }
            if( $custPointJson->{required} && !JSON::is_bool( $custPointJson->{required} )) {
                fatal( "Manifest JSON: customizationpoints section: customizationpoint $custPointName: field 'required' must be boolean" );
            }
            if( $custPointJson->{default} ) {
                unless( ref( $custPointJson->{default} ) eq 'HASH' ) {
                    fatal( "Manifest JSON: customizationpoints section: customizationpoint $custPointName: default: not a JSON object" );
                }
                unless( $custPointJson->{default}->{value} ) {
                    fatal( "Manifest JSON: customizationpoints section: customizationpoint $custPointName: default: no value given" );
                }
                if( ref( $custPointJson->{default}->{value} )) {
                    fatal( "Manifest JSON: customizationpoints section: customizationpoint $custPointName: default: field 'value' must be string" );
                }
                if( $custPointJson->{default}->{encoding} ) {
                    if( ref( $custPointJson->{default}->{encoding} )) {
                        fatal( "Manifest JSON: customizationpoints section: customizationpoint $custPointName: default: field 'encoding' must be string" );
                    }
                    if( $custPointJson->{default}->{encoding} ne 'base64' ) {
                        fatal( "Manifest JSON: customizationpoints section: customizationpoint $custPointName: default: unknown encoding" );
                    }
                }
            }
        }
    }
}


1;
