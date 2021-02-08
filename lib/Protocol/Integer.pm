# ----------------------------------------------------------------------------
#
# Title:  Class Integer
#
# File - Protocol/Integer.pm
# Version - 1.0
# Author - fpeignot
#
# Name:
#
#       package Protocol::Integer
#
# Abstract:
#
#       Inheritage of the Tpe class in the protocol management layer.
#
# ----------------------------------------------------------------------------
package Protocol::Integer;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

use Exporter;
use Log::Log4perl;
use Data::Dumper;

use Protocol::ScalarType;
use Protocol::Utilities;
use Message;
use Carp;
use bigint;

$VERSION = 1;

@ISA = qw(Protocol::ScalarType);

@EXPORT = qw (SIGNED UNSIGNED);
use constant SIGNED => 0;
use constant UNSIGNED => 1;

# ------------------------------------------------------------------------
# method: _init (private)
#
# Initialisation of the object. Do not call directly.
# ------------------------------------------------------------------------
sub _init {
    my $Self = shift;

    # Default attributs
    exists( $Self->{'size'} )      or $Self->{'size'}      = 4;
    exists( $Self->{'unsigned'} )  or $Self->{'unsigned'}  = 1;
    exists( $Self->{'endianess'} ) or $Self->{'endianess'} = 'big_endian';

    # Call the parent initialization first
    $Self->Protocol::ScalarType::_init(@_);
}

# ------------------------------------------------------------------------
# method: size
#
# Sets or returns the size of the type in bytes.
#
# Parameters:
# value - when void the method get the value. when defined, set the value.
#
# Return:
# the size of the type in bytes.
# ------------------------------------------------------------------------
sub size {
    my $Self = shift;

    if (@_) {
        my $value = shift;
        (        $value == 1
              || $value == 2
              || $value == 3
              || $value == 4
              || $value == 8 )
          or croak "\"$value\" is an unsupported integer size";
        $Self->{'size'} = $value;
    }
    return $Self->{'size'};
}

# ------------------------------------------------------------------------
# method: signed
#
# unsigned attribut reverse accessor
#
# Parameters:
# value - optional boolean
#
# Return:
# true when the integer is signed
# ------------------------------------------------------------------------
sub signed {
    my $Self = shift;

    if (@_) {
        my $value = shift;

        if ($value) {
            $Self->{'unsigned'} = 0;
        }
        else {
            $Self->{'unsigned'} = 1;
        }
    }
    return !$Self->{'unsigned'};
}

# ------------------------------------------------------------------------
# method: unsigned
#
# unsigned attribut accessor
#
# Parameters:
# value - optional boolean
#
# Return:
# the unsigned attribut
# ------------------------------------------------------------------------
sub unsigned {
    my $Self = shift;

    if (@_) {
        $Self->{'unsigned'} = @_;
    }
    return $Self->{'unsigned'};
}

# ------------------------------------------------------------------------
# method: endianess
#
# endianess attribut accessor. The Internet Protocol defines a
# standard big-endian network byte order. The Message class considers that
# is is the normal byte order, little endian being the 'reversed' order.
# Little Endian = (Motorola/Sparc)
# Big endian = (Intel)
#
# Parameters:
# value - optional 'little_endian' or 'big_endian'
#
# Return:
# the endianess attribut
# ------------------------------------------------------------------------
sub endianess {
    my $Self = shift;

    if (@_) {
        my $value = shift;
        ( $value eq 'little_endian' || $value eq 'big_endian' )
          or croak
"incorrect endianess \"$value\" should be 'little_endian' or 'big_endian'";
        $Self->{'endianess'} = $value;
    }
    return $Self->{'endianess'};
}

# ------------------------------------------------------------------------
# method: encode
#
# Encode an integer value. Raises an error when the value is out of range
# except for 64 bits types for which it is usually not possible to construct
# the out of range value
#
# Parameters:
# value - a universal integer
#
# Return: a binary buffer
# ------------------------------------------------------------------------
sub encode {
    my ( $Self, $value ) = @_;

    my $log       = $Self->{Logger};
    my $size      = $Self->{'size'};
    my $unsigned  = $Self->{'unsigned'};
    my $endianess = $Self->{'endianess'};
    $log->info(
"Integer.encode($value), size => $size, unsigned => $unsigned, endianess => $endianess"
    );

    my $bin;
    if ($unsigned) {

        # Unsigned integers
        my $max = 2**( $size * 8 ) - 1;

        # print "max = $max\n";
        croak("unsigned integer value $value not between 0 and $max : ")
          unless ( $value >= 0 ) && ( $value <= $max );

        # byte
        if ( $size == 1 ) {
            $bin = pack( "C", $value );
        }

        # 16 bits
        elsif ( $size == 2 ) {
            if ( $endianess eq 'big_endian' ) {
                $bin = pack( "n", $value );
            }
            else {
                $bin = pack( "v", $value );
            }
        }

        # 24 bits
        elsif ( $size == 3 ) {
            my $High = $value >> 16;
            my $Low = $value & 0xFFFF;
            if ( $endianess eq 'big_endian' ) {
                $bin = pack( "Cn", $High, $Low );
            }
            else {
                $bin = pack( "vC", $Low, $High );
            }
        }

        # 32 bits
        elsif ( $size == 4 ) {
            if ( $endianess eq 'big_endian' ) {
                $bin = pack( "N", $value );
            }
            else {
                $bin = pack( "V", $value );
            }
        }

        # 64 bits
        elsif ( $size == 8 ) {
            my $High = $value >> 32;
            my $Low = $value & 0xFFFFFFFF ;
            if ( $endianess eq 'big_endian' ) {
                $bin = pack( "N2", $High, $Low );
            }
            else {
                $bin = pack( "V2", $Low, $High );
            }
        }

        # others length
        else {
            croak "integer unsupported size $size";
        }

    }
    else {

        # signed integers
 print "Integer.encode($value), size => $size, unsigned => $unsigned, endianess => $endianess\n";

        my $min = - 2**( $size * 8 - 1);
        my $max = 2**( $size * 8 - 1) - 1;

        # print "max = $max\n";
        croak("unsigned integer value $value not between $min and $max : ")
          unless ( $value >= $min ) && ( $value <= $max );

        # byte
        if ( $size == 1 ) {
            $bin = pack( "C", $value );
        }
        croak "signed integer not yet supported";
    }
    return $bin;
}

# ------------------------------------------------------------------------
# method: value
#
# Decode a binary buffer and return a scalar value. This method
# is virtual and each scalar type should provide one implementation.
# ------------------------------------------------------------------------
sub value {
    my ( $Self, $bin ) = @_;

    my $size      = $Self->{'size'};
    my $unsigned  = $Self->{'unsigned'};
    my $endianess = $Self->{'endianess'};

    if ($unsigned) {

        if ( $size == 1 ) {
            # 8 bits
            return unpack( "C", $bin );
        }

        # 16 bits
        elsif ( $size == 2 ) {
            if ( $endianess eq 'big_endian' ) {
                return unpack( "n", $bin );
            }
            else {
                return unpack( "v", $bin );
            }
        }

        # 24 bits
        elsif ( $size == 3 ) {
            my ( $High, $Low );
            if ( $endianess eq 'big_endian' ) {
                ( $High, $Low ) = unpack( "Cn", $bin );
            }
            else {
                ( $Low, $High ) = unpack( "vC", $bin );
                print "little endian High = $High, Low = $Low\n";
            }
            return ( $High * 0x10000 ) + $Low;

        }

        # 32 bits
        elsif ( $size == 4 ) {
            if ( $endianess eq 'big_endian' ) {
                return unpack( "N", $bin );
            }
            else {
                return unpack( "V", $bin );
            }
        }

        # 64 bits
        elsif ( $size == 8 ) {
            my ( $High, $Low );
            if ( $endianess eq 'big_endian' ) {
                ( $High, $Low ) = unpack( "N2", $bin );
            }
            else {
                ( $Low, $High ) = unpack( "V2", $bin );
            }
            return ( $High * 0x100000000 ) + $Low;
        }

        # Unsupported sizes
        else {
            croak "integer unsupported size $size";
        }
    }
    else {
        croak "signed integer not yet supported";
    }
}

# ------------------------------------------------------------------------
# method: decode
#
# Decode a binary buffer and return a message. This method
# is virtual and each type implementation will have to provide one.
# ------------------------------------------------------------------------
sub decode {
    my ($Self, $bin) = @_;

    my $value = $Self->value($bin);
    my $log       = $Self->{Logger};
    my $size      = $Self->{'size'};
    my $unsigned  = $Self->{'unsigned'};
    my $endianess = $Self->{'endianess'};

    my $hexa = bin2hexa($bin);
    $log->trace($Self->{'Class'} . " decode(\"" . $hexa . "\")");
    $log->warn($Self->{'Class'} . "\{size => $size, unsigned => $unsigned, endianess => $endianess\}");
    my ($errors, $error_description);

    if ($Self->{'size'} > length($bin)) {
        $size = length($bin);
        $errors = 1;
        $error_description = "binary buffer too small ($size) to decode a (" .
            $Self->{'size'} . ") bytes integer.";
        $log->error($Self->{'Class'} . ' ' . $error_description);
    } else {
        $size = $Self->{'size'};
        $errors = 0;
        $error_description = undef;
    }
    my $msg = new Message (value => $value,
                        errors => $errors,
                        error_description => $error_description,
                        type => $Self->{'name'},
                        size => $size);
    $log->debug($Self->{'Class'} . " raw=\"" . substr($hexa, 0, $msg->size() * 2) . "\"");
    if (defined($msg->value())) {
        $log->info($Self->{'Class'} . " value=" . $msg->value());
    }

    return $msg;
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
    die "Integer::_check is not yet implemented";
}

# Predeclare a few types
declare Protocol::Integer(
        name      => 'byte',
        size      => 1,
        unsigned  => UNSIGNED,
        endianess => 'big_endian'
    );

declare Protocol::Integer(
        name      => 'unsigned16',
        size      => 2,
        unsigned  => UNSIGNED,
        endianess => 'big_endian'
    );

declare Protocol::Integer(
        name      => 'unsigned32',
        size      => 4,
        unsigned  => UNSIGNED,
        endianess => 'big_endian'
    );

#declare Protocol::Integer(
#        name      => 'unsigned64',
#        size      => 8,
#        unsigned  => UNSIGNED,
#        endianess => 'big_endian'
#    );

# Predeclare a few types
declare Protocol::Integer(
        name      => 'signed8',
        size      => 1,
        unsigned  => SIGNED,
        endianess => 'big_endian'
    );

declare Protocol::Integer(
        name      => 'signed16',
        size      => 2,
        unsigned  => SIGNED,
        endianess => 'big_endian'
    );

declare Protocol::Integer(
        name      => 'signed32',
        size      => 4,
        unsigned  => SIGNED,
        endianess => 'big_endian'
    );

1;
