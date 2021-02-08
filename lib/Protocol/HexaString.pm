# ----------------------------------------------------------------------------
#
# Title:  Class HexaString
#
# File - Protocol/HexaString.pm
# Version - 1.0
#
# Name:
#
#       package Protocol::HexaString
#
# Abstract:
#
#       HexaString inherits from Types. It is the simpler
#       supported type.
#
#
# ------------------------------------------------------------------------
package Protocol::HexaString;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK $BYTES);

use Exporter;
use Log::Log4perl;
use Data::Dumper;
use Protocol::ScalarType;
use Protocol::Utilities;
use Protocol::Type;
use Message;
use Carp;

$VERSION = 1;

@ISA = qw(Protocol::ScalarType);


# ------------------------------------------------------------------------
# method: encode
# Encode a value or a list of values according to the type.
#
# Parameters:
# value - an hexadecimal string
#
# Return: a binary buffer
# ------------------------------------------------------------------------
sub encode {
    my ($Self, $value) = @_;
    
    my $log = $Self->{Logger};
    $log->info("encoding $value according to $Self->{'Class'}");

	croak "$value contains an odd number of digits" if (length($value) % 2 != 0);
	if (exists($Self->{'size'})) {
	    my $size = $Self->{'size'};
	    my $real_size = length($value) / 2;
	    croak "HexaString wrong size, expecting $size bytes, got $real_size" if ($size != $real_size);
	}
	my $bin = hexa2bin ($value);
	return $bin;
}

# ------------------------------------------------------------------------
# method: value
#
# Decode a binary buffer and return a scalar value. This method 
# is virtual and each scalar type should provide one implementation.
# ------------------------------------------------------------------------
sub value {
    my ($Self, $bin) = @_;

	return (bin2hexa($bin));
}

# ------------------------------------------------------------------------
# method: decode
#
# Decode a binary buffer and return a message of the type. his method
# is virtual and each type should provide one implementation.
# ------------------------------------------------------------------------
sub decode {
    my ($Self, $bin) = @_;
    
    my $log = $Self->{Logger};  
    $log->trace($Self->{'Class'} . " decode(\"" . bin2hexa($bin) . ")\"");

	my $hexa = bin2hexa($bin);
	my $msg;
						   
	if (exists($Self->{'size'})) {
	    my $size = $Self->{'size'};
	    $log->warn($Self->{'Class'} . "\{size => $size\}");
        if (length($bin) < $size) {
            # size defined, but not enough data
            $msg = new Message (value => $hexa,
                           errors => 0,
                           type => $Self->{'name'},
                           size => length($bin));
            $msg->add_error("binary buffer to small (" . length($bin) . ") decoding HexaString (" . $size . ")");
            $log->error($Self->{'Class'} . ' ' . $msg->error_description()); 
        } else {
            # size defined and enough data
            $msg = new Message (value => substr($hexa, 0, $Self->{'size'} * 2),
                           errors => 0,
                           type => $Self->{'name'},
                           size => $Self->{'size'});
        }
    } else {
        # no size defined
        $msg = new Message (value => $hexa,
                           errors => 0,
                           type => $Self->{'name'},
                           size => length($bin));
    }
    $log->info($Self->{'Class'} . " value=" . $msg->value());
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
    croak "HexaString::_check is not yet implemented";
}

declare Protocol::HexaString (name => 'binary');
1;
