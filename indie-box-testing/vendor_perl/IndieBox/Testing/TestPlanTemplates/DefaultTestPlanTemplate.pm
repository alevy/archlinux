#!/usr/bin/perl
#
# Default application test suite to test a single AppConfiguration.
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

package IndieBox::Testing::TestSuiteTemplates::DefaultTestSuiteTemplate;

use base qw( IndieBox::Testing::AbstractTestSuiteTemplate );
use fields;
use IndieBox::Logging;

my $steps = [
        [ 'runDeployStep', <<DOC
Deploy the site.
DOC
        ],
        [ 'runAfterFirstDeployStep', <<DOC
TEST: first deployment of the site is functional.
DOC
        ],
        [ 'runUpdateStep', <<DOC
Update all code on the server. This involves backing up, undeploying, redeploying and restoring sites.
DOC
        ],
        [ 'runAfterUpdateStep', <<DOC
TEST: site is again functional and hasn't lost any data after update.
DOC
        ],
        [ 'runRedeployStep', <<DOC
Redeploy the site without changes. This should not cause any changes.
DOC
        ],
        [ 'runAfterRedeployUnchangedStep', <<DOC
TEST: site is unchanged from a redeployment that made no changes.
DOC
        ],
        [ 'runBackupStep', <<DOC
Backup all data at the site.
DOC
        ],
        [ 'runUndeployStep', <<DOC
Undeploy the site.
DOC
        ],
        [ 'runAfterUndeployStep', <<DOC
TEST: site has cleanly undeployed.
DOC
        ],
        [ 'runRedeployStep', <<DOC
Redeploy the previously deployed and undeployed site.
DOC
        ],
        [ 'runAfterFirstDeployStep', <<DOC
TEST: the first deployment of the site is functional. Although the site had been
deployed before, in this step all the previous data should not be present.
DOC
        ],
        [ 'runRestoreStep', <<DOC
Restore the site from the previously created backup.
DOC
        ],
        [ 'runAfterRestoreStep', <<DOC
TEST: site has been restored to the previously backed-up state.
DOC
        ],
        [ 'runRedeployAlternateStep', <<DOC
Redeploy the site, but with an alternate configuration.
DOC
        ],
        [ 'runAfterRedeployAlternateStep', <<DOC
TEST: changed site is functional and did not lose data.
DOC
        ]
];

##
# Instantiate the TestSuite.
sub new {
    my $self      = shift;
    my $site      = shift;
    my $movedSite = shift;

    unless( ref $self ) {
        $self = fields::new( $self );
    }
    
    $self->SUPER::new( $steps );

    return $self;
}

##
# Invoked after the first deployment
sub runAfterFirstDeployStep {
    my $self = shift;

    $self->stepNotImplemented( 'runAfterFirstDeployStep' );
}

##
# Invoked after software update
sub runAfterUpdateStep {
    my $self = shift;

    $self->stepNotImplemented( 'runAfterUpdateStep' );
}

##
# Invoked after a redeployment without configuration change
sub runAfterRedeployUnchangedStep {
    my $self = shift;

    $self->stepNotImplemented( 'runAfterRedeployUnchangedStep' );
}

##
# Invoked after an undeployment
sub runAfterUndeployStep {
    my $self = shift;

    $self->stepNotImplemented( 'runAfterUndeployStep' );
}

##
# Invoked after restore
sub runAfterRestoreStep {
    my $self = shift;

    $self->stepNotImplemented( 'runAfterUndeployStep' );
}
    
##
# Invoked after a redeployment with a configuration change
sub runAfterRedeployAlternateStep {
    my $self = shift;

    $self->stepNotImplemented( 'runRedeployAlternateStep' );
}

##
# End this TestSuite.
sub end {
    my $self = shift;

    return 0;
}

##
# Return the steps in this test suite.
# return: the steps
sub steps {
    return $steps;
}

##
# Return help text.
# return: help text
sub help {
    return 'The default application test suite template.';
}

##
# Return allowed arguments for this command.
# return: allowed arguments, as string
sub helpArguments {
    return [ [ 'siteFile', 'The Site JSON file that contains the AppConfiguration to be tested' ],
             [ 'movedSiteFile', 'A Site JSON file which contains the same AppConfiguration, but at a different URL' ] ];
}

1;
