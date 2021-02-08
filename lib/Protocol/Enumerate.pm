# ----------------------------------------------------------------------------
#
# Title:  Class Enumerate
#
# File - Protocol/Enumerate.pm
# Version - 1.0
# Author - fpeignot
#
# Name:
#
#       package Protocol::Enumerate
#
# Abstract:
#
#       Enumerate types are base on Integer, but thier value
#       are set and get using literral strings.
#
# ----------------------------------------------------------------------------
package Protocol::Enumerate;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

use Exporter;
use Log::Log4perl;
use Data::Dumper;

use Protocol::ScalarType;
use Protocol::Utilities;
use Message;
use Carp;

$VERSION = 1;

@ISA = qw(Protocol::Integer);

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

    # Default attributs are the same than for Integer
#    exists( $Self->{'size'} )      or $Self->{'size'}      = 4;
#    exists( $Self->{'unsigned'} )  or $Self->{'unsigned'}  = 1;
#    exists( $Self->{'endianess'} ) or $Self->{'endianess'} = 'big_endian';
    
    # Call the parent initialization first
    $Self->Protocol::Integer::_init(@_);

    exists( $Self->{'labels'} ) or croak "Enumerates need a labels attribute, Ex: labels => {1 => blue, 3 => orange}";
    $Self->{'reversed'} = {};
    foreach my $key (keys (%{$Self->{'labels'} })) {
    	my $value = $Self->{'labels'}->{$key};
        
        if (exists ($Self->{'reversed'}->{$value})) {
            croak "duplicated value $value";        	
        }
        $Self->{'reversed'}->{$value} = $key; 
    }
}

# ------------------------------------------------------------------------
# method: label
#
# Returns the label associated to a code
#
# Parameters:
# code - integer value
#
# Return:
# a string
# ------------------------------------------------------------------------
sub label {
    my ($Self, $code) = @_;

    if (exists ($Self->{'labels'}->{$code})) {
        return $Self->{'labels'}->{$code};
    } else {
    	return undef;
    }
}

# ------------------------------------------------------------------------
# method: code
#
# Returns the code associated to a label
#
# Parameters:
# label - string
#
# Return:
# an integer value
# ------------------------------------------------------------------------
sub code {
    my ($Self, $label) = @_;

    if (exists ($Self->{'reversed'}->{$label})) {
        return $Self->{'reversed'}->{$label};
    } else {
        return undef;
    }
}



# ------------------------------------------------------------------------
# method: encode
#
# Encode an integer value. Raises an error when the value is out of range
# except for 64 bits types for which it is usually not possible to construct
# the out of range value
#
# Parameters:
# value - a string
#
# Return: a binary buffer
# ------------------------------------------------------------------------
sub encode {
    my ( $Self, $value ) = @_;

    $value = $Self->code($value);
    my $log       = $Self->{Logger};
    my $size      = $Self->{'size'};
    my $unsigned  = $Self->{'unsigned'};
    my $endianess = $Self->{'endianess'};
    $log->info(
"Enumerate.encode($value), size => $size, unsigned => $unsigned, endianess => $endianess"
    );
    
    return $Self->Protocol::Integer::encode($value);
}

# ------------------------------------------------------------------------
# method: value
#
# Decode a binary buffer and return a scalar value. This method
# is virtual and each scalar type should provide one implementation.
# ------------------------------------------------------------------------
sub value {
    my ( $Self, $bin ) = @_;

    my $value = $Self->Protocol::Integer::value($bin);
    return $Self->label($value);
}

1;
