# ----------------------------------------------------------------------------
#
# Title:  Class ScriptConfiguration
#
# Name:
#
#       package ScriptConfiguration
#
# Abstract:
#
#       This singleton manages the script configuration. From a unique
#       parameter description, the script manages both the command line
#       and an optional configuration file.
#
#       Once the configuration defined, the script provides method
#       to get the status of the configuration parameters.
#       Command line parameters have a higher priority than
#       file parameters.
#
# Attributes:
#
#    attributes are hash parameters of the constructor.
#
#    header - online help header (default = 'usage: perl $0 [options]*')
#    footer - online help footer
#    scheme - NONE | SCRIPT | TEST, add some predefined parameters
#    parameters - a hash with {type => "", description => "", default=> ""} elements
#    configFile - the name of a configuration file
#    postpone - do not call the CLI parse in constructor (default 0)
#
# Parameters types:
#
#   flag - only one occurence allowed, returns a boolean value
#   string - only one occurence allowed, returns a string, may contain floats or integers
#   array - multiple occurence allowed
#
# Examples of parameters:
# (Start code)
#my %params = (
#    help => {
#        type        => "flag",
#        description => "display the online help.",
#        default     => 0
#    },
#    iteration => {
#        type        => "string",
#        description => "number of test iteration.",
#        default     => 1
#    },
#    match => {
#        type        => "array",
#        description => "Keywords, execute the matching parts, (default all)",
#        default     => ""
#    },
#    skip => {
#        type        => "array",
#        description => "Keyword, skip the matching parts (default none)",
#        default     => ""
#    },
#);
#
# (end)
#
# ------------------------------------------------------------------------
package ScriptConfiguration;

use strict;
use vars qw($VERSION @ISA @EXPORT);

use Exporter;
use Data::Dumper;
use ConfigurationFile;
use Getopt::Long;

$VERSION = 1;

@ISA = qw(Exporter);

use constant NONE   => 0;
use constant SCRIPT => 1;
use constant TEST   => 2;

@EXPORT = qw (NONE SCRIPT TEST);

# default options
my %script = (
    help => {
        type        => "flag",
        description => "display the online help.",
        default     => 0
    },
    verbose => {
        type        => "flag",
        description => "switch on verbose mode.",
        default     => 0
    },
    outputDirectory => {
        type        => "string",
        description => "directory for outputs",
        default     => "."
    },
);

my %test = (
    iteration => {
        type        => "string",
        description => "number of test iteration.",
        default     => 1
    },
    memory => {
        type        => "flag",
        description => "checks the memory usage.",
        default     => 0
    },
    pid => {
        type        => "string",
        description => "pid of the process to monitor",
        default     => 0
    },
    performance => {
        type        => "flag",
        description => "displays execution time.",
        default     => 0
    },
    match => {
        type        => "array",
        description => "Keywords, execute the matching parts, (default all)",
        default     => []
    },
    skip => {
        type        => "array",
        description => "Keyword, skip the matching parts (default none)",
        default     => []
    },
    testId => {
        type        => "string",
        description => "test identificator. (default = script basename)",
        default     => ""
    },
    synopsis => {
        type        => "string",
        description => "test short description",
        default     => ""
    },
    directory => {
        type        => "string",
        description => "Logs and result directory",
        default     => "."
    },
    requirements => {
        type        => "array",
        description => "Requirements covered by the test",
        default     => undef
    }
);

# ------------------------------------------------------------------------
# method: new
#
# Returns a new initialised object for the class.
#
# Usage:
# (Start code)
#my $config = new ScriptConfiguration(
#    'header'     => $help_header,
#    'footer'     => $help_footer,
#    'scheme'     => SCRIPT,
#    'parameters' => {
#        host => {
#            type => "string",
#            description => "Server (host:port) to connect to. \":port\" accepted for localhost"
#        },
#        type => {
#            type        => "string",
#            description => "Message type: Blue | Red | Green",
#            default     => "Blue"
#        },
#        size => {
#            type        => "string",
#            description => "Max size of ...",
#            default     => "30"
#        },
#    },
#    #    'configFile' => $configFile
#);
# (end)
# ------------------------------------------------------------------------
sub new {
    my $Class = shift;
    my $Self  = {};

    bless( $Self, $Class );
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

    my %attr = @_;

    # Attribute initialization
    $Self->{'header'}     = "usage: perl $0 [options]*";
    $Self->{'footer'}     = "";
    $Self->{'scheme'}     = NONE;
    $Self->{'parameters'} = {};
    $Self->{'configFile'} = undef;
    $Self->{'postpone'}   = 0;
    # keep a copy of the CLI
    my @args = @ARGV;
    $Self->{'argv'}       = \@args;

    # Takes the constructor parameters as object attributs
    foreach my $key ( keys %attr ) {
        $Self->{$key} = $attr{$key};
    }

    # Others initialisation
    if ( $Self->{'scheme'} == SCRIPT ) {
        $Self->addParams( \%script );
    }
    elsif ( $Self->{'scheme'} == TEST ) {
        $Self->addParams( \%script );
        $Self->addParams( \%test );
    }

    # file
    $Self->{'_cfg'} =
      new ConfigurationFile( filename => $Self->{'configFile'} );

    
    # CLI
    unless ( $Self->{'postpone'} ) {
        $Self->parse();
    }
    
    if ($Self->value('help')) {
        print $Self->usage();
        exit();
    }
}

# ------------------------------------------------------------------------
# method: addParam
#
# Add a new list of parameters to the object.
#
# Parameters:
# params - a reference to a hash table
# ------------------------------------------------------------------------
sub addParams {
    my ( $Self, $param_ref ) = @_;

    foreach my $key ( keys( %{$param_ref} ) ) {
        $Self->{'parameters'}->{$key} = $param_ref->{$key};
    }
}

# ------------------------------------------------------------------------
# method: parse
#
# Parse the command line.
# ------------------------------------------------------------------------
sub parse {
    my $Self = shift;

    my %opts = ();

    foreach my $key ( keys( %{ $Self->{'parameters'} } ) ) {
        my $type    = $Self->{'parameters'}->{$key}->{'type'};
        my $desc    = $Self->{'parameters'}->{$key}->{'description'};
        my $default = $Self->{'parameters'}->{$key}->{'default'};

        $Self->{'value'}->{$key} = undef;
        if ( $type eq "flag" ) {
            my $opt = $key;
            $opts{$opt} = \$Self->{'value'}->{$key};
        }
        elsif ( $type eq "string" ) {
            my $opt = $key . "=s";
            $opts{$opt} = \$Self->{'value'}->{$key};
        }
        else {

            # array
            my $opt = $key . '=s';
            $Self->{'value'}->{$key} = [];
            $opts{$opt} = $Self->{'value'}->{$key};
        }
    }
    exit unless (GetOptions(%opts));
}

# ------------------------------------------------------------------------
# method: usage
#
# Returns: a string describing the script accepted parameters.
#
# Example:
# (Start code)
#Test template. 
#
#usage: perl test.pl [options]
#    -verbose         flag    switch on verbose mode.
#    -fail            flag    set to emulate failure
#    -scenario        string  test scenario (subscript)
#    -match           array   Keywords, execute the matching parts, (default all)
#    -requirements    array   Requirements covered by the test
#    -directory       string  Logs and result directory, default=.
#    -outputDirectory string  directory for outputs, default=.
#    -memory          flag    checks the memory usage.
#    -synopsis        string  test short description
#    -skip            array   Keyword, skip the matching parts (default none)
#    -pid             string  pid of the process to monitor
#    -iteration       string  number of test iteration., default=1
#    -help            flag    display the online help.
#    -testId          string  test identificator. (default = script basename)
#    -performance     flag    displays execution time.
#
#Exemple:
#
#    perl test.pl -help
#    perl test.pl -iter 2 -scen scen1.scen
#
# (end)
# ------------------------------------------------------------------------
sub usage {
    my $Self = shift;

    my $help = $Self->{'header'} . "\n";
    my $max  = 0;
    foreach my $key ( keys( %{ $Self->{'parameters'} } ) ) {
        if ( length($key) > $max ) { $max = length($key); }
    }
    foreach my $key ( keys( %{ $Self->{'parameters'} } ) ) {
        my $type    = $Self->{'parameters'}->{$key}->{'type'};
        my $desc    = $Self->{'parameters'}->{$key}->{'description'};
        my $default = $Self->{'parameters'}->{$key}->{'default'};

        my $line = sprintf( "\t\-%-$max" . "s %-7s %s", $key, $type, $desc );
        if (exists($Self->{'parameters'}->{$key}->{'default'})) {
        	if (($type eq "array") && (ref($default) eq "ARRAY")) {
        		$line .= ", default=[" . join(", ", @{$default}) . "]";
        	} else {
        		$line .= ", default=" . $default;
        	}
        }
        $help .= $line . "\n";
    }
    $help .= $Self->{'footer'};
    return $help;
}

# ------------------------------------------------------------------------
# method: value
#
# Returns the value of a configuration parameter or undef.
#
# Parameters:
# parameter - parameter name
#
# Return:
#     The parameter value
#
# (start code)
# print $cfg->value('verbose');
# (end)
# ------------------------------------------------------------------------
sub value {
    my ( $Self, $parameter ) = @_;

    exists( $Self->{'parameters'}->{$parameter} )
      or die "unknown parameter \"$parameter\"";

    my $type    = $Self->{'parameters'}->{$parameter}->{'type'};
    my $desc    = $Self->{'parameters'}->{$parameter}->{'description'};
    my $default = $Self->{'parameters'}->{$parameter}->{'default'};

    my $val;

    # try to get value from CLI
    $val = $Self->{'value'}->{$parameter};
    if ($type eq 'array') {
        # return the array ref if there the array is not empty
        return $val if (scalar(@{$val}) > 0);
    } else {
        return $val if ($val);
    }

    # look in the configuration file
    $val = $Self->{'_cfg'}->value( '', $parameter );
    return $val if (defined($val));

    # return the default
    return $default;
}

# ------------------------------------------------------------------------
# method: numberOfValues
#
# Returns the number of element for a value. 0 when not defined, 1 for
# scalars and n for lists.
#
# Parameters:
# section - section name, (undef, or _anonymous for the anonymous section)
# variable - variable name
#
# Return:
#     The list element value
# ------------------------------------------------------------------------
sub numberOfValues {
    my ( $Self, $parameter ) = @_;

    exists( $Self->{'parameters'}->{$parameter} )
      or die "unknown parameter \"$parameter\"";

    my $type    = $Self->{'parameters'}->{$parameter}->{'type'};
    my $desc    = $Self->{'parameters'}->{$parameter}->{'description'};
    my $default = $Self->{'parameters'}->{$parameter}->{'default'};

    my $nb = 0;

    # check CLI
    if ( ( $type eq "flag" ) || ( $type eq "string" ) ) {
        $nb = 1 if defined( $Self->{'value'}->{$parameter} );
    }
    else {

        # array
        if ( defined( $Self->{'value'}->{$parameter} ) ) {
            $nb = scalar( @{ $Self->{'value'}->{$parameter} } );
        }
    }
    return $nb if ($nb);

    # check file
    $nb = $Self->{'_cfg'}->numberOfValues( '', $parameter );
    return $nb if ($nb);

    # check default
    if ( $type eq "array" ) {

        # number of values of arrays eq their number of elements
        return scalar( @{$default} );
    }
    elsif ( $type eq "flag" ) {

        # number of values of flafs equal 1 when they are set
        if ($default) {
            return 1;
        }
        else {
            return 0;
        }
    }
    else {

        # string
        if ( defined($default) ) {
            return 1;
        }
        else {
            return 0;
        }
    }
}

# ------------------------------------------------------------------------
# method: EltValue
#
# Shortcut to get the value of a list element
#
# Parameters:
# parameter - variable name
# index - index of the element inside the list
#
# Return:
#     The list element value
# ------------------------------------------------------------------------
sub eltValue {
    my ( $Self, $parameter, $index ) = @_;

    exists( $Self->{'parameters'}->{$parameter} )
      or die "unknown parameter \"$parameter\"";

    my $type = $Self->{'parameters'}->{$parameter}->{'type'};
    die "$parameter is not an array, eltValue is not applicable"
      if ( $type ne "array" );    
    my $desc    = $Self->{'parameters'}->{$parameter}->{'description'};
    my $default = $Self->{'parameters'}->{$parameter}->{'default'};

    my $val;

    # CLI
    if ( defined( $Self->{'value'}->{$parameter} ) ) {
        $val = @{ $Self->{'value'}->{$parameter} }[$index];
    }
    
    # File
    eval {
        $val = $Self->{'_cfg'}->eltValue( '', $parameter, $index );
    };
    if ( $@ || !defined($val) ) {
        # Default
        return @{$default}[$index];
    }
    return $val;
}

1;
