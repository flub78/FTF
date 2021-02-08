# ----------------------------------------------------------------------------
# Title:  Class MemoryMonitor
#
# File - MemoryMonitor.pm
# Version - 1.0
#
# Abstract:
#
#       Memory monitor. This object can measure the memory
#       used by a Unix process and estimate the risk of a
#       memory leak.
#
#       On request the object returns the point in percentage
#       of measures where the peak has been reached. One may considere
#       for example than there is no memory leak when the peak
#       has been reached within the first third and there is a
#       sufficient number of measures.
#
#       By default the object uses The Unix::Process library to get
#       the amount of memory used by a process. When the object has
#       a 'ps_cmd' defined attribut, this command is used and parsed
#       to find the amount of memory.
#
#       When you specify a size attribute to the constructor, the object
#       maintains a round robin database of memory values and measure time.
#       The time and value methods returns the latest measure when they are
#       called without parameters. You can specify a negative offset to
#       get previous values; -1 get you the previous value, -2 the previous previous,
#       etc.
#
#       Warning times and values are only meaningfull after a number
#       of measure bigger than the round robin database size.
# ------------------------------------------------------------------------
package MemoryMonitor;

use strict;
use vars qw($VERSION @ISA @EXPORT);

use Exporter;
use Log::Log4perl;
use Data::Dumper;
use Carp;
use Time::HiRes qw(gettimeofday);

BEGIN {
    eval { require Unix::Process; };
}

$VERSION = 1;

@ISA = qw(Exporter);

# ------------------------------------------------------------------------
# method: new
#
# Returns a new initialised object for the class.
# ------------------------------------------------------------------------
sub new {
    my $Class = shift;
    my $Self  = {};

    bless( $Self, $Class );

    $Self->{Logger} = Log::Log4perl::get_logger($Class);
    $Self->{Logger}->debug("Creating instance of $Class");
    $Self->_init(@_);

    return $Self;
}

# ------------------------------------------------------------------------
# method: reset
#
# Reset the MemoryMonitor for a new set of measures
# ------------------------------------------------------------------------
sub reset {
    my $Self = shift;
    my $log  = $Self->{Logger};

    # Initialisation
    $Self->{'measureCount'} = 0;
    $Self->{'memoryPeak'}   = 0;
    $Self->{'peakIndex'}    = 0;
    $Self->{'values'}       = [];
    $Self->{'dates'}        = [];
}

# ------------------------------------------------------------------------
# method: _init (private)
#
# Initialisation of the object. Do not call directly.
# ------------------------------------------------------------------------
sub _init {
    my $Self = shift;
    my $log  = $Self->{Logger};

    my %attr = @_;

    # Initialisation
    $Self->reset();
    $Self->{'pid'}                         = 0;
    $Self->{'ps_cmd'}                      = 'ps -fel';
    $Self->{'use_ps'}                      = 1;
    $Self->{'size_column'}                 = 10;          # OK for AIX
    $Self->{'not_self'}                    = 0;
    $Self->{'size'}                        = 1;
    $Self->{'acceptable_leak_per_measure'} = 0;
    $Self->{'acceptable_leak_per_second'}  = 0;

    # Takes the constructor parameters as object attributs
    foreach my $key ( keys %attr ) {
        $Self->{$key} = $attr{$key};
    }

    if ( $Self->{'use_ps'} ) {
        $Self->{'unit'} = "Kbytes";
    }
    else {
        $Self->{'unit'} = "Kbytes";
    }

    # pid management
    my $pid    = $Self->{'pid'};
    my $ps_pid = 0;
    unless ( $pid =~ /^\d+$/ ) {
        $log->trace("non numerical pid");
        my $ps = `$Self->{'ps_cmd'}`;
        chomp($ps);
        my @pslist = split( /\n/, $ps );

        # $log->trace("pattern=" . $pid .", ps=\n" . $ps);

        foreach my $line (@pslist) {
            if ( $line =~ /.*$pid.*/ ) {

                # line matches the pid pattern
                my @list = split( /\s+/, $line );
                $ps_pid = $list[4];
                print $pid, ":", $$, ":", $ps_pid, "->", $line, "\n";
                next if ( ( $$ == $ps_pid ) && ( $Self->{'not_self'} ) );

                $Self->{'pid'} = $ps_pid;
                return $ps_pid;
            }
        }
        die "pid " . $pid . " not found";
    }
    else {

        # numerical pid
        ( $Self->{'pid'} != 0 )
          or croak "No pid defined and memory check required";
    }
}

# ------------------------------------------------------------------------
# method: pid
#
# This accessor can be use to set or get the value of the pid
#
# Parameters:
# value - when defined, set the pid.
#
# Return:
#    the pid value
# ------------------------------------------------------------------------
sub pid {
    my $Self = shift;

    $Self->{'pid'} = shift if @_;
    return $Self->{'pid'};
}

# ------------------------------------------------------------------------
# method: measureCount
#
# This accessor can be use to set or get the value of the measure counter
#
# Parameters:
# value - when defined, set the measure counter.
#
# Return:
#    the number of measure
# ------------------------------------------------------------------------
sub measureCount {
    my $Self = shift;

    $Self->{'measureCount'} = shift if @_;
    return $Self->{'measureCount'};
}

# ------------------------------------------------------------------------
# method: size
#
# This accessor can be use to set or get the size of the round robin
# buffer.
#
# Parameters:
# value - when defined, set the size.
#
# Return:
#    the size
# ------------------------------------------------------------------------
sub size {
    my $Self = shift;

    $Self->{'size'} = shift if @_;
    return $Self->{'size'};
}

# ------------------------------------------------------------------------
# method: memoryPeak
#
# Return:
#    the memory peak
# ------------------------------------------------------------------------
sub memoryPeak {
    my $Self = shift;

    return $Self->{'memoryPeak'};
}

# ------------------------------------------------------------------------
# method: unit
#
# Return:
#    the memory unit
# ------------------------------------------------------------------------
sub unit {
    my $Self = shift;

    return $Self->{'unit'};
}

# ------------------------------------------------------------------------
# method: get_memory
#
# get memory from a ps command
#
# Return:
#    the memory value
# ------------------------------------------------------------------------
sub get_memory {
    my $Self = shift;

    my $log = $Self->{Logger};

    my $ps = `$Self->{'ps_cmd'}`;
    chomp($ps);
    my @pslist = split( /\n/, $ps );

    my $pid = $Self->{'pid'};
    $log->info( 'get_memory(' . $pid . ')' );
    foreach my $line (@pslist) {
        if ( $line =~ /(\w*)\s(\d+).*$pid/ ) {

            # line matches the pid pattern
            # print "pid=$$, line=$line\n";
            unless ( $line =~ /$Self->{'ps_cmd'}/ ) {

                # skip the ps itself
                $log->info("pid=$$, line=$line");
                my @list = split( /\s+/, $line );
                return $list[ $Self->{'size_column'} ];
            }
        }
    }
    die "did not find " . $pid . " in \n" . $ps;
}

# ------------------------------------------------------------------------
# method: measure
#
# measure the memory used by the process
#
# return:
# the memory measure
# ------------------------------------------------------------------------
sub measure {
    my $Self = shift;

    my $log = $Self->{Logger};

    my $mem;
    if ( $Self->{'use_ps'} ) {

        # get memory from ps_cmd, low accuracy
        $mem = $Self->get_memory();
    }
    else {

        # get memory locally, high accuracy
        $mem = Unix::Process->vsz( $Self->{'pid'} );
    }
    my $time = gettimeofday;

    my $idx = $Self->{'measureCount'} % $Self->{'size'};
    print "count = " . $Self->{'measureCount'} . ", idx = $idx\n";

    @{ $Self->{'values'} }[$idx] = $mem;
    @{ $Self->{'dates'} }[$idx]  = $time;

    $Self->{'measureCount'} += 1;

    if ( $mem > $Self->{'memoryPeak'} ) {
        $Self->{'memoryPeak'} = $mem;
        $Self->{'peakIndex'}  = $Self->{'measureCount'};
    }

    $log->info( "memory = " . $mem );
    return $mem;
}

sub vsz { my $Self = shift; return Unix::Process->vsz( $Self->{'pid'} ); }

# ------------------------------------------------------------------------
# function: value
#
# Return a value stored in the round robin database.
# value (undefined) or value (0) return the latest value
# value (-1) returns the previous value.
# value (1) returns the oldest value.
#
# Parameters:
# offset - offset
# Return:
#    a value from the round robin database
# ------------------------------------------------------------------------
sub value {
    my ( $Self, $offset ) = @_;

    $offset = 0 unless ( defined($offset) );

    my $idx = ( $Self->{'measureCount'} + $offset - 1 ) % $Self->{'size'};
    my $val = @{ $Self->{'values'} }[$idx];
    return $val;
}

# ------------------------------------------------------------------------
# function: time
#
# Parameter:
# offset - time offset, see value for explaination
#
# Return:
#    a time from the round robin database
# ------------------------------------------------------------------------
sub time {
    my ( $Self, $offset ) = @_;

    $offset = 0 unless ( defined($offset) );

    my $idx = ( $Self->{'measureCount'} + $offset - 1 ) % $Self->{'size'};
    my $val = @{ $Self->{'dates'} }[$idx];
    return $val;
}

# ------------------------------------------------------------------------
# function: delta_value
#
# Return the difference between the latest and oldest value
# ------------------------------------------------------------------------
sub delta_value {
    my ( $Self, $offset ) = @_;

    $offset = 1 unless ( defined($offset) );

    my $value = $Self->value();
    defined($value) or die "cannot compute memory usage, no measure done"; 

    my $oldest_value = $Self->value($offset);
    defined ($oldest_value) or die "cannot compute memory usage, no enough measure done";
    
    return ($value - $oldest_value);
}

# ------------------------------------------------------------------------
# function: delta_time
#
# Return the difference between the latest and oldest time
# ------------------------------------------------------------------------
sub delta_time {
    my ( $Self, $offset ) = @_;

    $offset = 1 unless ( defined($offset) );

    my $time = $Self->time();
    defined($time) or die "cannot compute memory usage, no measure done"; 

    my $oldest_time = $Self->time($offset);
    defined ($oldest_time) or die "cannot compute memory usage, no enough measure done";
    
    return ($time - $oldest_time);
}


# ------------------------------------------------------------------------
# function: peakPercentage
#
# Return:
#    the index to which the peak has been reach in percentage of
# ------------------------------------------------------------------------
sub peakPercentage {
    my $Self = shift;

    if ( $Self->{'measureCount'} ) {
        return int( 100 * $Self->{'peakIndex'} / $Self->{'measureCount'} );
    }
    else {
        return 0;
    }
}

1;
