# ----------------------------------------------------------------------------
#
# Title:  Class Type
#
# File - Protocol/Type.pm
# Version - 1.0
# Author - fpeignot
#
# Name:
#
#       package Protocol::Type
#
# Abstract:
#
#    In this context a type has various attributes; size, number and structure of sub-components, etc.
#
#    Root class for the protocol management layer in this context a type has 
#    various attributes; size, number and structure of sub-components, etc. 
#    This class will be derived for various scalar types and lists and records.
#    
#    Types must contain enough information to control encoding or decoding 
#    of messages. They can be used directly but are likely 
#    generated by the parsing of a formal protocol specification. Once
#    the types database generated for a protocol, the databse is used either
#    directly by a script or to generate encoding or decoding routine
#    in a code generation phase.
#
#    This class is really the corner stone of this job. The main idea is really
#    to encapsulate the types layout inside this data. It is a purely
#    declarative task, and then to not have to worry any more about the physical
#    structure of the data.
#
#    This job is the third implementation after two succesful ones (the Ada
#    message generator and the Tcl Protocol handling layer)
#
#    The point is really about binary buffer parsing and generation. The purpose 
#    of this job is to fill the gap between the binary buffer structure 
#    specification and the most convenient API to handle data compliant with
#    this structure. The Tcl approach was really 
#    succesful. The parser error reporting was not perfect and there was no 
#    code generation but these two points could have been improved, so it 
#    is possible to just port this design. However I wonder if alternative 
#    approach like binary regular expressions pattern matching could not be as
#    effective. 
#
# Section: Types and Messages versus classes and objects
#
#       The point of this development is really to encapsulate all knowledge
#       about the protocol format into some program database AND NOT INTO
#       a class hierarchy structure.
#       For exemple if you have a Date record made of a Year, Month and Day fields
#       you need something to contain the date definition.
#       Something that we have often done and that I would avoid, at
#       least without automated code generation, is to derive a Date class
#       from the record class and to define the field list for the Date. The only 
#       difference between the record class and the date class is that the record class
#       is able to handle any record and the date class only date records.
#       The reason for which I would avoid the approach is that it generates
#       thousand of lines of code that you have to maintain even for relatively 
#       simple protocols (you generate on class for each message type).
#
# Types naming:
#
#       Types are identified by a name. Eventually it can be a complex 
#       structured name if we want to support name spaces. So the type
#       constructor will take this name as input parameter and the class
#       will maintain a mechanism to retreive a reference to the object
#       from the name. I think that the most currently used convention
#       to build structure names is to use '::' double colomns as 
#       sepearators. So we will use that, but in fact names are just
#       strings so you can use whatever convention that you want.
#
# Section: Encode and Decode profile
#
#       The input parameter of an encode method is either
#       - a scalar for scalar types
#       - a reference to a list for list types
#       - a reference to a hash for record types.
#
#       The result of a decode routine is a message from the Message class. Messages are objects
#       with a filed named value which has the same semantic than the encode input parameter.
#       Others fields are used to keep information about the decoding success, error number and error
#       messages, sizes, etc.
#
#       At some point during implementation I used Messages as well as input parameters, but it generates
#       an over-head that it is difficult to justify. Perhaps that I could have two versions of encode ??
#
# Section: Error Management Policiy
#
#       It seams resonable to treat in different ways encoding and decoding errors. During
#       encoding you are supposed to know what you are doing and you should provide data
#       compatible to the type that you are using. So errors are treated by exception.
#
#       During decoding it is more natural to sometime attempt to decode invalid data. So I have currently 
#       decided to store errors and error description inside the returned messages. That way decoding code
#       shoudl never raise exceptions, exception remains exceptional (this probably comes from my
#       former Ada programer life). It implies that usser must check the error status before to use
#       a message. It has also the advantage that partial values can be stored in messages. For example
#       when you detect an error while parsing the end of the message, you can have already stored
#       in the message the first fields. That may help to build more meaningful error messages.
#
# Truncation or error: 
#
#       I have to decide what to do when more data than required is supplied for encoding. For example
#       20 bytes are supplied to fit into a 16 bytes string. FIrst I'll treat that as an error, just to
#       be safe. I'll relax the control if it makes the usage more difficult.
#      
# ----------------------------------------------------------------------------
package Protocol::Type;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

use Exporter;
use Log::Log4perl;
use Data::Dumper;

use lib "$ENV{'FTF'}/lib";
use Protocol::Utilities;
use Carp;

$VERSION = 1;

@EXPORT = qw (Encode Decode TypeList DefinedType TypeFromName);
@ISA = qw(Exporter);

$Protocol::Type::BYTES = 8;    # number of bits in a byte

my @dimensions = qw(scalar list record alternative);

# Table of all the types declared in an application. With this table it
# is possible to use an existing type to encode or decode a message.
my $Type_Table = {};

# ------------------------------------------------------------------------
# method: new
#
# Parameters:
#    Class - name of the class
#    Name - Name of the type
#    args - list of initialisation parameters
# Returns a new initialised object for the class.
# ------------------------------------------------------------------------
sub new {
    my $Class = shift;
    
    # The name attribut could be useful to support types which are only
    # different by their names (Kind of Ada strong typing)
    # In this paradigm you can have several integers to handle incompatible
    # values which have exactly the same attributs (except the name).
    # This way it is possible to forbid addition of speeds and surfaces, etc.
    # I am not sure that I want to go so far in this work.
    # my $name = shift;
    
    my $Self  = {};

    bless( $Self, $Class );

    $Self->{Logger} = Log::Log4perl::get_logger('Encoder');
    $Self->{Logger}->warn("Creating instance of $Class");
    my %attr = @_;
    $Self->{Logger}->info("new $Class (" . Dumper(%attr) . ")");
    $Self->{'Class'} = $Class;

    $Self->_init(@_);    
    return $Self;
}

# ------------------------------------------------------------------------
# method: declare
#
# Abstract:
#
#   Alias for new. When you do not care for the returned object and intend
#   to rely on access to type by name (usage of Encode and Decocde). The
#   dclare routine makes the code mode natural. You just declare new types.
# ------------------------------------------------------------------------
sub declare {
    return new (@_);
}

# ------------------------------------------------------------------------
# method: _init (private)
#
# Initialisation of the object. Do not call directly.
# ------------------------------------------------------------------------
sub _init {
    my $Self = shift;

    my %attr = @_;

    # Default Attribute values

    # Others initialisation
    # Takes the constructor parameters as object attributs
    foreach my $key ( keys %attr ) {
        # print "init $key  => $attr{$key}\n";
        $Self->{$key} = $attr{$key};
    }
    if (exists($Self->{'name'})) {
        my $type_name = $Self->{'name'};
        # the type is not anonymous
        if (exists($Type_Table->{$type_name})) {
            # redeclaration of the same type name. There are perhaps cases where it would
            # bring more benefits to accept it. However I think that it is probably safer
            # to raise an error.
            croak "type $type_name already defined. Use namespaces to avoid conflicts.";
        } else {
            $Type_Table->{$type_name} = $Self;
        }
    }
}

# ------------------------------------------------------------------------
# method: size
#
# Sets or returns the size of the type in bytes. The size is undef when the type
# is unbounded or contain unbounded elements. It has beed considered than bytes
# are more convenients than bits for sizes. Eventually some methods to extract
# bitfields from byte streams will be provided.
#
# Parameters:
# value - when void the method get the value. when defined, set the value.
#
# Return:
# the size of the type in bytes.
# ------------------------------------------------------------------------
sub size {
    my $Self = shift;

    $Self->{'size'} = shift if @_;
    return $Self->{'size'};
}

# ------------------------------------------------------------------------
# method: name
#
# Returns the name of the type in bytes.
#
# Return:
# the name of the type.
# ------------------------------------------------------------------------
sub name {
    my $Self = shift;

    $Self->{'name'} = shift if @_;
    return $Self->{'name'};
}

# ------------------------------------------------------------------------
# method: structure
#
# Sets or returns the structure of the type. it can be either
# scalar, list, record or alternative.
#
# Parameters:
# value - when void the method get the value. when defined, set the value.
#
# Return:
# the type structure
# ------------------------------------------------------------------------
sub structure {
    my $Self = shift;

    if (@_) {
        my $value = shift;

        existIn($value, @dimensions) or croak "\"$value\" is an incorrect value for structure (scalar, list, record, alternative)";       
        $Self->{'structure'} = $value;
    }
    return $Self->{'structure'};
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
    croak "_check is not yet implemented";
}

# ------------------------------------------------------------------------
# method: encode
#
# Encode a value or a list of values according to the type. This method
# is virtual and each type implementation will have to provide one.
#
# Parameters:
# $value - a value, its structure depends on the type, scalar, list reference, hash reference, etc.
#
# Return: a binary buffer
# ------------------------------------------------------------------------
sub encode {
    my ($Self, $value) = @_;
    croak "NYI encode must be overloaded for each subtype." . Dumper($value);
}

# ------------------------------------------------------------------------
# method: decode
#
# Decode a binary buffer and return a message. This method
# is virtual and each type implementation will have to provide one.
# ------------------------------------------------------------------------
sub decode {
    my $Self = shift;
    croak "NYI decode must be overloaded by each scalar subtype.";
}


# ------------------------------------------------------------------------
# method: dump
#
# print an ASCII representation of the object
# ------------------------------------------------------------------------
sub dump {
    my $Self = shift;

    print Dumper($Self), "\n";
}

# ------------------------------------------------------------------------
# method: Encode
#
# Encode using a type name. The Type class maintain a table of all the
# existing types by name. It is possible to use the method to encode
# a list of value without having access to a type object.
#
# Parameters:
# $typename - the name of a type already declared.
# $value - supported value type depends on typename 
# 
# Return: a binary buffer
# ------------------------------------------------------------------------
sub Encode {
    my ($typename, $value) = @_;
    
    my $log = Log::Log4perl::get_logger('Encoder');
    $log->info("Encode (\"" . $typename . "\")");
    exists ($Type_Table->{$typename}) or croak "Unknown type \"$typename\" in Encode";
    
    $log->trace("Encode with " . Dumper($Type_Table->{$typename}) ); 
    # $log->trace("Encode what " . Dumper($value) );    
    return $Type_Table->{$typename}->encode($value);
}

# ------------------------------------------------------------------------
# method: Decode
#
# Decode a binary buffer and return a message using the type name
# instead of having direct access to the object.
# ------------------------------------------------------------------------
sub Decode {
    my ($typename, $buffer) = @_;
    
    my $log = Log::Log4perl::get_logger('Encoder');
    $log->info("Decode (\"" . $typename . "\")");
     exists ($Type_Table->{$typename}) or croak "Unknown type \"$typename\" in Decode";    
    return $Type_Table->{$typename}->decode($buffer);
}

# ------------------------------------------------------------------------
# method: TypeList
#
# Return the list of non anonymous types
# ------------------------------------------------------------------------
sub TypeList {
    my ($typename) = @_;
    
    return sort(keys(%{$Type_Table})) ;
}

# ------------------------------------------------------------------------
# method: DefinedType
#
# Return true when the type has already been defined
# ------------------------------------------------------------------------
sub DefinedType {
    my ($typename) = @_;
    
    return exists($Type_Table->{$typename}); 
}

# ------------------------------------------------------------------------
# method: TypeFromName
#
# Return a type from its name
# ------------------------------------------------------------------------
sub TypeFromName {
    my ($typename) = @_;
    
    croak "type \"$typename\" has not been declared" unless exists($Type_Table->{$typename});
    return $Type_Table->{$typename}; 
}
1;