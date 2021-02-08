# ----------------------------------------------------------------------------
#
# Title:  Class String
#
# File - Protocol/String.pm
# Version - 1.0
#
# Name:
#
#       package Protocol::String
#
# Abstract:
#
#       String is a type for wihich encoding is a neutral operation.
#       The result equal the input parameter. The only reason to supply this
#       package is for othogonality of the framework, that way strings can
#       be handled like other types.
# ------------------------------------------------------------------------
package Protocol::String;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK $BYTES);

use Exporter;
use Log::Log4perl;
use Data::Dumper;
use Carp;

use lib "$ENV{'FTF'}/lib";
use Protocol::ScalarType;
use Protocol::Utilities qw(hexa2bin bin2hexa);
use Message;

$VERSION = 1;

@ISA = qw(Protocol::ScalarType);

# ------------------------------------------------------------------------
# method: encode
# Encode a value or a list of values according to the type.
#
# Parameters:
# $value - a string to encode
#
# Return: a binary buffer
# ------------------------------------------------------------------------
sub encode {
    my ( $Self, $value ) = @_;

    my $log = $Self->{Logger};
    $log->info("encoding $value according to $Self->{'Class'}");

    if ( exists( $Self->{'size'} ) ) {
        my $size      = $Self->{'size'};
        my $real_size = length($value);
        croak "String wrong size, expecting $size bytes, got $real_size"
          if ( $size != $real_size );
    }

    # nothing to do
    return $value;
}

# ------------------------------------------------------------------------
# method: decode
#
# Decode a binary buffer and return a message of the type. his method
# is virtual and each type should provide one implementation.
# ------------------------------------------------------------------------
sub decode {
    my ( $Self, $bin ) = @_;

    my $log = $Self->{Logger};
    $log->trace( $Self->{'Class'} . " decode(\"" . $bin . ")\"" );

    my $msg;

    if ( exists( $Self->{'size'} ) ) {
        my $size = $Self->{'size'};
        $log->warn( $Self->{'Class'} . "\{size => $size\}" );
        if ( length($bin) < $Self->{'size'} ) {

            # size defined, but not enough data
            $msg = new Message(
                value  => $bin,
                errors => 0,
                type   => $Self->{'name'},
                size   => length($bin)
            );
            $msg->add_error( "binary buffer to small ("
                  . length($bin)
                  . ") decoding string ("
                  . $Self->{'size'}
                  . ")" );
            $log->error( $Self->{'Class'} . ' ' . $msg->error_description() );
        }
        else {

            # size defined and enough data
            $msg = new Message(
                value  => substr($bin, 0, $Self->{'size'}),
                errors => 0,
                type   => $Self->{'name'},
                size   => $Self->{'size'}
            );
        }
    }
    else {

        # no size defined
        $msg = new Message(
            value  => $bin,
            errors => 0,
            type   => $Self->{'name'},
            size   => length($bin)
        );
    }
    return $msg;
}

# ------------------------------------------------------------------------
# method: value
#
# Decode a binary buffer and return a scalar value. This method
# is virtual and each scalar type should provide one implementation.
# ------------------------------------------------------------------------
sub value {
    my ( $Self, $bin ) = @_;

    return ($bin);
}

# ------------------------------------------------------------------------
# method: _check
#
# Check the validity of the attributes and the coherency of the object.
# When the various accessors are used checks are performed along the way,
# but the object can be built with various component initialized directly
# through a hash table. In this case it is useufull to be able to check the
# object coherency.
# ------------------------------------------------------------------------
sub _check {
    my $Self = shift;
    croak "String::_check is not yet implemented";
}

declare Protocol::String( name => 'string' );
1;
