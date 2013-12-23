#!/usr/bin/perl
#
# Default application test suite.
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

package IndieBox::Testing::Suites::Default;

use fields;
use IndieBox::Logging;

##
# Instantiate the Suite. This may take a long time.
sub setup {
    my $self = shift;

    unless( ref $self ) {
        $self = fields::new( $self );
    }

    return $self;
}

##
# Teardown this Suite.
sub teardown {
    my $self = shift;

    return 0;
}

##
# Return help text.
# return: help text
sub help {
    return 'The default application test suite.';
}

1;
