# ----------------------------------------------------------------------------
#
# Title:  Class with Logger (Moose version)
#
# Abstract:
#
#       Class with a default logger.
# ------------------------------------------------------------------------
package MClassWithLogger;
use Moose;
use MooseX::Has::Sugar;
use 5.010;

use Log::Log4perl qw(:easy);
use Data::Dumper;

has logName => (ro, default => "mylogger");


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
    
    unless ($sublogger) {$sublogger = ""};
    Log::Log4perl::get_logger($Self->{'logName'} . $sublogger);
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

    unless ($sublogger) {$sublogger = ""};
    $Self->logger($sublogger)->log( $level, 
        $Self->{'logName'} . "$sublogger : " . $str );
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
