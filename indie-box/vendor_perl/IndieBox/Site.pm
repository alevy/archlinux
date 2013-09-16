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

use IndieBox::Apache2;
use IndieBox::AppConfiguration;
use IndieBox::Logging;
use IndieBox::Utils;
use JSON;
use MIME::Base64;

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
# Obtain the site's id.
# return: string
sub siteId {
    my $self = shift;

    return $self->{json}->{siteid};
}

##
# Obtain the site's host name.
# return: string
sub hostName {
    my $self = shift;

    return $self->{json}->{hostname};
}

##
# Determine whether SSL data has been given.
# return: 0 or 1
sub hasSsl {
    my $self = shift;

    return ( $self->{json}->{ssl}->{key} ? 1 : 0 );
}

##
# Obtain the SSL key, if any has been provided.
# return: the SSL key
sub sslKey {
    my $self = shift;

    return $self->{json}->{ssl}->{key};
}

##
# Obtain the SSL certificate, if any has been provided.
# return: the SSL certificate
sub sslCert {
    my $self = shift;

    return $self->{json}->{ssl}->{crt};
}

##
# Obtain the SSL certificate chain, if any has been provided.
# return: the SSL certificate chain
sub sslCertChain {
    my $self = shift;

    return $self->{json}->{ssl}->{crtchain};
}

##
# Obtain the site's robots.txt file content, if any has been provided.
# return: robots.txt content
sub robotsTxt {
    my $self = shift;

    return $self->{json}->{wellknown}->{robotstxt};
}

##
# Obtain the beginning of the site's robots.txt file content, if no robots.txt
# has been provided.
# return: prefix of robots.txt content
sub robotsTxtPrefix {
    my $self = shift;

    return $self->{json}->{wellknown}->{robotstxtprefix};
}

##
# Obtain the site's sitemap.xml file content, if any has been provided.
# return: robots.txt content
sub sitemapXml {
    my $self = shift;

    return $self->{json}->{wellknown}->{sitemapxml};
}

##
# Obtain the site's favicon.ico file content, if any has been provided.
# return: binary content of favicon.ico
sub faviconIco {
    my $self = shift;

    if( $self->{json}->{wellknown}->{faviconicobase64} ) {
        return decode_base64( $self->{json}->{wellknown}->{faviconicobase64} );
    } else {
        return undef;
    }
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
# Obtain an AppConfiguation with a particular appconfigid on this Site.
# return: the AppConfiguration, or undef
sub appConfig {
    my $self        = shift;
    my $appconfigid = shift;

    foreach my $appConfig ( @{$self->appConfigs} ) {
        if( $appconfigid eq $appConfig->appConfigId ) {
            return $appConfig;
        }
    }
    return undef;
}

##
# Add names of packages that are required to run the specified roles for this site.
# $roleNames: array of role names
# $packages: hash of packages
sub addToPrerequisites {
    my $self      = shift;
    my $roleNames = shift;
    my $packages  = shift;

    foreach my $appConfig ( @{ $self->appConfigs} ) {
        my $app = $appConfig->app;
        $app->addToPrerequisites( $roleNames, $packages );
    }
    1;
}

##
# Deploy this site
sub deploy {
    my $self = shift;

    print "Placeholder: about to deploy\n";
    print "    siteid:        " . $self->siteId . "\n";
    print "    hostname:      " . $self->hostName . "\n";

    foreach my $appConfig ( @{$self->appConfigs} ) {
        print "        appconfigid: " . $appConfig->appConfigId . "\n";
        print "        context:     " . $appConfig->context     . "\n";
    }

    IndieBox::Apache2::setupSite( $self );

    1;
}

##
# Undeploy this site
sub undeploy {
    my $self = shift;

    print "Placeholder: about to undeploy\n";
    print "    siteid:        " . $self->siteId . "\n";
    print "    hostname:      " . $self->hostName . "\n";

    foreach my $appConfig ( @{$self->appConfigs} ) {
        print "        appconfigid: " . $appConfig->appConfigId . "\n";
    }

    IndieBox::Apache2::removeSite( $self );

    1;
}

##
# Set up a placeholder for this new site: "coming soon"
# $triggers: triggers to be executed may be added to this hash
sub setupPlaceholder {
    my $self     = shift;
    my $triggers = shift;

    print "Placeholder: createPlaceholder\n";
    print "    siteid:        " . $self->siteId . "\n";
    print "    hostname:      " . $self->hostName . "\n";

    IndieBox::Apache2::setupPlaceholderSite( $self, 'maintenance' );

    $triggers->{'httpd-reload'} = 1;
}

##
# Suspend this site: replace site with an "updating" placeholder or such
# $triggers: triggers to be executed may be added to this hash
sub suspend {
    my $self     = shift;
    my $triggers = shift;

    print "Placeholder: suspend\n";
    print "    siteid:        " . $self->siteId . "\n";
    print "    hostname:      " . $self->hostName . "\n";

    IndieBox::Apache2::setupPlaceholderSite( $self, 'maintenance' );

    $triggers->{'httpd-reload'} = 1;
}

##
# Resume this site from suspension
# $triggers: triggers to be executed may be added to this hash
sub resume {
    my $self     = shift;
    my $triggers = shift;

    print "Placeholder: resume\n";
    print "    siteid:        " . $self->siteId . "\n";
    print "    hostname:      " . $self->hostName . "\n";

    $triggers->{'httpd-reload'} = 1;
}

##
# Permanently disable this site
# $triggers: triggers to be executed may be added to this hash
sub disable {
    my $self     = shift;
    my $triggers = shift;

    print "Placeholder: disable\n";
    print "    siteid:        " . $self->siteId . "\n";
    print "    hostname:      " . $self->hostName . "\n";

    $triggers->{'httpd-reload'} = 1;
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
