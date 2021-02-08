# ----------------------------------------------------------------------------
#
# Title:  Class ScalarType
#
# File - Protocol/ScalarType.pm
# Version - 1.0
#
# Name:
#
#       package Protocol::ScalarType
#
# Abstract:
#
#       Scalar types like integer, real, etc.
# ------------------------------------------------------------------------
package Protocol::ScalarType;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK $BYTES);

use Exporter;
use Log::Log4perl;
use Data::Dumper;

use lib "$ENV{'FTF'}/lib";
use Protocol::Utilities;

$VERSION = 1;

@ISA = qw(Protocol::Type);


# ------------------------------------------------------------------------
# method: _init (private)
#
# Initialisation of the object. Do not call directly.
# ------------------------------------------------------------------------
sub _init {
    my $Self = shift;

    # Call the parent initialization first
    $Self->Protocol::Type::_init(@_);

    my %attr = @_;

    # Force structure attributs
    $Self->structure('scalar');
}

1;
