# ----------------------------------------------------------------------------
# Title:  Class MTest
#
# Abstract:
#
# Moose test environment. Objects of this class encapsulate
# test environments.
# ------------------------------------------------------------------------
package MTest;
use MooseX::Singleton; 

use MooseX::Has::Sugar;
use 5.010;
extends 'MClassWithLogger';

use XML::Writer;
use ExecutionContext;
use Time::HiRes qw(gettimeofday);
use Data::Dumper;

has success => (is => 'rw', default => 0);
has failures => (rw, default => 0);
has testId => (ro, required);
has scenario => (ro);
has exitOnFailure => (ro, default => 1);
has junit => (rw, default => "");

has start_time => (is => 'rw', default => 0);
has iter_start_time => (is => 'rw', default => 0);
has nb_iteration => (is => 'rw', default => 0);

has total_time => (rw, default => 0);
has iteration_total_time => (rw, default => 0);
has latest_iteration_time => (rw, default => 0);
has synopsis => (rw, default => "");
has failuresReasons => (rw, default => "");

sub BUILD () {
    my $Self = shift;
    
    if ($Self->{'junit'}) {unlink ($Self->{'junit'})}
}

# ------------------------------------------------------------------------
# method: passed
#
#   log that a check has been succesful
#
# Parameters:
#    $msg - string to log
# ------------------------------------------------------------------------
sub passed {
    my ( $Self, $msg ) = @_;

    $Self->{success}++;
    $Self->info( "PASSED " . $Self->{success} . " " . $msg, ".Checks" );
}

# ------------------------------------------------------------------------
# method: failed
#
#   log that a check has failed.
#
# Parameters:
#    $msg - string to log
# ------------------------------------------------------------------------
sub failed {
    my ( $Self, $msg ) = @_;

    $Self->{failures}++;
    $Self->error( "FAILED " . $msg, ".Checks" );
    $Self->{'failuresReasons'} .= $msg . "\n";

    if ( $Self->{'exitOnFailure'} ) {
        $Self->fatal("Test aborted on fatal error");
        $Self->result();
        exit();
    }
}


# ------------------------------------------------------------------------
# method: ok
#
#   Assertion check. The string to log is logged on the check logger at
#   passed of failed level depending on the result.
#
# Parameters:
#   $assertion - boolean assertion
#   $msg - string to log on the test logger.
# ------------------------------------------------------------------------
sub ok () {
    my ( $Self, $assertion, $msg ) = @_;
    if ($assertion) {
        $Self->passed($msg);    
    }
    else {
        $Self->failed($msg);    
    }
}


# ------------------------------------------------------------------------
# method: set_result
#
# Set the number of success and failures. This method is used when assertion
# evaluation is done by another program and reported globally
# ------------------------------------------------------------------------
sub set_result () {
    my ( $Self, $passed, $failed, $reason) = @_;
    $Self->{failures} = $failed if (defined($failed));
    $Self->{success} = $passed if (defined($passed));
    $Self->{failuresReasons} = $reason if (defined($reason));
}

# ------------------------------------------------------------------------
# method: result
#
# Print the test result
# ------------------------------------------------------------------------
sub result {
    my $Self = shift;

    if ( $Self->{failures} == 0 ) {
        $Self->warn(
"PASSED global $Self->{testId}, success=$Self->{success}, failures=0",
            ".Checks"
        );
    }
    else {
        $Self->error(
"FAILED global $Self->{testId}, success=$Self->{success}, failures=$Self->{'failures'}",
            ".Checks"
        );
        $Self->error(
            "FAILED because $Self->{testId} $Self->{'failuresReasons'}",
            ".Checks" );
    }
    if ( $Self->{'junit'} ) {
        $Self->_junit();
    }
}

# Perl trim function to remove whitespace from the start and end of the string
sub trim($)
{
    my $string = shift;
    $string =~ s/^\s+//;
    $string =~ s/\s+$//;
    return $string;
}

# ------------------------------------------------------------------------
# method: _junit (private)
#
# Generates the rest of the Junit xml file result
# ------------------------------------------------------------------------
sub _junit {
    my ($Self) = @_;

    # say Dumper($Self);
    
    my $junit = $Self->{'junit'};
    # print "generating Junit footer: $junit\n";

    my $fd;
    open( $fd, "> $junit" ) or die("cannot open file $junit : $!");

    print $fd "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>\n";
    my $xml = XML::Writer->new( OUTPUT => $fd, NEWLINES => 0 );
    my $hostname = `hostname`;
    chomp($hostname);
    my $date = `date`;
    chomp($date);
    my $failures = $Self->{'failures'};
    my $time     = $Self->{'total_time'};

    $xml->startTag(
        "testsuite",
        "errors"    => "0",
        "failures"  => $failures,
        "hostname"  => $hostname,
        "name"      => $Self->{'testId'},
        "tests"     => 1,
        "time"      => $time,
        "timestamp" => $date
    );
    print $fd "\n";

    # Generates the properties
    foreach my $line ( split( /\n/, ExecutionContext::context() ) ) {
        if ( $line =~ /(.*)\s*=\s*(.*)/ ) {
            my $name = trim($1);

            $xml->startTag(
                "property",
                name  => $name,
                value => $2
            );
            $xml->endTag("property");
            print $fd "\n";
        }
    }

    # Property synopsis
    $xml->startTag(
        "property",
        name  => "Synopsis",
        value => $Self->{'synopsis'}
    );
    $xml->endTag("property");
    print $fd "\n";

    # Execution environement variables
    # TODO

    # subtest list
    $xml->startTag(
        "testcase",
        classname => "Simulation",
        name      => $Self->{'testId'},
        time      => $time
    );
    if ( $Self->{failures} != 0 ) {
        print $fd "\n";
        $xml->startTag(
            "failure",
            message      => $Self->{'failuresReasons'}
        );
        $xml->endTag("failure");
        print $fd "\n";
    }
    $xml->endTag("testcase");
    print $fd "\n";

    $xml->startTag("system-out");
    print $fd "<![CDATA[";
    my $logfilename = main::logFilename();
    open(LOG, $logfilename) || die("Could not open file $logfilename!");
    my $data=<LOG>;
    close(LOG); 
    print $fd $data;
    print $fd "]]>";
    $xml->endTag("system-out");
    
    #
    print $fd "\n";
    $xml->startTag("system-err");
    print $fd "<![CDATA[";
    print $fd "]]>";
    $xml->endTag("system-err");

    print $fd "\n";
    $xml->endTag("testsuite");

    $xml->end();
    close($fd);
}

# ------------------------------------------------------------------------
# method: start
#
# Starts the test timer
# ------------------------------------------------------------------------
sub start () {
    my ( $Self, $msg ) = @_;
    
    $Self->info("test=" .  $Self->{'testId'} . ", scenario=" . $Self->{'scenario'} . " started");
    $Self->{'start_time'} = gettimeofday();
}

# ------------------------------------------------------------------------
# method: stop
#
# Stops the test timer
# ------------------------------------------------------------------------
sub stop () {
    my ( $Self, $msg ) = @_;
    
    $Self->{'total_time'} = gettimeofday() - $Self->{'start_time'};
    $Self->info("test=" .  $Self->{'testId'} . ", scenario=" . $Self->{'scenario'} . 
        " completed in " . $Self->{'total_time'} . " ms"
    );
    my $average = ($Self->{'nb_iteration'} != 0) 
        ? $Self->{'iteration_total_time'} / $Self->{'nb_iteration'}
        : 0;
    $Self->info("iterations=" . $Self->{'nb_iteration'} . ", average time=$average");
}

# ------------------------------------------------------------------------
# method: iteration_start
#
# New iteration
# ------------------------------------------------------------------------
sub iteration_start () {
    my ( $Self, $msg ) = @_;
    
    $Self->{'nb_iteration'}++; 
    $Self->info("iteration " . $Self->{'nb_iteration'} . " started");
    $Self->{'iter_start_time'} = gettimeofday();
}

# ------------------------------------------------------------------------
# method: iteration_stop
#
# End of iteration
# ------------------------------------------------------------------------
sub iteration_stop () {
    my ( $Self, $msg ) = @_;
    
    $Self->{'latest_iteration_time'} = gettimeofday() - $Self->{'iter_start_time'};
    $Self->{'iteration_total_time'} += $Self->{'latest_iteration_time'};
    $Self->info("iteration " . $Self->{'nb_iteration'} . 
    " completed in " . $Self->{'latest_iteration_time'} . " ms");
}

1;
