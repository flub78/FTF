# ----------------------------------------------------------------------------
#
# Title: Class CODECs::Support
#
# File - Support.pm
# Author - frederic
#
# Name:
#
#    package CODECs
#
# Abstract:
#       Support routines for CODEC.
#
# Contents:
#    bin2hexa - translate binary buffer into hexadecimal strings
#    hexa2bin - translate hexadecimal strings into binary buffer
#    bin2unsigned - translate a binary buffer into an unsigned integer
#    unsigned2bin - translate an unsigned integer into a binary buffer
#
# TODO should encode/decode always use messages ?
# ----------------------------------------------------------------------------
package CODECs::Support;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

use Log::Log4perl;
use Exporter;
use Message;
use Data::Dumper;

$VERSION = 1;

@EXPORT =
  qw (hexa2bin bin2hexa bin2unsigned decode_message_header decode_tlv_parameters
  encode_tlv encode_tlv_parameters pop_message revert revert_tlv
  decode_record encode_record unsigned2bin);

@ISA = qw(Exporter);

######################
# Section: Utilities #
######################

# These routines are services routine that can be used in most CODEC implementation

my $log = Log::Log4perl::get_logger("CODECs");

# ------------------------------------------------------------------------
# routine: hexa2bin
#
# Converts an hexadecimal string into binary
#
# Parameters:
# $hexa - an hexadecimal string
#
# Returns a binary buffer.
# ------------------------------------------------------------------------
sub hexa2bin {
	return pack( "H*", shift() );
}

# ------------------------------------------------------------------------
# routine: bin2hexa
#
# Converts a binary buffer into hexadecimal string
#
# Parameters:
# $bin - a binary buffer.
#
# Returns: an hexadecimal string
# ------------------------------------------------------------------------
sub bin2hexa {
	return unpack( "H*", shift() );
}

# ------------------------------------------------------------------------
# routine: pop_message
#
# extract a message from the head of a buffer and truncate the buffer
#
# Parameters:
#    $buffer_ref - a reference to a binary buffer
#    $len - length of the chunk to remove from the head of the message
# ------------------------------------------------------------------------
sub pop_message {
	my ( $buffer_ref, $len ) = @_;

	my $msg = substr( $$buffer_ref, 0, $len );
	$$buffer_ref = substr( $$buffer_ref, $len );
	return $msg;
}

# ------------------------------------------------------------------------
# routine: bin2unsigned
#
# Read an integer value from a big endian binary buffer
#
# Parameters:
# $buffer - binary buffer
# $len - number of bytes of the integer
#
# Returns: an integer
# ------------------------------------------------------------------------
sub bin2unsigned {
	my ( $buffer, $len ) = @_;

	my $int;
	if ( $len == 1 ) {
		$int = unpack( "C", $buffer );
		return $int;
	}
	elsif ( $len == 2 ) {
		$int = unpack( "n", $buffer );
		return $int;
	}
	elsif ( $len == 3 ) {
		$int = unpack( "C", $buffer );
		return $int;
	}
	elsif ( $len == 4 ) {
		$int = unpack( "N", $buffer );
	}
	elsif ( $len == 8 ) {
		my ( $high, $low ) = unpack( "N N", $buffer );
	}
	return $int;
}

# ------------------------------------------------------------------------
# routine: unsigned2bin
#
# Encode an unsigned integer value into a binary buffer.
# 
# Parameters:
# $int - a positive value
# $len - number of bytes of the resulting binary buffer
# ------------------------------------------------------------------------
sub unsigned2bin {
	my ( $int, $len ) = @_;

	my $bin;
	if ( $len == 1 ) {
		return pack( "C", $int );
	}
	elsif ( $len == 2 ) {
		return pack( "n", $int );
	}
	elsif ( $len == 3 ) {
		return pack( "C", $int );
	}
	elsif ( $len == 4 ) {
		return pack( "N", $int );
	}
	elsif ( $len == 8 ) {
		die "unsupported size";
		return 0;

		#my ( $high, $low ) = unpack( "N N", $buffer );
	}
	die "unsupported size";
}

# ------------------------------------------------------------------------
# routine: revert 
#
# Revert a hash table. Keys become values and values become keys.
#
# Parameter:
# %hash - the hash to revert
#
# Returns the reverted hash.
# ------------------------------------------------------------------------
sub revert {
	my %table = @_;

	my %reverted = ();
	foreach my $key ( keys(%table) ) {
		$reverted{ $table{$key} } = $key;
	}
	return %reverted;
}

# ------------------------------------------------------------------------
# routine: revert_tlv
#
# Creates a reverted hash table from a tlv table. A tlb table is a table
# where tags are keys, of record containing a name field.
# ------------------------------------------------------------------------
sub revert_tlv {
	my %table = @_;

	my %reverted = ();
	foreach my $key ( keys(%table) ) {
		my $name = $table{$key}->{'name'};
		$reverted{$name} = $key;
	}
	return %reverted;
}

# ------------------------------------------------------------------------
# routine: decode_message_header
#
# Decode the header of a TLV message
#
# Parameters:
#    $decoded - Structured message
#    $msg_ref - reference to the buffer
#    $tag_length - length of the command tag
#    $len_length - length of the command lenght field
#    $symbols - a reference to a symbol table
# ------------------------------------------------------------------------
sub decode_message_header {
	my ( $decoded, $msg_ref, $tag_length, $len_length, $symbols ) = @_;

	$log->trace("decode_message_header");

	my $tmp = pop_message( $msg_ref, $tag_length );
	my $tag = bin2unsigned( $tmp,    $tag_length );
	$tmp = pop_message( $msg_ref, $len_length );
	my $len = bin2unsigned( $tmp, $len_length );

	$decoded->type(
		exists( $symbols->{$tag} ) ? $symbols->{$tag} : $tag );
	$decoded->length($len );
	$decoded->tag($tag );
}

# ------------------------------------------------------------------------
# routine: decode_message_header_with_protocol
#
# Decode the header of a TLV message
#
# Parameters:
#    $decoded - Message
#    $msg_ref - reference to the buffer
#    $protocol_length - length of the command protocol version
#    $tag_length - length of the command tag
#    $len_length - length of the command lenght field
#    $symbols - a reference to a symbol table
# ------------------------------------------------------------------------
sub decode_message_header_with_protocol {
	my ( $decoded, $msg_ref, $protocol_length, $tag_length, $len_length, $symbols ) = @_;

	$log->trace("decode_message_header_with_protocol");

	my $tmp = pop_message( $msg_ref, $protocol_length );
	my $protocol_version = bin2unsigned( $tmp, $protocol_length );
	$tmp = pop_message( $msg_ref, $tag_length );
	my $tag = bin2unsigned( $tmp, $tag_length );
	$tmp = pop_message( $msg_ref, $len_length );
	my $len = bin2unsigned( $tmp, $len_length );

	$decoded->type(
		exists( $symbols->{$tag} ) ? $symbols->{$tag} : $tag );
	$decoded->length( $len );
	$decoded->tag( $tag );
	$decoded->protocol_version( $protocol_version );
}

# ------------------------------------------------------------------------
# routine: decode_tlv_parameters
#
# Decode the tlv parameters of a TLV message
#
# Parameters:
#    $decoded - Structured message
#    $msg_ref - reference to the buffer
#    $tag_length - length of the command tag
#    $len_length - length of the command lenght field
#    $tlv - reference to tlv parameters descriptors
#    $messages_desc - a message descriptor
# ------------------------------------------------------------------------
sub decode_tlv_parameters {
	my ( $decoded, $msg_ref, $tag_length, $len_length, $tlv, $msgs ) = @_;

	$log->trace("decode_tlv_parameters");

	# Check tag validity
	my $msg_desc;
	my $type;
	if ( $decoded->type() ) {
		$type = $decoded->type();
		if ( exists( $msgs->{$type} ) ) {
			$msg_desc = $msgs->{$type};
		}
		else {
			$decoded->add_error("unknown message type=$type");
		}
	}
	# print "message_descriptor=" . Dumper($msg_desc) . "\n";

	# for all the TLV parameters
	while ( length($$msg_ref) > 0 ) {

		# extract header
		my $header = CODECs::pop_message( $msg_ref, $tag_length );
		my $tag    = bin2unsigned( $header,         $tag_length );

		# extract length
		$header = CODECs::pop_message( $msg_ref, $len_length );
		my $len = bin2unsigned( $header, $tag_length );

		# extract value
		my $body = CODECs::pop_message( $msg_ref, $len );

		# save tag id
		my $tag_name;
		if ( exists( $tlv->{$tag}->{'name'} ) ) {
			$tag_name = $tlv->{$tag}->{'name'};
		}
		else {
			$tag_name = $tag;
			$decoded->add_error("unknown tag=$tag_name");
		}
		$log->trace("decode_tlv_parameters, found tag=$tag_name");
		
		# Check tag validity
		unless ( exists( $msg_desc->{$tag_name} ) ) {
			$decoded->add_error("unexpected tag=$tag_name in $type message");
		}    

		# check length
		if ( exists( $tlv->{$tag}->{'len'} ) ) {
			if ( defined( $tlv->{$tag}->{'len'} ) ) {
				my $expectedLength = $tlv->{$tag}->{'len'};
				if ( $len != $expectedLength ) {
					$decoded->add_error(
						"incorrect length=$len for tag=$tag_name");
				}
			}
		}

		$decoded->{'lengths'}->{$tag_name} = $len;

		# parameters values
		my $type = $tlv->{$tag}->{'type'};
		my $value;
		my $hexa = bin2hexa($body);

		$decoded->{'raw'}->{$tag_name} = $hexa;

		if ( $type eq 'unsigned' ) {
			$value = bin2unsigned( $body, $len );
			$decoded->add_field( $tag_name, $value, 'tlv::unsigned');
		}
		elsif ( $type eq 'binary' ) {
			$decoded->add_field( $tag_name, $hexa, 'tlv::binary');
		}
		elsif ( $type eq 'string' ) {
			$value = unpack( "Z*", $body );
			$decoded->add_field( $tag_name, $value, 'tlv::string');
		}
		elsif ( $type eq 'char' ) {
			$value = unpack( "a*", $body );
			$decoded->add_field( $tag_name, $value, 'tlv::char');
		}
		else {
			my $cmd = "require CODECs::$type;
        		my \$codec = CODECs::$type->instance();
        	";
			my $codec = eval $cmd;

			if ($codec) {
				my $dec = $codec->decode($body);
				$decoded->add_field( $tag_name, $dec->value(), $type);

				if ( $dec->{'errors'} ) {
					# merge sub-component errors
					$decoded->add_error(
						$type . '::' . $dec->error_description(),
						$dec->errors() );
				}
			}
			else {
				$decoded->add_error("unsupported type=$type for tag=$tag_name $cmd");
			}
		}
	}
	
	# Checks that all mandatory fields have been found
	foreach my $key (keys(%{$msg_desc})) {
		my $fld_desc = $msg_desc->{$key};
		my $min = $fld_desc->{'nb_min'};
		if ($min > 0 && (!defined($decoded->value($key)))) {
			$decoded->add_error("parameter $key not found in $type");
		}
	}
}

# ------------------------------------------------------------------------
# routine: decode_record
#
# Decode a sequence of positionnal fields
#
# Parameters:
#    $msg_ref - reference to the buffer
#    $desc - record descriptor
# ------------------------------------------------------------------------
sub decode_record {
	my ( $msg_ref, $desc ) = @_;

	$log->trace("decode_record");

	my $res = {};
	foreach my $fld ( @{$desc} ) {
		my $len = $fld->{'len'};
		if ( $fld->{'type'} eq 'unsigned' ) {

			# unsigned
			$res->{ $fld->{'name'} } =
			  bin2unsigned( pop_message( $msg_ref, $len ), $len );

		}
		elsif ( $fld->{'type'} eq 'string' ) {

			# string
			unless ( defined($len) ) {
				$len = length($$msg_ref);
			}
			$res->{ $fld->{'name'} } = pop_message( $msg_ref, $len );

		}
		else {
			die "decode_record $fld->{'type'} NYI";
		}
	}
	return $res;
}

# ------------------------------------------------------------------------
# routine: encode_one_tlv_parameter
#
# Parameters:
#    $msg - Structured message
#    $tag_length - length of the command tag
#    $len_length - length of the command lenght field
#    $params_desc - reference to tlv parameters descriptors
#    $reverse - reversed tlv parameters descriptor reference
#    $msgs_desc - message descriptor
#
# Returns: a binary buffers containing the tlv parameters
# ------------------------------------------------------------------------
sub encode_one_tlv_parameter {
    my ( $value, $tag_length, $len_length, $params_desc, $reverse, $msgs_desc ) = @_;

}

# ------------------------------------------------------------------------
# routine: encode_tlv_parameters
#
# Encode the tlv parameters of a TLV message. This method as a structured
# message parameter, it contains the values to encode with one entry for
# each field. It has a parameters descriptor table which determines the
# type and encoding options for each field and a message descriptor which 
# contains the list of acceptable fields.
#
# Parameters:
#    $msg - Structured message
#    $tag_length - length of the command tag
#    $len_length - length of the command lenght field
#    $params_desc - reference to tlv parameters descriptors
#    $reverse - reversed tlv parameters descriptor reference
#    $msgs_desc - message descriptor
#
# Returns: a binary buffers containing the tlv parameters
# ------------------------------------------------------------------------
sub encode_tlv_parameters {
	my ( $msg, $tag_length, $len_length, $params_desc, $reverse, $msgs_desc ) = @_;

    my $msg_type = $msg->{'type'};
	$log->trace(
		"encode_tlv_parameters ($tag_length, $len_length, " . Dumper($msg) );
		
    my $value = $msg->{'value'};

	my $res = "";
	foreach my $fld ( keys( %{$value} ) ) {

        my $descriptor = $msgs_desc->{$msg_type}->{$fld};
        my $nb_min = $descriptor->{'nb_min'};
        my $nb_max = $descriptor->{'nb_max'};
        
#        $log->trace("--------------- $fld");
#        $log->trace(Dumper($descriptor));
#        $log->trace("nb_min = " . $nb_min);
#        $log->trace("nb_max = " . $nb_max);
#        $log->trace("=============== $fld");
		my $tag = $reverse->{$fld};
		defined($tag) or die "unknown field $fld.";

		my $type = $params_desc->{$tag}->{'type'};
		my $len  = $params_desc->{$tag}->{'len'};

        # $value->{$fld} can be 
        # - a scalar
        # - a list
        # - a record
        # 
        
		if ( $type eq 'unsigned' ) {
			# unsigned
			my $unsigned = unsigned2bin( $value->{$fld}, $len );
			$res .= encode_tlv( $tag, $tag_length, $len_length, $unsigned );
		}
		else {
			# call a specific codec
			my $cmd = "require CODECs::$type;
                      my \$codec = CODECs::$type->instance();";

			my $codec = eval $cmd;
			if ($codec) {
			    my $submsg = new Message (
			       'type' => $type,
			       'value' => $value->{$fld}
			    );
			    my $field = $codec->encode( $submsg );
			    $res .= encode_tlv( $tag, $tag_length, $len_length, $field );
			}
			else {
				die "eval error (codec not found): $@";
			}
		}
	}
	return $res;
}

# ------------------------------------------------------------------------
# routine: encode_record
#
# Encode the positional parameters of a record
#
# Parameters:
#    $msg - Message
#    $desc - record descriptor
#
# Returns: a binary buffers containing the tlv parameters
# ------------------------------------------------------------------------
sub encode_record {
	my ( $value, $desc ) = @_;

	$log->trace( "encode_record (" . Dumper($value) );

	my $bin = "";
	foreach my $fld ( @{$desc} ) {
		my $len = $fld->{'len'};
		exists( $value->{ $fld->{'name'} } )
		  or die "encode record, no value for $fld->{'name'}";
		if ( $fld->{'type'} eq 'unsigned' ) {
			$bin .= unsigned2bin( $value->{ $fld->{'name'} }, $len );
		}
		else {
			die "encode_record $fld->{'type'} NYI";
		}
	}
	return $bin;
}

# ------------------------------------------------------------------------
# routine: encode_tlv
#
# Encode the header of a TLV message
#
# Parameters:
#    $tag - Type identifier
#    $tag_length - length of the tlv tag
#    $len_length - length of the tlv lenght field
#    $value - binary value
#
# Returns: a binary TLV parameter
# ------------------------------------------------------------------------
sub encode_tlv {
	my ( $tag, $tag_length, $len_length, $value ) = @_;

	my $res = "";
	my $len = length($value);

    $log->trace("encode_tlv ($tag, $len, ...)");
	my $btag = unsigned2bin( $tag, $tag_length );
	my $blen = unsigned2bin( $len, $len_length );

	return $btag . $blen . $value;
}

# ------------------------------------------------------------------------
# routine: encode_tlv_with_protocol
#
# Encode the header of a TLV message
#
# Parameters:
#    $tag - Type identifier
#    $tag_length - length of the tlv tag
#    $len_length - length of the tlv lenght field
#    $value - binary value
#
# Returns: a binary TLV parameter
# ------------------------------------------------------------------------
sub encode_tlv_with_protocol {
	my ( $protocol_version, $protocol_version_length, $tag, $tag_length, $len_length, $value ) = @_;

	my $res = "";
	my $len = length($value);

	my $bprotocol = unsigned2bin( $protocol_version, $protocol_version_length );
	my $btag = unsigned2bin( $tag, $tag_length );
	my $blen = unsigned2bin( $len, $len_length );

	return $bprotocol . $btag . $blen . $value;
}

1;
