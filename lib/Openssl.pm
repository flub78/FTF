# ----------------------------------------------------------------------------
#
# Title:  Class Openssl
#
# Source - <file:../Class.pm.html>
# Version - 1.0
#
# Abstract:
#
#       Interface to the openssl command line tool. 
#       This is perhaps not the most efficient way to access to the
#       openssl library but it is a very symple one.
# ------------------------------------------------------------------------
package Openssl;

use strict;
use vars qw($VERSION @ISA @EXPORT);
use Exporter;

$VERSION = 1;
@ISA     = qw(Exporter);

use Log::Log4perl;
use Data::Dumper;

# ------------------------------------------------------------------------
# method: new
#
# Class constructor.
#
# Parameters:
#
#    Contructors often takes a hash table parameter. Each entry
#    of the table is the name of an object attribute.
#
# Returns: a new initialised object for the class.
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
#
# Most constructors are organized into three steps.
#    - default attributes initialization
#    - attribute from the parameter constructor
#    - completion of attributes
# ------------------------------------------------------------------------
sub _init {
    my $Self = shift;

    my %attr = @_;

    # Attribute initialization
    $Self->{'key'}  = "";
    $Self->{'iv'} = "";
    $Self->{'cipher'} = "base64";

    # Takes the constructor parameters as object attributs
    foreach my $key ( keys %attr ) {
        $Self->{$key} = $attr{$key};
    }

    # Others initialisation
    unless ( exists( $Self->{'Logger'} ) ) {
        my $Class = $Self->{'Class'};
        $Self->{Logger} = Log::Log4perl::get_logger($Class);
        $Self->{Logger}->debug("Creating instance of $Class");
    }
}



# ------------------------------------------------------------------------
# method: _save
#
# save a variable content into a file
#
# parameters:
# filename - name of the file to save
# variable - data to save
#
# return: describe the returned value
# ------------------------------------------------------------------------
sub _save {
    my ($Self, $filename, $variable)   = @_;
    my $log = $Self->{Logger};

    $log->trace("$Self->{'Class'}->_save ($filename, $variable)");
        defined($filename) or $filename = $Self->{'filename'};

    open( FD, "> $filename" ) || croak("can't open $filename: $!");
    print FD $variable;
    close(FD);
}

# ------------------------------------------------------------------------
# method:  _load
#
# Load data from a file
#
# Parameters:
# filename - name of the file
#
# returns: data
# ------------------------------------------------------------------------
sub _load {
    my ( $Self, $filename ) = @_;

    my $log = $Self->{Logger};
    $log->info("_load $filename");

    open( FD, "< $filename" ) or croak("cannot open file $filename : $!");
    my $data = <FD>;
    close(FD);
    return $data;
}

# ------------------------------------------------------------------------
# method encrypt
#
# encrypt some data
#
# Parameters:
# data - data to encrypt
#
# returns: encrypted data
# ------------------------------------------------------------------------
sub encrypt {
    my ( $Self, $data, $dec ) = @_;

    my $decopt = ($dec) ? " -d" : "";
    my $log = $Self->{Logger};
    $log->info("encrypt $data");

    my $inputName = "/tmp/input" . $$; 
    my $outputName = "/tmp/output" . $$;
    $Self->_save($inputName, $data);
    my $cmd = "openssl enc -" . $Self->{'cipher'} .
        $decopt .
        " -K " . $Self->{'key'} . " -iv " . $Self->{'iv'} .
        " < $inputName > $outputName";
    system ($cmd);
    
    my $data = $Self->_load($outputName);
    unlink ($inputName);
    unlink ($outputName);
    return $data; 
}

# ------------------------------------------------------------------------
# method decrypt
#
# decrypt some data
#
# Parameters:
# data - data to decrypt
#
# returns: plain text
# ------------------------------------------------------------------------
sub decrypt {
    my ( $Self, $data) = @_;
    return $Self->encrypt($data, 1);
}    

1;
