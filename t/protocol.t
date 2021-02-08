# ------------------------------------------------------------------------
# Title:  Protocol Unit Test
#
# File - protocol.t
# Version - 1.0
#
# Abstract:
#
#    This is a unitary test for the protocol encoder layer.
# ------------------------------------------------------------------------
package Encoder;

use strict;
use lib "$ENV{'FTF'}/lib";
use vars qw($VERSION @ISA @EXPORT);
use Exporter;
use Test;
use bigint;

$VERSION = 1;
@ISA     = qw(Test);

# Test::More is only used to test Perl modules.
use Test::More qw( no_plan );
use Data::Dumper;
use ExecutionContext;
use ScriptConfiguration;

use Protocol::Utilities qw (bin2hexa hexa2bin at_offset);
use Protocol::Type;
use Protocol::HexaString;
use Protocol::String;
use Protocol::Integer;
use Protocol::List;
use Protocol::Record;
use Protocol::TLV;
use Protocol::TLV_List;
use Protocol::TLV_Alternative;
use Protocol::TLV_Message;
use Protocol::Enumerate;

# ------------------------------------------------------------------------
# read CLI and configuration file
my $config = new ScriptConfiguration( 'scheme' => TEST );

my $configFile = ExecutionContext::configFile();
$config = new ScriptConfiguration(
	'header' => "",
	'footer' => "",
	'scheme' => TEST,
);

# ------------------------------------------------------------------------
# method: testUtilities
#
# Test Parser::Protocol::Utilities
# ------------------------------------------------------------------------
sub testUtilities {
	my $Self = shift;

	# Basic binary encoding and decoding
	# ----------------------------------
	my $str = "Hello";
	is( bin2hexa($str), "48656c6c6f", "Basic hexadecimal dump" );

	$str .= " World";
	is( bin2hexa($str), "48656c6c6f20576f726c64", "Hexadecimal dump" );

	is( bin2hexa(""), "", "Hexadecimal dump of an empty string" );
	is( hexa2bin(""), "", "Binary encoding of an empty string" );

	my $bin = hexa2bin("01234567");
	$bin .= hexa2bin("deadbeef");

	is( bin2hexa($bin), "01234567deadbeef", "basic binary encoding" );

	is( at_offset( $bin, 0 ), 1,    "atOffset 0" );
	is( at_offset( $bin, 1 ), 0x23, "atOffset 1" );
	is( at_offset( $bin, 2 ), 0x45, "atOffset 2" );
	is( at_offset( $bin, 3 ), 0x67, "atOffset 3" );
	is( at_offset( $bin, 4 ), 0xDE, "atOffset 4" );
	is( at_offset( $bin, 5 ), 0xAD, "atOffset 5" );
	is( at_offset( $bin, 6 ), 0xBE, "atOffset 6" );
	is( at_offset( $bin, 7 ), 0xEF, "atOffset 7" );
	eval { is( at_offset( $bin, 8 ), undef, "atOffset 8" ); };

	if ($@) {
		ok( 1, "out of bound offsets correctly reported:\n$@" );
	}

	# Write the binary buffer into a file
	my $filename = "file.tst";
	open( FD, "> $filename" ) or die("cannot open file $filename : $!");
	print FD $bin;
	close FD;
}

# ------------------------------------------------------------------------
# method: testHexaString
#
# Test HexaString encoding
# ------------------------------------------------------------------------
sub testHexaString {
	my $Self = shift;

	my $hexType = TypeFromName('binary');

	my $buffer = $hexType->encode("0123456789ABCDEF");
	my $buffer2 = Encode( 'binary', "0123456789ABCDEF" );
	is( $buffer, $buffer2, "Same encoding by name or reference" );

	# attempt to redeclare the same type
	eval {
		$hexType = new Protocol::HexaString( name => 'binary' );
		ok( 0, "duplicated declaration not reported" );
	};
	if ($@) {
		ok( 1, "error reported for duplicated declaration" );
	}

	my $msg = $hexType->decode($buffer);
	is( $msg->value(), "0123456789abcdef", "HexaString value" );

	my $msg2 = Decode( 'binary', $buffer );
	is( $msg2->value(), "0123456789abcdef", "HexaString value by name" );
	ok( !$msg->errors(), "HexaString error (no error)" );

	is( $msg->type(), "binary", "HexaString type" );

	eval { $buffer = $hexType->encode("012"); };
	$buffer = $hexType->encode("0123");
	$msg    = $hexType->decode($buffer);
	is( $msg->value(), "0123", "HexaString value from decodeMsg" );

	my $value = $hexType->value($buffer);
	is( $value,       "0123", "HexaString value from decode" );
	is( $msg->size(), 2,      "HexaString message size" );

	# fix size hexa string
	declare Protocol::HexaString( name => 'key16', size => 16 );
	my $buf = Encode( 'key16', "0123456789ABCDEF0123456789ABCDEF" );
	$value = Decode( 'key16', $buf )->value();
	is(
		$value,
		'0123456789abcdef0123456789abcdef',
		'encode/decode fix size hexa string'
	);

	# underflow
	eval {
		my $buf = Encode( 'key16', "01234567" );
		ok( undef, "hexastring underflow not reported" );
	};
	if ($@) {
		ok( 1, "hexastring underflow correctly reported:\n$@" );
	}

	# overflow
	eval {
		my $buf =
		  Encode( 'key16', "012345670123456701234567012345670123456701234567" );
		ok( undef, "hexastring overflow not reported" );
	};
	if ($@) {
		ok( 1, "hexastring overflow correctly reported:\n$@" );
	}
}

# ------------------------------------------------------------------------
# method: testString
#
# Test String encoding
# ------------------------------------------------------------------------
sub testString {
	my $Self = shift;

	my $str = TypeFromName('string');

	if (1) {
		my $str8 = new Protocol::String( name => 'string8', size => 8 );
		my $buffer = $str8->encode("01234567");
	}
	else {
		declare Protocol::String( name => 'string8', size => 8 );
		my $buffer = Encode( "string8", "01234567" );
	}

	my $buffer = Encode( 'string', "0123456789ABCDEF" );
	is( $buffer, "0123456789ABCDEF", "String basic encoding" );
	my $value = Decode( 'string', $buffer )->value;
	is( $value, "0123456789ABCDEF", "String basic decoding" );

	# underflow
	eval {
		my $buf = Encode( 'string8', "0123456" );
		ok( undef, "string underflow not reported" );
	};
	if ($@) {
		ok( 1, "string underflow correctly reported:\n$@" );
	}

	# overflow
	eval {
		my $buf = Encode( 'string8', "012345678" );
		ok( undef, "string overflow not reported" );
	};
	if ($@) {
		ok( 1, "string overflow correctly reported:\n$@" );
	}

	# limit size
	my $str0 = new Protocol::String( name => 'string0', size => 0 );
	my $buffer = $str0->encode("");
	is( $buffer, "", "empty sting encoding" );
	# overflow
    eval {
        my $buf = Encode( 'string0', "0" );
        ok( undef, "string overflow not reported for null strings" );
    };
    if ($@) {
        ok( 1, "null string overflow correctly reported:\n$@" );
    }
	

}

# ------------------------------------------------------------------------
# method: testIntValue
#
# Test one value for unsigned integer
#
# Parameters:
#   $size - size of the integer to test
#   $unsigned - boolean value
#   $endian - 'little_endian' or 'big_endian'
#   $value - value to test
#   $result - expected hexadecimal image
# ------------------------------------------------------------------------
sub testIntValue {
	my ( $Self, $size, $unsigned, $endian, $value, $result ) = @_;

	my $intType = new Protocol::Integer(
		size      => $size,
		unsigned  => $unsigned,
		endianess => $endian
	);

	my $buf;
	$buf = $intType->encode($value);

	my $decoded = $intType->value($buf);
	is( $decoded, $value,
		"same value after decoding, decoded:$decoded == encoded:$value" );
	is( bin2hexa($buf), $result, "expected result $result" );
	
	my $byte = hexa2bin("A5");
	my $bin = $byte x $size;
	$decoded = $intType->value($bin);
	
	$bin .= $byte;
	$decoded = $intType->value($bin);
	my $msg = $intType->decode($bin);
	is ($msg->errors(), 0, "no decoding errors");
    
    $bin = substr($bin, 2);
    $msg = $intType->decode($bin);
    $decoded = $intType->value($bin);
#    is ($decoded, undef, "value undef on underflow, integer size=$size, endianness=$endian");
    is ($msg->errors(), 1, "underflow detected on integer $size decode");
}

# ------------------------------------------------------------------------
# method: testIntegerType
#
# Test integer encoding
#
# Parameters:
#   $size - size of the integer to test
#   $sign - 'signed' or 'unsigned'
#   $endian - 'little_endian' or 'big_endian'
# ------------------------------------------------------------------------
sub testIntegerType {
	my ( $Self, $size, $sign, $endian ) = @_;

	my $intType = new Protocol::Integer(
		size      => $size,
		unsigned  => $sign,
		endianess => $endian
	);

	is( $intType->size(),      $size,    "Integer size: $size" );
	is( $intType->endianess(), $endian,  "Integer endianess: $endian" );
	is( $intType->unsigned(),  $sign,    "Integer sign: $sign" );
	is( $intType->structure(), 'scalar', "Integer structure" );
}

# ------------------------------------------------------------------------
# method: testAllIntegers
#
# Test integer encoding
# ------------------------------------------------------------------------
sub testAllIntegers {
	my $Self = shift;

	my $support64 = 1;

	#    my $BYTES = $Protocol::Type::BYTES;
	$Self->info("Protocol Encoder Integer Encoding Test");

	my $defaultInt = new Protocol::Integer;

	# print "\n", "default Integer = ", Dumper($defaultInt), "\n";
	is( $defaultInt->size(), 4, "Default integer size" );
	ok( !$defaultInt->signed(),  "Default integer signed" );
	ok( $defaultInt->unsigned(), "Default integer unsigned" );
	is( $defaultInt->endianess(), 'big_endian', "Default integer endianess" );
	is( $defaultInt->endianess('little_endian'),
		'little_endian', "endianess little" );
	is( $defaultInt->endianess('big_endian'), 'big_endian', "endianess big" );
	eval {
		is( $defaultInt->endianess('bad_endian'),
			'big_endian', "wrong endianess" );
	};

	if ($@) {
		ok( 1, "wrong endianess correctly reported:\n$@" );
	}
	is( $defaultInt->size(1), 1, "set integer size 1" );
	is( $defaultInt->size(2), 2, "set integer size 2" );
	is( $defaultInt->size(3), 3, "set integer size 3" );
	is( $defaultInt->size(4), 4, "set integer size 4" );
	is( $defaultInt->size(8), 8, "set integer size 8" );
	eval { is( $defaultInt->size(7), 7, "set integer size 7" ); };
	if ($@) {
		ok( 1, "wrong integer size correctly reported:\n$@" );
	}

	# Integer types
    $Self->testIntegerType( 0, 'signed',   'little_endian' );
    $Self->testIntegerType( 0, 'unsigned',   'big_endian' );
	$Self->testIntegerType( 1, 'signed',   'little_endian' );
	$Self->testIntegerType( 2, 'unsigned', 'little_endian' );
	$Self->testIntegerType( 3, 'signed',   'big_endian' );
	$Self->testIntegerType( 4, 'unsigned', 'big_endian' );
	$Self->testIntegerType( 8, 'signed',   'little_endian' );

	# Unsigned values
	# ---------------

	# Bytes
	$Self->testIntValue( 1, UNSIGNED, 'big_endian', 0, "00" );

	#    $Self->testIntValue( 1, SIGNED, 'big_endian', 0,   "00" );
	$Self->testIntValue( 1, UNSIGNED, 'big_endian', 1,   "01" );
	$Self->testIntValue( 1, UNSIGNED, 'big_endian', 127, "7f" );
	$Self->testIntValue( 1, UNSIGNED, 'big_endian', 255, "ff" );

	eval { $Self->testIntValue( 1, UNSIGNED, 'big_endian', 256, "100" ); };
	if ($@) {
		ok( 1, "out of bound correctly reported:\n$@" );
	}

	# double bytes
	$Self->testIntValue( 2, UNSIGNED, 'big_endian', 0,      "0000" );
	$Self->testIntValue( 2, UNSIGNED, 'big_endian', 0x0001, "0001" );
	$Self->testIntValue( 2, UNSIGNED, 'big_endian', 0x0170, "0170" );
	$Self->testIntValue( 2, UNSIGNED, 'big_endian', 0xFFFF, "ffff" );

	$Self->testIntValue( 2, UNSIGNED, 'little_endian', 0,      "0000" );
	$Self->testIntValue( 2, UNSIGNED, 'little_endian', 0x0170, "7001" );
	$Self->testIntValue( 2, UNSIGNED, 'little_endian', 0xFFFF, "ffff" );
	$Self->testIntValue( 2, UNSIGNED, 'little_endian', 0x0001, "0100" );
	eval {
		$Self->testIntValue( 1, UNSIGNED, 'big_endian', 0xFFFF + 1, "10000" );
	};
	if ($@) {
		ok( 1, "out of bound correctly reported:\n$@" );
	}

	# 24 bits
	$Self->testIntValue( 3, UNSIGNED, 'big_endian', 0,        "000000" );
	$Self->testIntValue( 3, UNSIGNED, 'big_endian', 0x000001, "000001" );
	$Self->testIntValue( 3, UNSIGNED, 'big_endian', 0x012345, "012345" );
	$Self->testIntValue( 3, UNSIGNED, 'big_endian', 0x89ABCD, "89abcd" );
	$Self->testIntValue( 3, UNSIGNED, 'big_endian', 0xFFFFFF, "ffffff" );

	$Self->testIntValue( 3, UNSIGNED, 'little_endian', 0,        "000000" );
	$Self->testIntValue( 3, UNSIGNED, 'little_endian', 0x012345, "452301" );
	$Self->testIntValue( 3, UNSIGNED, 'little_endian', 0x89ABCD, "cdab89" );
	$Self->testIntValue( 3, UNSIGNED, 'little_endian', 0xFFFFFF, "ffffff" );
	eval {
		$Self->testIntValue( 1, UNSIGNED, 'big_endian', 0xFFFFFF + 1,
			"1000000" );
	};

	if ($@) {
		ok( 1, "out of bound correctly reported:\n$@" );
	}

	# 32 bits
	$Self->testIntValue( 4, UNSIGNED, 'big_endian', 0,          "00000000" );
	$Self->testIntValue( 4, UNSIGNED, 'big_endian', 0x0001,     "00000001" );
	$Self->testIntValue( 4, UNSIGNED, 'big_endian', 0x01234567, "01234567" );
	$Self->testIntValue( 4, UNSIGNED, 'big_endian', 0x89ABCDEF, "89abcdef" );
	$Self->testIntValue( 4, UNSIGNED, 'big_endian', 0xFFFFFFFF, "ffffffff" );

	$Self->testIntValue( 4, UNSIGNED, 'little_endian', 0,          "00000000" );
	$Self->testIntValue( 4, UNSIGNED, 'little_endian', 0x01234567, "67452301" );
	$Self->testIntValue( 4, UNSIGNED, 'little_endian', 0x89ABCDEF, "efcdab89" );
	$Self->testIntValue( 4, UNSIGNED, 'little_endian', 0xFFFFFFFF, "ffffffff" );
	eval {
		$Self->testIntValue( 1, UNSIGNED, 'big_endian', 0xFFFFFFFF + 1,
			"100000000" );
	};

	if ($@) {
		ok( 1, "out of bound correctly reported:\n$@" );
	}

	if ($support64) {

		# 64 bits
		$Self->testIntValue( 8, UNSIGNED, 'big_endian', 0, "0000000000000000" );
		$Self->testIntValue( 8, UNSIGNED, 'big_endian', 1, "0000000000000001" );
		$Self->testIntValue( 8, UNSIGNED, 'big_endian', 0x0123456789ABCDEF,
			"0123456789abcdef" );
		$Self->testIntValue( 8, UNSIGNED, 'big_endian', 0xFFFFFFFFFFFFFFFF,
			"ffffffffffffffff" );

		$Self->testIntValue( 8, UNSIGNED, 'little_endian', 0,
			"0000000000000000" );
		$Self->testIntValue( 8, UNSIGNED, 'little_endian', 1,
			"0100000000000000" );
		$Self->testIntValue( 8, UNSIGNED, 'little_endian', 0x0123456789ABCDEF,
			"efcdab8967452301" );
		$Self->testIntValue( 8, UNSIGNED, 'little_endian', 0xFFFFFFFFFFFFFFFF,
			"ffffffffffffffff" );
	}
}

# ------------------------------------------------------------------------
# method: testLists
#
# Test list encoding
# ------------------------------------------------------------------------
sub basicList {
	my $Self = shift;

	declare Protocol::List(
		name              => 'int_3_list',
		numberOfElements  => 3,
		'elementTypeName' => 'unsigned16'
	);
	my $buffer = Encode( 'int_3_list', [ 1, 2, 3 ] );

	my $intList3 = TypeFromName('int_3_list');

	ok( $intList3, "basic list creation" );
	is( $intList3->numberOfElements(), 3, "size of a fixe size list" );
	is( $intList3->structure(), 'list', "structure of a fixe size list" );

	# list too small
	eval { $buffer = $intList3->encode( [ 1, 2 ] ); };
	if ($@) {
		ok( 1, "wrong size correctly reported:\n$@" );
	}
	else {
		ok( 0, "wrong size not reported" );
	}

	# list too large
	eval { $buffer = $intList3->encode( [ 1, 2, 3, 4 ] ); };
	if ($@) {
		ok( 1, "wrong size correctly reported:\n$@" );
	}
	else {
		ok( 0, "wrong size not reported" );
	}

	# correct size
	$buffer = $intList3->encode( [ 1, 2, 3 ] );
	is( bin2hexa($buffer), "000100020003",
		"list encoding is the catenation of elements" );

	my $msg = $intList3->decode($buffer);
	is( $msg->value(0), 1, "decoded int list, first elt" );
	is( $msg->value(1), 2, "decoded int list, second elt" );
	is( $msg->value(2), 3, "decoded int list, third elt" );
	is( $msg->errors(), 0, "decoded int list, error number" );

	declare Protocol::List(
		name              => 'list_with_nb',
		numberTypeName    => 'byte',
		'elementTypeName' => 'unsigned16'
	);
	$buffer = Encode( 'list_with_nb', [ 0xDEAD, 0xBEEF ] );
	is( bin2hexa($buffer), lc("02DEADBEEF"), "list with number of elements" );

	$msg = Decode( 'list_with_nb', $buffer );
	is( $msg->value("0"), 0xDEAD, "first value of a list with number" );
	is( $msg->value("1"), 0xBEEF, "second value of a list with number" );

	# missing value
	$buffer = hexa2bin("03DEADBEEF");
	$msg = Decode( 'list_with_nb', $buffer );
	is( $msg->errors(), 1, "missing element detected" );

	declare Protocol::List(
		name              => 'bounded_list_with_nb',
		numberTypeName    => 'byte',
		numberOfElements  => 2,
		'elementTypeName' => 'unsigned16'
	);
	$msg = Decode( 'bounded_list_with_nb', $buffer );
	is( $msg->errors(), 1,
		"missing element detected in bounded list with number" );
}

# ------------------------------------------------------------------------
# method: testLists
#
# Test list encoding
# ------------------------------------------------------------------------
sub unboundedList {
	my $Self = shift;
	my $buffer;

	declare Protocol::List(
		name              => 'int_list',
		'elementTypeName' => 'unsigned16'
	);

	my $intList = TypeFromName('int_list');
	is( $intList->numberOfElements(), undef, "size of an unbounded list" );
	is( $intList->structure(), 'list', "structure of an unbounded list" );

	# correct size
	$buffer = Encode( 'int_list', [ 1, 2, 3 ] );
	is( bin2hexa($buffer), "000100020003",
		"list encoding is the catenation of elements" );

	my $msg = $intList->decode($buffer);
	is( $msg->value(0), 1, "decoded unbounded list, first elt" );
	is( $msg->value(1), 2, "decoded unbounded list, second elt" );
	is( $msg->value(2), 3, "decoded unbounded list, third elt" );
	is( $msg->errors(), 0, "decoded unbounded list, error number" );
}

# ------------------------------------------------------------------------
# method: testRecords
#
# Test record encoding
# ------------------------------------------------------------------------
sub testRecords {
	my $Self = shift;

	declare Protocol::Record(
		name              => 'date',
		field_descriptors => [
			{ name => 'day',   type => 'byte' },
			{ name => 'month', type => 'byte' },
			{ name => 'year',  type => 'unsigned16' }
		]
	);

	my $dateType = TypeFromName("date");
	is( $dateType->numberOfFields(), 3, "record numberOfFields" );
	is(
		join( ", ", $dateType->fields() ),
		"day, month, year",
		"record field list"
	);

	eval { my $bin = Encode( 'date', 14, 7, 1789 ); };
	if ($@) {
		ok( 1, "Record encode, wrong value type correctly reported:\n$@" );
	}
	else {
		ok( 0, "Record encode, wrong value type not reported" );
	}

	my $bin = Encode( 'date', { day => 14, month => 7, year => 1789 } );
	is( bin2hexa($bin), "0e0706fd", "date encoding" );

	# too much fields
	eval {
		$bin = Encode(
			'date',
			{
				day    => 7,
				month  => 14,
				year   => 1789,
				minute => 47,
				hour   => 12,
				second => 59
			}
		);
	};
	if ($@) {
		ok( 1, "Record encode, too much fields correctly reported:\n$@" );
	}
	else {
		ok( 0, "Record encode, too much fields not reported" );
	}

	# missing fields
	eval { $bin = Encode( 'date', { day => 7, month => 14 } ); };
	if ($@) {
		ok( 1, "Record encode, missing field correctly reported:\n$@" );
	}
	else {
		ok( 0, "Record encode, missing field not reported" );
	}

	# ------------------------------------------------------------------------
	# decoding

	$bin = hexa2bin("0e0706fd");
	my $msg = Decode( 'date', $bin );

	is( $msg->value("day"),   14,   "record field day" );
	is( $msg->value("month"), 7,    "record field month" );
	is( $msg->value("year"),  1789, "record field year" );

	is( $msg->kind(),      'RECORD', "record kind" );
	is( $msg->type(),      'date',   "record type" );
	is( $msg->size(),      4,        "record size" );
	is( $msg->number_of(), 3,        "record number of fields" );
	is( $msg->errors(),    0,        "record errors number" );

	# error cases
	$bin = hexa2bin("0e0706");
	$msg = Decode( 'date', $bin );
	ok( $msg->errors() == 1, "record decoding errors detected" );

}

# ------------------------------------------------------------------------
# method: testRecordValues
#
# Test record field values, default field values, conditional fields
# ------------------------------------------------------------------------
sub testRecordValues {
	my $Self = shift;

	# Record with predefined values
	declare Protocol::Record(
		name              => 'currentDate',
		field_descriptors => [
			{ name => 'day',   type => 'byte' },
			{ name => 'month', type => 'byte' },
			{ name => 'year',  type => 'unsigned16', value => 2009 }
		]
	);

	# type with a default value
	declare Protocol::Record(
		name              => 'currentDateDefault',
		field_descriptors => [
			{ name => 'day',   type => 'byte' },
			{ name => 'month', type => 'byte' },
			{ name => 'year',  type => 'unsigned16', default => 2009 }
		]
	);

	# encoding without supplying a value for default
	my $bin = Encode( 'currentDate', { day => 29, month => 2 } );
	is( bin2hexa($bin), lc("1d0207d9"), "Record with value binary" );
	$bin = Encode( 'currentDateDefault', { day => 29, month => 2 } );
	is( bin2hexa($bin), lc("1d0207d9"), "Record with default value binary" );
	is( Decode( 'currentDate', $bin )->value('year'),
		2009, "Record constant values" );

	# When you provide a value
	eval {
		$bin =
		  Encode( 'currentDate', { day => 29, month => 2, year => '2007' } );
	};
	if ($@) {
		ok( 1,
			"Record encode, incorrect value overwriting correctly reported:\n$@"
		);
	}
	else {
		ok( 0, "Record encode, incorrect value overwriting not reported" );
	}

  # the following one is legal, the provided value is the same than for the type
	$bin = Encode( 'currentDate', { day => 29, month => 2, year => '2009' } );
	is( bin2hexa($bin), lc("1d0207d9"),
		"Record with value supplied with type and value binary" );

	# this one two is legal, default can be overwritten
	$bin =
	  Encode( 'currentDateDefault', { day => 29, month => 2, year => '2007' } );
	is( bin2hexa($bin), lc("1d0207d7"), "Record default overwriting" );

	# attempt to overwrite a value
	eval {
		$bin =
		  Encode( 'currentDate', { day => 29, month => 2, 'year' => 2007 } );
	};
	if ($@) {
		ok( 1, "Record encode, incorrect value correctly reported:\n$@" );
	}
	else {
		ok( 0, "Record encode, incorrect value not reported" );
	}

	# decoding a buffer that is wrong regarding default value
	$bin = hexa2bin("1d0207d7");
	my $msg;
	eval { $msg = Decode( 'currentDate', $bin ); };
	if ($@) {
		ok( 1,
			"Record encode, decoded incorrect value correctly detected:\n$@" );
	}
	else {
		ok( 0, "Record encode, decoded incorrect value not reported" );
	}

}

# ------------------------------------------------------------------------
# method: testRecordConditional
#
# Test record field values, default field values, conditional fields
# ------------------------------------------------------------------------
sub testRecordConditional {
	my $Self = shift;

	# Record with conditional values
	declare Protocol::Record(
		name              => 'citizen',
		field_descriptors => [
			{ name => 'name', type => 'string8' },
			{ name => 'age',  type => 'byte' },
			{
				name      => 'driver_id',
				type      => 'unsigned16',
				condition => "\$value->{'age'} > 18"
			},
			{ name => 'zip', type => 'unsigned32' }
		]
	);

	my ( $bin, $msg );

	# encoding unexpected field because condiiton is false
	eval {
		$bin = Encode(
			'citizen',
			{
				name      => 'Keith   ',
				age       => 17,
				driver_id => 5000,
				zip       => 0x00055555
			}
		);
	};
	if ($@) {
		ok( 1, "Record encode, unexpected conditional field detected:\n$@" );
	}
	else {
		ok( 0, "Record encode, unexpected conditional not reported" );
	}

	# condition is false
	$bin =
	  Encode( 'citizen', { name => 'Keith   ', age => 17, zip => 0x00055555 } );
	is(
		bin2hexa($bin),
		lc("4b656974682020201100055555"),
		"Record conditional binary value false"
	);
	$msg = Decode( 'citizen', $bin );
	is( $msg->value('age'), 17, "regular field of a conditional record" );
	is( $msg->value('driver_id'),
		undef, "non existing field of a conditional record" );

	# condition is true
	$bin = Encode( 'citizen',
		{ name => 'Keith   ', age => 19, driver_id => 5000, zip => 0x00055555 }
	);
	is(
		bin2hexa($bin),
		lc("4b6569746820202013138800055555"),
		"Record conditional binary value true"
	);
	$msg = Decode( 'citizen', $bin );
	is( $msg->value('age'), 19, "regular field of a conditional record (2)" );
	is( $msg->value('driver_id'), 5000, "conditional field of a record" );
}

# ------------------------------------------------------------------------
# method: testCombination
#
# Test combination of record and lists
# ------------------------------------------------------------------------
sub testCombination {
	my $Self = shift;

	# a period is a list of two dates
	declare Protocol::List(
		name              => 'period',
		numberOfElements  => 2,
		'elementTypeName' => 'date'
	);

	my $list = [
		{
			day   => 1,
			month => 1,
			year  => 1970
		},
		{
			day   => 31,
			month => 12,
			year  => 1970
		}
	];
	my $bin = Encode( 'period', $list );
	is( bin2hexa($bin), "010107b21f0c07b2", "period encoding" );
	my $msg = Decode( 'period', $bin );

	# a period is a record of two dates
	declare Protocol::Record(
		name              => 'recordPeriod',
		field_descriptors => [
			{ name => 'startDate', type => 'date' },
			{ name => 'endDate',   type => 'date' }
		]
	);
	my $bin2 = Encode(
		'recordPeriod',
		{
			startDate => { day => 1,  month => 1,  year => 1970 },
			endDate   => { day => 31, month => 12, year => 1970 }
		}
	);
	is( $bin, $bin2, "recordPeriod encoding" );
	$msg = Decode( 'recordPeriod', $bin2 );
}

# ------------------------------------------------------------------------
# method: testTLV
#
# Test TLV encoding
# ------------------------------------------------------------------------
sub testTLV {
	my $Self = shift;

	declare Protocol::TLV(
		name        => 'MOP',
		tag         => 0x01,
		tag_type    => 'byte',
		length_type => 'unsigned32',
		value_type  => 'unsigned16',
	);

	my $tlv = TypeFromName('MOP');
	is( $tlv->tag(),         1,            "TLV tag" );
	is( $tlv->tag_type(),    'byte',       "TLV tag type" );
	is( $tlv->length_type(), 'unsigned32', "TLV length type" );
	is( $tlv->value_type(),  'unsigned16', "TLV value type" );

	my $bin = Encode( 'MOP', 0x13 );
	is( bin2hexa($bin), "01000000020013", "TLV encoding" );

	# print Decode ('MOP', $bin)->dump(), "\n";
	# print Decode ('MOP', $bin)->dump(), "\n";

	declare_tlv( 'TR_PERIOD', 0x02, 'unsigned16', 'unsigned16', 'unsigned32' );
	declare_tlv( 'FTF_CA_SN', 0x03, 'unsigned16', 'unsigned16', 'unsigned32' );
	declare_tlv( 'TR_NUMBER', 0x04, 'unsigned16', 'unsigned16', 'unsigned32' );
	declare_tlv( 'D_KEY',     0x05, 'unsigned16', 'unsigned16', 'key16' );
	declare_tlv( 'T_KEY',     0x06, 'unsigned16', 'unsigned16', 'key16' );
	declare_tlv( 'T_KEY_D_KEY', 0x07, 'unsigned16', 'unsigned16', 'key16' );
	declare_tlv( 'ECI', 0x08, 'unsigned16', 'unsigned16', 'unsigned32' );

	$bin = Encode( 'TR_NUMBER', 0xFFFFFFFF );

	my $msg = Decode( 'TR_NUMBER', $bin );
	is( $msg->value(), 0xffffffff, "TR_NUMBER from TLV" );
	$msg = Decode( 'TR_NUMBER', $bin . $bin );
	is( $msg->value(), 0xffffffff, "TR_NUMBER from TLV too big" );
	$msg = Decode( 'TR_NUMBER', substr( $bin, 0, 6 ) );
	is( $msg->errors(), 1,
		"Buffer too small for TLV detected: " . $msg->error_description() );

	$bin = Encode( 'T_KEY', "0123456789ABCDEF0123456789ABCDEF" );

	$msg = Decode( 'T_KEY', $bin );
	is(
		$msg->value(),
		lc("0123456789ABCDEF0123456789ABCDEF"),
		"T_KEY from TLV"
	);
	$msg = Decode( 'T_KEY', $bin . $bin );
	is(
		$msg->value(),
		lc("0123456789ABCDEF0123456789ABCDEF"),
		"T_KEY from TLV too big"
	);
	$msg = Decode( 'T_KEY', substr( $bin, 0, 6 ) );
	is( $msg->errors(), 1,
		"Buffer too small for TLV_KEY detected: " . $msg->error_description() );
}

# ------------------------------------------------------------------------
# method: testTLV_Lists
#
# Test record encoding
# ------------------------------------------------------------------------
sub testTLV_Lists {
	my $Self = shift;

	declare Protocol::TLV_List(
		name     => 'msg1_params',
		elements => [
			{ name => 'TR_PERIOD', mandatory => TRUE,  multiple => FALSE },
			{ name => 'FTF_CA_SN', mandatory => TRUE,  multiple => FALSE },
			{ name => 'TR_NUMBER', mandatory => FALSE, multiple => TRUE },
			{ name => 'D_KEY',     mandatory => FALSE, multiple => FALSE }
		]
	);

	# basic TLV_List encoding
	my $bin = Encode(
		'msg1_params',
		{
			TR_PERIOD => 1,
			FTF_CA_SN => 2,
			D_KEY     => "0123456789ABCDEF0123456789ABCDEF"
		}
	);
	is(
		bin2hexa($bin),
"00020004000000010003000400000002000500100123456789abcdef0123456789abcdef",
		"simple TLV list encoding"
	);

	# and decoding
	my $msg = Decode( 'msg1_params', $bin );
	is( $msg->errors(),           0, "no errors for correct decoding" );
	is( $msg->value("TR_PERIOD"), 1, "TR_PERIOD from TLV_List" );
	is(
		$msg->value("D_KEY"),
		lc("0123456789ABCDEF0123456789ABCDEF"),
		"D_KEY from TLV_List"
	);
	is( $msg->value("TR_NUMBER"), undef, "TR_NUMBER from TLV_List" );

	# wrong field type
	eval {
		$bin = Encode(
			'msg1_params',
			{
				TR_PERIOD => 1,
				FTF_CA_SN => 2,
				D_KEY     => "0123456789ABCDEF0123456789ABCDEF",
				TR_NUMBER => 3
			}
		);
	};
	if ($@) {
		ok( 1, "TLV_Record encode, scalar unstead of list reported:\n$@" );
	}
	else {
		ok( 0, "TLV_List encode, scalar instead of list not reported" );
	}

	# empty list for TR_NUMBER
	$bin = Encode(
		'msg1_params',
		{
			TR_PERIOD => 1,
			FTF_CA_SN => 2,
			TR_NUMBER => []
		}
	);
	is(
		bin2hexa($bin),
		"00020004000000010003000400000002",
		"TLV list encoding with empty list"
	);

	# check with non empty list
	$bin = Encode(
		'msg1_params',
		{
			TR_PERIOD => 1,
			FTF_CA_SN => 2,
			TR_NUMBER => [ 0xdeadbeef, 0x01234567, 0x89ABCDEF ]
		}
	);

	is(
		bin2hexa($bin),
"0002000400000001000300040000000200040004deadbeef00040004012345670004000489abcdef",
		"TLV list encoding with non empty list"
	);
	$msg = Decode( 'msg1_params', $bin );
	is( $msg->value("TR_PERIOD"), 1,     "TR_PERIOD from TLV_List (2)" );
	is( $msg->value("D_KEY"),     undef, "D_KEY from TLV_List (2)" );
	is( $msg->value("TR_NUMBER.[0]"),
		0xdeadbeef, "TR_NUMBER[0] from TLV_List (2)" );
	is( $msg->value("TR_NUMBER.[1]"),
		0x01234567, "TR_NUMBER[1] from TLV_List (2)" );
	is( $msg->value("TR_NUMBER.[2]"),
		0x89ABCDEF, "TR_NUMBER[2] from TLV_List (2)" );
	is( $msg->value("TR_NUMBER.[3]"), undef, "TR_NUMBER[3] from TLV_List (2)" );
	is( $msg->number_of("TR_NUMBER"),
		3, "number_of TR_NUMBER from TLV_List (2)" );
	is( $msg->errors(), 0, "no errors for correct decoding (2)" );

	# Missing mandatory field FTF_CA_SN
	# during encoding
	eval {
		$bin = Encode(
			'msg1_params',
			{
				TR_PERIOD => 1,
				D_KEY     => "0123456789ABCDEF0123456789ABCDEF"
			}
		);
	};
	if ($@) {
		ok( 1, "TLV_List encode, missing mandatory field reported:\n$@" );
	}
	else {
		ok( 0, "TLV_List encode, missing mandatory field  not reported" );
	}

	# during decoding
	# $bin = hexa2bin("000200040000000100030004deadbeef");
	$bin = hexa2bin("0002000400000001");
	$msg = Decode( 'msg1_params', $bin );

	if ( $msg->errors() ) {
		ok( 1, "TLV_List decode, missing mandatory field reported:\n$@" );
	}
	else {
		ok( 0, "TLV_List decode, missing mandatory field not reported" );
	}

	# print "msg = " . Dumper ($msg) . "\n";
}

# ------------------------------------------------------------------------
# method: testTLV_Alternatives
#
# Test record encoding
# ------------------------------------------------------------------------
sub testTLV_Alternatives {
	my $Self = shift;

	declare Protocol::TLV_Alternative(
		name    => 'alternative',
		choices => [ 'TR_PERIOD', 'FTF_CA_SN', 'TR_NUMBER', 'D_KEY' ]
	);

	my $bin = Encode( 'TR_NUMBER', 0xFFFFFFFF );
	my $msg = Decode( 'alternative', $bin );
	is( $msg->type(),  'TR_NUMBER', "alternative decoding, message type" );
	is( $msg->value(), 0xFFFFFFFF,  "alternative decoding, message value" );

	# print "bin = " . bin2hexa($bin) . "\n";

	$bin = Encode( 'T_KEY', "0123456789ABCDEF0123456789ABCDEF" );
	$msg = Decode( 'alternative', $bin );

	if ( $msg->errors() ) {
		ok( 1,
			"TLV_Alternative decode, unexpected tag reported: "
			  . $msg->error_description() );
	}
	else {
		ok( 0, "TLV_Alternative decode, unexpected tag not reported" );
		print $msg->dump(1), "\n";
	}

	$bin = Encode( 'D_KEY', "0123456789ABCDEF0123456789ABCDEF" );
	$msg = Decode( 'alternative', $bin );
	is( $msg->type(), 'D_KEY', "alternative decoding, message type (2)" );
	is(
		$msg->value(),
		lc("0123456789ABCDEF0123456789ABCDEF"),
		"alternative decoding, message value (2)"
	);
}

# ------------------------------------------------------------------------
# method: testsTLV_Message
#
# Test record encoding
# ------------------------------------------------------------------------
sub testTLV_Message {
	my $Self = shift;

	my $tlvm = new Protocol::TLV_Message(
		name              => 'msg',
		field_descriptors => [
			{ name => 'protocol', type => 'byte' },
			{ name => 'version',  type => 'unsigned32' }
		],
		tag         => 0x35,
		tag_type    => 'byte',
		length_type => 'unsigned32',
		elements    => [
			{ name => 'TR_PERIOD', mandatory => TRUE,  multiple => FALSE },
			{ name => 'FTF_CA_SN', mandatory => TRUE,  multiple => FALSE },
			{ name => 'TR_NUMBER', mandatory => FALSE, multiple => TRUE },
			{ name => 'D_KEY',     mandatory => FALSE, multiple => FALSE }
		]
	);

	ok( $tlvm, "Creation of a TLV_Message" );
	my $msgType = TypeFromName("msg");
	is( $msgType->numberOfFields(), 2, "TLV message numberOfFields" );
	is(
		join( ", ", $msgType->fields() ),
		"protocol, version",
		"TLV message field list"
	);
	is( $msgType->numberOfElements(), 4,      "TLV message numberOfElements" );
	is( $msgType->tag(),              0x35,   "TLV message tag" );
	is( $msgType->tag_type(),         'byte', "TLV message tag_type" );
	is( $msgType->length_type(), 'unsigned32', "TLV message length_type" );

	my $buffer = Encode(
		'msg',
		{
			protocol  => 47,
			version   => 0xFF,
			TR_PERIOD => 1,
			FTF_CA_SN => 2,
			D_KEY     => "0123456789ABCDEF0123456789ABCDEF"
		}
	);

	is(
		bin2hexa($buffer),
		lc(
"2f000000ff350000002400020004000000010003000400000002000500100123456789abcdef0123456789abcdef"
		),
		"binary value of a TLV Message"
	);

	my $msg = Decode( 'msg', $buffer );
	is( $msg->value('version'),  255, "TLV_Message version" );
	is( $msg->value('protocol'), 47,  "TLV_Message protocol" );
	is(
		$msg->value('D_KEY'),
		lc("0123456789ABCDEF0123456789ABCDEF"),
		"TLV_Message D_KEY"
	);

	eval {
		$buffer = Encode(
			'msg',
			{
				protocol  => 47,
				TR_PERIOD => 1,
				FTF_CA_SN => 2,
				D_KEY     => "0123456789ABCDEF0123456789ABCDEF"
			}
		);
	};

	if ($@) {
		ok( 1, "TLV_Message encode, missing mandatory field reported:\n$@" );
	}
	else {
		ok( 0, "TLV_Message encode, missing mandatory field  not reported" );
	}

	eval {
		$buffer = Encode(
			'msg',
			{
				protocol  => 47,
				version   => 0xFF,
				TR_PERIOD => 1,
				D_KEY     => "0123456789ABCDEF0123456789ABCDEF"
			}
		);
	};
	if ($@) {
		ok( 1, "TLV_Message encode, missing mandatory field reported:\n$@" );
	}
	else {
		ok( 0, "TLV_Message encode, missing mandatory field  not reported" );
	}

	# Check TLV Message without header
	$tlvm = new Protocol::TLV_Message(
		name => 'msg_wo_header',

		#        field_descriptors => [
		#            {name => 'protocol',   type => 'byte'},
		#            {name => 'version', type => 'unsigned32'}
		#        ],
		tag         => 0x37,
		tag_type    => 'byte',
		length_type => 'unsigned32',
		elements    => [
			{ name => 'TR_PERIOD', mandatory => TRUE,  multiple => FALSE },
			{ name => 'FTF_CA_SN', mandatory => TRUE,  multiple => FALSE },
			{ name => 'TR_NUMBER', mandatory => FALSE, multiple => TRUE },
			{ name => 'D_KEY',     mandatory => FALSE, multiple => FALSE }
		]
	);

	ok( $tlvm, "Creation of a TLV_Message w/o header " );
	$msgType = TypeFromName("msg_wo_header");
	is( $msgType->numberOfFields(), 0,
		"TLV message w/o header numberOfFields" );
	is( join( ", ", $msgType->fields() ),
		"", "TLV message w/o header field list" );
	is( $msgType->numberOfElements(),
		4, "TLV message w/o header numberOfElements" );
	is( $msgType->tag(),      0x37,   "TLV message w/o header tag" );
	is( $msgType->tag_type(), 'byte', "TLV message w/o header tag_type" );
	is( $msgType->length_type(), 'unsigned32',
		"TLV message w/o header length_type" );

	$buffer = Encode(
		'msg_wo_header',
		{
			TR_PERIOD => 1,
			FTF_CA_SN => 2,
			D_KEY     => "0123456789ABCDEF0123456789ABCDEF"
		}
	);

	is(
		bin2hexa($buffer),
		lc(
"370000002400020004000000010003000400000002000500100123456789abcdef0123456789abcdef"
		),
		"binary value of a TLV Message w/o header"
	);

	$msg = Decode( 'msg_wo_header', $buffer );
	is(
		$msg->value('D_KEY'),
		lc("0123456789ABCDEF0123456789ABCDEF"),
		"TLV_Message w/o header D_KEY"
	);
}

# ------------------------------------------------------------------------
# method: testsTLV_MessageAlternative
#
# Test record encoding
# ------------------------------------------------------------------------
sub testTLV_MessageAlternative {
	my $Self = shift;

	my $tlvm = new Protocol::TLV_Message(
		name              => 'msg2',
		field_descriptors => [
			{ name => 'protocol', type => 'byte' },
			{ name => 'version',  type => 'unsigned32' }
		],
		tag         => 0x35,
		tag_type    => 'byte',
		length_type => 'unsigned32',
		elements    => [
			{ name => 'TR_PERIOD', mandatory => TRUE, multiple => FALSE },
			{ name => 'ECI',       mandatory => TRUE, multiple => FALSE }
		]
	);

	eval {
		declare Protocol::TLV_Alternative(
			name    => 'bad_all_msg',
			choices => [ 'msg', 'msg2' ]
		);
	};
	if ($@) {
		ok( 1, "TLV_Alternative duplication reported:\n$@" );
	}
	else {
		ok( 0, "TLV_Alternative duplication not reported" );
	}

	$tlvm->{'tag'} = 0x36;

	declare Protocol::TLV_Alternative(
		name    => 'all_msg',
		choices => [ 'msg', 'msg2' ]
	);

	my $bin = hexa2bin(
"2f000000ff350000002400020004000000010003000400000002000500100123456789abcdef0123456789abcdef"
	);

	my $msg = Decode( 'all_msg', $bin );
	is( $msg->type(),            'msg', "TLV_MessageAlternative type" );
	is( $msg->value('protocol'), 47,    "TLV_MessageAlternative protocol" );
	is(
		$msg->value('D_KEY'),
		lc("0123456789ABCDEF0123456789ABCDEF"),
		"TLV_MessageAlternative D_KEY"
	);

	# print $msg->dump();
}

# ------------------------------------------------------------------------
# method: testEnumerate
#
# Test enumerate encoding
# ------------------------------------------------------------------------
sub testEnumerate {
	my $Self = shift;

	my $enum;

	# declaration with missing labels
	eval { $enum = new Protocol::Enumerate( size => 1 ); };
	if ($@) {
		ok( 1, "Missing attribute detected" );
	}
	else {
		ok( 0, "Missing attribute not detected" );
	}

	# declaration with duplicate values
	eval {
		$enum = new Protocol::Enumerate(
			size   => 1,
			labels => { 1 => 'blue', 3 => 'orange', 7 => 'blue' }
		);
	};
	if ($@) {
		ok( 1, "Duplicate value detected" );
	}
	else {
		ok( 0, "Duplicate value not detected" );
	}

	$enum = new Protocol::Enumerate(
		size   => 1,
		name   => 'Fruits',
		labels => { 1 => 'blue', 3 => 'orange' }
	);

	ok( $enum, "Enumerate created" );
	is( $enum->size(),         1,            "enum size" );
	is( $enum->endianess(),    "big_endian", "default endianness" );
	is( $enum->unsigned(),     1,            "default unsigned" );
	is( $enum->label(1),       "blue",       "label(1)" );
	is( $enum->label(3),       "orange",     "label(3)" );
	is( $enum->code('orange'), 3,            "code('orange')" );

	my $bin = $enum->encode('orange');
	is( bin2hexa($bin),     "03",     "Enumerate encoding" );
	is( $enum->value($bin), 'orange', "Enumerate value" );

	my $msg = $enum->decode($bin);

	print $msg->dump(), "\n";
}

# ------------------------------------------------------------------------
# method: TestMain
#
# Test main routine. It is this method which is executed several times
# when the *-iteration* parameter is more than 1.
# ------------------------------------------------------------------------
sub TestMain {
	my $Self = shift;

	$Self->info("Protocol Encoder Unitary Test");

	$Self->testUtilities();
	$Self->testHexaString();
	$Self->testString();
	$Self->testAllIntegers();
	$Self->basicList();
	$Self->unboundedList();
	$Self->testRecords();
	$Self->testCombination();
	$Self->testTLV();
	$Self->testTLV_Alternatives();
	$Self->testTLV_Lists();
	$Self->testTLV_Message();
	$Self->testTLV_MessageAlternative();
	$Self->testRecordValues();
	$Self->testRecordConditional();
	$Self->testEnumerate();

	# print "Types:\n", join("\n", TypeList()), "\n";
}

# ------------------------------------------------------------------------
# Variable: test
my $testid =
  ( $config->value('testId') )
  ? $config->value('testId')
  : ExecutionContext::basename();

# my Test local instance.
my $test = new Encoder(
	loggerName => "Tests",
	testId     => $testid
);

$test->run();

