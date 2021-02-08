# ----------------------------------------------------------------------------
#
# Title:  Class with Logger
#
# Abstract:
#
#       Class with a default logger.
# ------------------------------------------------------------------------
package ClassWithLogger;

use strict;
use vars qw($VERSION @ISA @EXPORT);
use Exporter;

$VERSION = 1;
@ISA     = qw(Exporter);

use Log::Log4perl qw(:easy);
use Data::Dumper;

use ExecutionContext;

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
    $Self->{'loggerName'}  = $Self->{'Class'};

    # Takes the constructor parameters as object attributs
    foreach my $key ( keys %attr ) {
        $Self->{$key} = $attr{$key};
    }

    # Others initialisation
    Log::Log4perl->init($Self->logConfigFile());
    $Self->debug("Creating instance");
}

# ------------------------------------------------------------------------
# method: logConfFile
#
#  returns the default log configuratin file.
# ------------------------------------------------------------------------
sub logConfigFile {
    if (-e "log4perl.conf") {
        return "log4perl.conf";
    } else {
        return "$ENV{'FTF'}/conf/log4perl.conf";
    }	
}

# ------------------------------------------------------------------------
# method: logger
#
#  returns the object default logger.
#
# Parameters:
#     sublogger - when required
# ------------------------------------------------------------------------
sub logger {
    my ( $Self, $sublogger) = @_;

    defined ($sublogger) or $sublogger = "";
    if (!exists($Self->{'logger'}->{$sublogger})) {
        my $loggerName = $Self->{'loggerName'} . $sublogger;
        $Self->{'logger'}->{$sublogger} = Log::Log4perl::get_logger($loggerName);
    }
    return $Self->{'logger'}->{$sublogger};
}

# ------------------------------------------------------------------------
# method: log
#
#  Log to the object default logger.
#
# Parameters:
#     Str - String to log
# ------------------------------------------------------------------------
sub log {
    my ( $Self, $level, $str, $sublogger ) = @_;

    my $sub = defined($sublogger) ? $sublogger : "";
    $Self->logger($sublogger)->log( $level, 
        $Self->{'loggerName'} . "$sub : " . $str );
}

# ------------------------------------------------------------------------
# method: debug
#
#  Log to the object default logger.
#
# Parameters:
#     Str - String to log
# ------------------------------------------------------------------------
sub debug {
    my ( $Self, $str, $sublogger ) = @_;
    $Self->log( $DEBUG, $str, $sublogger );
}

# ------------------------------------------------------------------------
# method: info
#
#  Log to the object default logger.
#
# Parameters:
#     Str - String to log
# ------------------------------------------------------------------------
sub info {
    my ( $Self, $str, $sublogger ) = @_;
    $Self->log( $INFO, $str, $sublogger );
}

# ------------------------------------------------------------------------
# method: warn
#
#  Log to the object default logger.
#
# Parameters:
#     Str - String to log
# ------------------------------------------------------------------------
sub warn {
    my ( $Self, $str, $sublogger ) = @_;
    $Self->log( $WARN, $str, $sublogger );
}

# ------------------------------------------------------------------------
# method: error
#
#  Log to the object default logger.
#
# Parameters:
#     Str - String to log
# ------------------------------------------------------------------------
sub error {
    my ( $Self, $str, $sublogger ) = @_;
    $Self->log( $ERROR, $str, $sublogger );
}

# ------------------------------------------------------------------------
# method: fatal
#
#  Log to the object default logger.
#
# Parameters:
#     Str - String to log
# ------------------------------------------------------------------------
sub fatal {
    my ( $Self, $str, $sublogger ) = @_;
    $Self->log( $FATAL, $str, $sublogger );
}

# ------------------------------------------------------------------------
# method: trace
#
#  Log to the object default logger.
#
# Parameters:
#     Str - String to log
# ------------------------------------------------------------------------
sub trace {
    my ( $Self, $str, $sublogger ) = @_;
    $Self->log( $TRACE, $str, $sublogger );
}

1;
