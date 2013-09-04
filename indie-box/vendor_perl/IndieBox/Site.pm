#!/usr/bin/perl
#
# Represents a Site for Indie Box Project
#
# Copyright (C) 2013 Johannes Ernst
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

package IndieBox::Site;

use IndieBox::AppConfiguration;
use IndieBox::Utils qw( fatal );
use JSON;

use fields qw{json appConfigs};

##
# Constructor.
# $json: JSON object containing Site JSON
# return: Site object
sub new {
    my $self = shift;
    my $json = shift;

    unless( ref $self ) {
        $self = fields::new( $self );
    }
    $self->{json} = $json;

    $self->_checkJson();

    return $self;
}

##
# Obtain the AppConfigurations at this Site.
# return: array of AppConfiguration objects
sub appConfigs {
    my $self = shift;

    unless( defined( $self->{appConfigs} )) {
        my $jsonAppConfigs = $self->{json}->{appconfigs};
        $self->{appConfigs} = [];
        foreach my $current ( @$jsonAppConfigs ) {
            push @{$self->{appConfigs}}, new IndieBox::AppConfiguration( $current, $self );
        }
    }
    return $self->{appConfigs};
}

##
# Check validity of the Site JSON
# return: 1 or exits with fatal error
sub _checkJson {
    my $self = shift;
    my $json = $self->{json};

    unless( $json ) {
        fatal( "No Site JSON present" );
    }
    unless( $json->{siteid} ) {
        fatal( "Site JSON: missing siteid" );
    }
    unless( ref( $json->{siteid} ) || $json->{siteid} =~ m/^s[0-9a-f]{4}([0-9a-f]{28})?$/ ) {
        fatal( "Site JSON: invalid siteid, must be s followed by 4 or 32 hex chars" );
    }
    unless( $json->{hostname} ) {
        fatal( "Site JSON: missing hostname" );
    }
    unless( ref( $json->{hostname} ) || $json->{hostname} =~ m/^(?=.{1,255}$)[0-9A-Za-z](?:(?:[0-9A-Za-z]|-){0,61}[0-9A-Za-z])?(?:\.[0-9A-Za-z](?:(?:[0-9A-Za-z]|-){0,61}[0-9A-Za-z])?)*\.?$/ ) {
        # regex from http://stackoverflow.com/a/1420225/200304
        fatal( "Site JSON: invalid hostname" );
    }

    if( $json->{ssl} ) {
        unless( ref( $json->{ssl} ) eq 'HASH' ) {
            fatal( "Site JSON: ssl section: not a JSON object" );
        }
        unless( $json->{ssl}->{key} || !ref( $json->{ssl}->{key} )) {
            fatal( "Site JSON: ssl section: missing or invalid key" );
        }
        unless( $json->{ssl}->{crt} || !ref( $json->{ssl}->{crt} )) {
            fatal( "Site JSON: ssl section: missing or invalid crt" );
        }
        unless( $json->{ssl}->{crtchain} || !ref( $json->{ssl}->{crtchain} )) {
            fatal( "Site JSON: ssl section: missing or invalid crtchain" );
        }
    }

    if( $json->{wellknown} ) {
        unless( ref( $json->{wellknown} ) eq 'HASH' ) {
            fatal( "Site JSON: wellknown section: not a JSON object" );
        }
        if( $json->{wellknown}->{robotstxt} && ref( $json->{wellknown}->{robotstxt} )) {
            fatal( "Site JSON: wellknown section: invalid robotstxt" );
        }
        if(    $json->{wellknown}->{sitemapxml}
            && (    ref( $json->{wellknown}->{sitemapxml} )
                 || $json->{wellknown}->{sitemapxml} !~ m!^<\?xml! ))
        {
            fatal( "Site JSON: wellknown section: invalid sitemapxml" );
        }
        if( $json->{wellknown}->{faviconicobase64} && ref( $json->{wellknown}->{faviconicobase64} )) {
            fatal( "Site JSON: wellknown section: invalid faviconicobase64" );
        }
    }

    if( $json->{appconfigs} ) {
        unless( ref( $json->{appconfigs} ) eq 'ARRAY' ) {
            fatal( "Site JSON: appconfigs section: not a JSON array" );
        }

        my $i=0;
        foreach my $appConfigJson ( @{$json->{appconfigs}} ) {
            unless( $appConfigJson->{appconfigid} ) {
                fatal( "Site JSON: appconfig $i: missing appconfigid" );
            }
            unless( ref( $appConfigJson->{appconfigid} ) || $appConfigJson->{appconfigid} =~ m/^a[0-9a-f]{4}([0-9a-f]{28})?$/ ) {
                fatal( "Site JSON: appconfig $i: invalid appconfigid, must be a followed by 4 or 32 hex chars" );
            }
            if(    $appConfigJson->{context}
                && (    ref( $appConfigJson->{context} )
                     || $appConfigJson->{context} !~ m!^(/[-_\.a-zA-Z0-9]+)?$! ))
            {
                fatal( "Site JSON: appconfig $i: invalid context, must be valid context URL without trailing slash" );
            }
            if( $appConfigJson->{isdefault} && !JSON::is_bool( $appConfigJson->{isdefault} )) {
                fatal( "Site JSON: appconfig $i: invalid isdefault, must be true or false" );
            }
            unless( $appConfigJson->{appid} && !ref( $appConfigJson->{appid} )) {
                fatal( "Site JSON: appconfig $i: invalid appid" );
                # FIXME: format of this string must be better specified and checked
            }
            ++$i;
        }
    }
    return 1;
}

1;
