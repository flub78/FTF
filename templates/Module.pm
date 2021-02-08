# ----------------------------------------------------------------------------
#
# Title:  Module Template
#
# Source - <file:../Module.pm.html>
# Version - 1.0
#
# Abstract:
#
#       Template for Perl modules used in the toolbox context.
#       Its usage is recommended for every module of the
#       toolbox and in test suite development.
#
#       This template is to be used for all non object oriented
#       libraries.
#
# Usage:
#    (start code)
#    # put here some examples of the API usage
#
# (end)
# ------------------------------------------------------------------------
package Module;

use strict;
use vars qw($VERSION @EXPORT);
use Exporter;

$VERSION = 1;
use Data::Dumper;

# ------------------------------------------------------------------------
# routine: routine
#
# regular routine template, duplicate for each real routine.
#
# parameters:
# param1 - Parameter 1
# param2 - Parameter 2
#
# return: describe the returned value
# ------------------------------------------------------------------------
sub routine {
    my ($param1, $param2)   = @_;
    # Something to do
}

1;
