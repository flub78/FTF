# ----------------------------------------------------------------------------
#
# Title:  Class Message
#
# Name:
#
#       package Message
#
# Abstract:
#
#       Messages are generic containers for complex structured data.
#       They contain scalar, lists and records, the list and records can
#       themselves contain other lists and records.
#
#       In Perl it is  a very thin layer on top of the classical
#       data structure (combination of references on hashes and list).
#
# (Start code)
#	my $msg = new Message (value => {
#		TABLE_ID => 0x47,
#		OP_LIST => [
#			{MOP => 3, DATE => {MONTH => 1, DAY => 1, YEAR => 2009}},
#			{MOP => 4, DATE => {MONTH => 12, DAY => 25, YEAR => 2009}}
#		]
#	});
# (end)
#
#       Messages are the result of the CODECs decode method and the input
#       parameter of the encode routine. Messages can also contain information
#       on the decoding process, errors number and description, type or codec
#       use for the analysis, etc.
#
#       One of the main method on messages is the value method which returns
#       the scalar value or is an accessor to subcomponent. The value
#       method can have a subcomponent identifiers, which are index for lists
#       and a field name for records. The identifier supports a dotted
#       notation to access sub-components.
#
#       Examples of sub-component identifiers:
#
#		"" or undef - access to scalar values for scalar messages.
#       4 - integer values are used as lists indexes
#       "TR_NUMBER" - field name
#       "DATE.DAY" - compound accessor
#       "OP_LIST.[1].DATE.SECOND" - complex access
#
# The value method can be used to get or change the value of a sub-component.
#
# (Start code)
# # access a value
# my $value = $msg->value('OP_LIST.[1].DATE.MONTH');
#
# # change a value
# $msg->value('OP_LIST.[1].DATE.MONTH', 12);
# (end)
#
# Their is curently no field validity control mechanism, so be cautious. If
# it is a problem I'll add some support to perform field checking.
# ------------------------------------------------------------------------
package Message;

use strict;
use vars qw($VERSION @ISA @EXPORT);

use Exporter;
use Log::Log4perl;
use Data::Dumper;
use ClassWithLogger;

$VERSION = 1;

@ISA = qw(ClassWithLogger);

# ------------------------------------------------------------------------
# method: new
#
# Returns a new initialised object for the class.
# ------------------------------------------------------------------------
sub new {
	my $Class = shift;
	my $Self  = {};

	bless( $Self, $Class );
    $Self->{'Class'} = $Class;
	$Self->_init(@_);

	return $Self;
}

# ------------------------------------------------------------------------
# method: _init (private)
#
# Initialisation of the object. Do not call directly.
# ------------------------------------------------------------------------
sub _init {
	my $Self = shift;

    # Call the parent initialization first
    $Self->ClassWithLogger::_init(@_);

	my %attr = @_;

	# Takes the constructor parameters as object attributs
	foreach my $key ( keys %attr ) {
		$Self->{$key} = $attr{$key};
	}
}

# ------------------------------------------------------------------------
# method: value
#
# This method returns the value of the message or any of its subcomponent.
# Subcomponents are element for lists, fields for records. When the 
# message is a structured message, combination of various lists and 
# records, it is possible to adress any sub-elements at any level.
# It returns a scalar when the sub-component indicator identifies a scalar
# or a reference to a list when the item is a list, or a reference to a hash
# when the item is a record. It returns undef when the item subcomponent does
# not exist.
#
# The following example explains the syntax supported for sub-components. The 
# message is a record with a component named OP_LIST, which is a list with 
# at least two elements. These elements are date records which contain
# at least a filed named MONTH.
#
# (Start code)
# # access a value
# my $value = $msg->value('OP_LIST.[1].DATE.MONTH');
#
# # change a value
# $msg->value('OP_LIST.[1].DATE.MONTH', 12);
# (end)
#
# Parameters:
# id - sub-element identifier
# new - new value
# ------------------------------------------------------------------------
sub value {
	my ( $Self, $id, $new ) = @_;

    my $lnew = defined($new) ? $new : "undef";
    my $lid = defined($id) ? $id  : "undef";
	$Self->trace("value($lid, $lnew)");

	my $val       = $Self->{'value'};	
	unless (ref($val) && defined($id)) {
	    # value is a scalar
        return $val;
	}
	 
	my @selectors = split( /\./, $id );
	my $iter      = scalar(@selectors);

	foreach my $sel (@selectors) {
		$iter--;
		if ( ref($val) eq 'ARRAY' ) {

			# remove brackets
			if ( $sel =~ /\[(.*)\]/ ) {
				$sel = $1;
			}
			if ( defined($new) && !$iter ) {
				@{$val}[$sel] = $new;
			}
			$val = @{$val}[$sel];

		}
		elsif ( ref($val) eq 'HASH' ) {
			if ( defined($new) && !$iter ) {
				$val->{$sel} = $new;
			}
			$val = $val->{$sel};
		}
		else {
			if ( defined($new) && !$iter ) {
				$val->{$sel} = $new;
			}
			else {
				return undef;
			}
		}
	}
	return $val;
}

# ------------------------------------------------------------------------
# method: push
#
# Add a new element to a message list sub-component.
#
# Parameters:
# id - sub-element identifier (must be an array)
# elt - element to add
# ------------------------------------------------------------------------
sub push {
	my ( $Self, $id, $elt ) = @_;

	$Self->trace("push($id)");
	my $val = $Self->value($id);

	if ( ref($val) eq 'ARRAY' ) {
		push( @{$val}, $elt );
	}
	else {
		die "push($id) is not an array";
	}
}

# ------------------------------------------------------------------------
# method: number_of
#
# Cardinality a message list sub-component. Returns the number of elements
# in lists, the number of fields for records, etc.
#
# Parameters:
# id - sub-element identifier
# ------------------------------------------------------------------------
sub number_of {
	my ( $Self, $id ) = @_;

	my $val = $Self->value($id);

	return 0 unless ($val);
	if ( ref($val) eq 'ARRAY' ) {
		return scalar( @{$val} );
	} elsif (ref($val) eq 'HASH' ) {
	    return scalar (keys(%{$val}));
	}
	else {
		return 1;
	}
}

# ------------------------------------------------------------------------
# method: field_list
#
# Returns the list of field of a message or a sub-element. The specified level
# musth be a record.
#
# Parameters:
# id - sub-element identifier (must be a record)
# ------------------------------------------------------------------------
sub field_list {
	my ( $Self, $id, $elt ) = @_;

	$Self->trace("field_list($id)");
	my $val = $Self->value($id);

	if ( ref($val) eq 'HASH' ) {
		return keys( %{$val} );
	}
	else {
		die "field_list($id) is not a record";
	}
}

# ------------------------------------------------------------------------
# method: add_field
#
# Add a new field and its value. If the field does not exist it is created.
# if it already exists and is a scalar, it is replaced by a list containg
# the two values. If it is already a list, the new value is added to the list
#
# Parameters:
#    $field - field name
#    $value - value for the field
# ------------------------------------------------------------------------
sub add_field {
	my ( $Self, $field, $value, $type ) = @_;

	if ( exists( $Self->{'value'}->{$field} ) ) {
		my $val = $Self->value($field);
		if ( ref($val) eq 'ARRAY' ) {
			CORE::push( @{$val}, $value );
		}
		else {

			# create a reference to a two elements list
			my $nl = [ $val, $value ];
			$Self->value( $field, $nl );
		}
	}
	else {
		$Self->{'value'}->{$field} = $value;
	}
	$Self->{'value'}->{$field} = $value;
	$Self->{'types'}->{$field} = $type;
}

# ------------------------------------------------------------------------
# method: type
#
# This accessor can be use to set or get the value of the type.
#
# Parameters:
# value - when void the method get the value. when defined, set the value.
# ------------------------------------------------------------------------
sub type {
	my $Self = shift;

	$Self->{'type'} = shift if @_;
	return $Self->{'type'};
}

# ------------------------------------------------------------------------
# method: length
#
# This accessor can be use to set or get the value of the length.
#
# Parameters:
# value - when void the method get the value. when defined, set the value.
# ------------------------------------------------------------------------
sub length {
	my $Self = shift;

	$Self->{'length'} = shift if @_;
	return $Self->{'length'};
}

# ------------------------------------------------------------------------
# method: tag
#
# This accessor can be use to set or get the value of the tag.
#
# Parameters:
# value - when void the method get the value. when defined, set the value.
# ------------------------------------------------------------------------
sub tag {
	my $Self = shift;

	$Self->{'tag'} = shift if @_;
	return $Self->{'tag'};
}

# ------------------------------------------------------------------------
# method: kind
#
# Returns the kind of a message or a message subcomponent. It can be
# SCALAR | ARRAY | RECORD.
#
# Parameters:
# id - sub-element identifier
# ------------------------------------------------------------------------
sub kind {
	my ( $Self, $id ) = @_;

	my $ref = ref( $Self->value($id) );
	if ($ref) {
		return 'RECORD' if ($ref eq 'HASH');
		return $ref;
	}
	else {
		return 'SCALAR';
	}
}

# ------------------------------------------------------------------------
# method: errors
#
# Read or set the number of parsing errors. 
#
# Parameters:
# value - when void the method get the value. when defined, set the value.
# ------------------------------------------------------------------------
sub errors {
	my $Self = shift;

	$Self->{'errors'} = shift if @_;
	return $Self->{'errors'};
}

# ------------------------------------------------------------------------
# method: error_description
#
# This is the accessor to the error description. The error description is big
# string containing one or several lines. During parsing of complex types
# errors are propagated to the nesting component. It means that if
# you get an error while parsing the field of a record, the error
# description will be concatenated in the parent error descriptor. The
# total error number of a message must be equal to the number of 
# errors of the sub-components.
#
# Parameters:
# value - when void the method get the value. when defined, set the value.
# ------------------------------------------------------------------------
sub error_description {
	my $Self = shift;

	$Self->{'error_description'} = shift if @_;
	return $Self->{'error_description'};
}

# ------------------------------------------------------------------------
# method: add_error
#
# Add a new error to the message
#
# Parameters:
# description - string to describe the error
# nb - number or errors to add (default = 1). Can be more than one to merge errors from sub components
# ------------------------------------------------------------------------
sub add_error {
	my ( $Self, $description, $nb ) = @_;

	$nb = 1 unless ($nb);
	$Self->{'errors'} += $nb;
	$Self->{'error_description'} .= $description . "\n";
}

# ------------------------------------------------------------------------
# method: size
#
# This accessor can be use to set or get the value of the error.
#
# Return: the size of the object in byte
# ------------------------------------------------------------------------
sub size {
	my $Self = shift;

	$Self->{'size'} = shift if @_;
	return $Self->{'size'};
}

# ------------------------------------------------------------------------
# method: dump
#
# Returns an ASCII image of the message. When details are required all 
# information about the message is displayed.
#
# When no details are required the dump method returns a string that can be
# cut and past to encode again the message.
#
# Parameters:
#    $detail - boolean
# ------------------------------------------------------------------------
sub dump {
	my ( $Self, $detail ) = @_;

	if ($detail) {
		# full format
		return Dumper($Self);
	}

	# short format
	my $res = "Message (\n";
	$res .= "\ttype => \'" . $Self->type . "\',\n";

    my $ref = ref($Self->{'value'});
    if ($ref) {
	   my $dump = Dumper( $Self->{'value'} );
	   my @splitted = split( /\n/, $dump );
	   $splitted[0] = "\tvalue => {";
	   $splitted[ @splitted - 1 ] = "\t}";
	   $res .= join( "\n", @splitted);
    } else {
       $res .= "\tvalue => " . $Self->{'value'}; 
    }
	my $errors = $Self->errors();
	if ($errors) {
		$res .= ",\n\terrors => $errors,\n" . 
		        "\terror_description => \"" .
		        $Self->error_description() . "\"";
	}    
	$res .= "\n)";
	return $res;
}

1;
