# ----------------------------------------------------------------------------
#
# Title:  Class Sequence
#
# Abstract:
#
#       This class is an abstraction for test sequences or sequence
#       diagrams.
#
#       In a test context, the problem is to activate a sequence
#       of actions compliant with a a given sequence diagram. The point is
#       to accept correct sequences and to reject incorrect ones. In other words
#       during the test of of a TCP/IP client or server, this class must help
#       to determine the next message to send to the peer, when it should
#       be sent, and if the replies received are acceptable or not.
#
#       We see that in the general case, the problem is quite complex.
#       The abstraction must be rich enough to handle most
#       of the cases encountered in the real life, but simple enough to keep
#       the expression of simple cases easy.
#
#       At least, our performance tests are used to handle transmission windows.
#       It means that new messages are not transmitted as long as enough replies have not been
#       received. This class could manage this feature or provide some support.
#
# Section: Examples
#
# Exemple 1:
#
#       - The test send a message "A" to a peer
#       - and expect a reply "B".
#
# Exemple 2:
#
#       - The test expect expect a prompt message
#       - it replies a "Ready" message
#       - for i = 0 to 9
#       - --- send message A[i]
#       - --- expect message B[i]
#       - end loop
#
# Exemple 3:
#
#      Same case than example 2, but the replies "B" are allowed
#      to arrive out of order and we want the measure the service time
#      between a request and the associated replies.
#
# Exemple 4:
#
#      Same case than example 3, but a "keep-alive" message is sent
#      when no activity is detected from the peer during more than
#      10 secondes. Keep-alive messages must be receive an "I-am-alive"
#      replies within 3 seconds.
#
#      And one message every 7 messages, has its replies sent twice.
#
# And so-on.
#
# Section: Design
#
# - We can see from the exemple aboves than messages cannot be managed
#   as binary byte streams. Acceptable replies depend on the sent requests.
#
# - As the problem cannot be solve in the general case, This class is
# an abstract one. Real one are supposed to be provided to implement the real services.
#
# - Relationship with the State Machine Automaton ?  SMA objects come handy
#
# Section content:
#
# next_message - a method which returns the next message
# check_reply - a method to inform the sequence of a message reception
# current_window - returns the number of transmitted request not yet replied
# is_completed - boolean method to determine if a sequence is over.
# errors - number of errors found during the sequence
# statistic - return information
#
# The statistic data should contain:
# - the number of messages sent
# - the number of messages received
# - the quantity of data sent (in bytes)
# - the quantity of data received
# - the min, max, average, standard deviation of the reply time
# - sequence start time
# - sequence completion time
# - sequence idle time
# ------------------------------------------------------------------------
package Sequence;

use strict;
use vars qw($VERSION @ISA @EXPORT);

use Exporter;
use Log::Log4perl;
use Data::Dumper;
use Time::HiRes qw(gettimeofday);

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
# method: _init (private)
#
# Initialisation of the object. Do not call directly.
# ------------------------------------------------------------------------
sub _init {
	my $Self = shift;

	my %attr = @_;

	# default values
	$Self->{'window'} = 1;

	# Takes the constructor parameters as object attributs
	foreach my $key ( keys %attr ) {
		$Self->{$key} = $attr{$key};
	}

	$Self->{'messages_sent'}     = 0;
	$Self->{'messages_received'} = 0;
	$Self->{'errors'}            = 0;

	$Self->{'start_time'}         = gettimeofday();
	$Self->{'stop_time'}          = 0;
	$Self->{'total_time'}         = 0;
	$Self->{'transaction_number'} = 0;
	$Self->{'transactions'}       = {};
}

# ------------------------------------------------------------------------
# method: next_message
#
# Returns the next message to send or undef when no message is to send.
# Undef can be returned when the sequence is over or when the ahead message
# window has been reached.
# ------------------------------------------------------------------------
sub next_message {
    my $Self = shift;
    
    $Self->{'Logger'}->debug("next_message");
	die
"Sequence is an abstract class, method next_message should be overloaded.";
}

# ------------------------------------------------------------------------
# method: check_reply
#
# Register a received message.
#
# Parameters:
#    $msg - binary message to check
# ------------------------------------------------------------------------
sub check_reply {
    my ( $Self, $msg ) = @_;

    $Self->{'Logger'}->debug("check_reply");
	die
	  "Sequence is an abstract class, method check_reply should be overloaded.";
}

# ------------------------------------------------------------------------
# method: is_completed
#
# Returns true when the sequence is completed, it means when all messages
# to send have been sent and all expected replies have been received.
# ------------------------------------------------------------------------
sub is_completed {

    my $Self = shift;

    $Self->{'Logger'}->debug("is_completed");
	die
"Sequence is an abstract class, method is_completed should be overloaded.";
}

# ------------------------------------------------------------------------
# method: statistic
#
# Returns some statistic about the treatments
# ------------------------------------------------------------------------
sub statistic {
	my ($Self) = @_;

	my $res = "";

	$res .= "window size               = " . $Self->{'window'} . "\n";
	$res .= "messages sent             = " . $Self->{'messages_sent'} . "\n";
	$res .= "messages received         = " . $Self->{'messages_received'} . "\n";
	$res .= "number of errors          = " . $Self->{'errors'} . "\n";

	my $duration = $Self->{'stop_time'} - $Self->{'start_time'};
	$res .= "sequence duration         = " . $duration . "\n";

	$res .= "service total time   = " . $Self->{'total_time'} . "\n";
	$res .=
	  "requests number       = " . $Self->{'transaction_number'} . "\n";
	if ( $Self->{'transaction_number'} ) {
		my $avg = $Self->{'total_time'} / $Self->{'transaction_number'};
		$res .= "service average time = " . $avg . "\n";
	}

	if ( exists( $Self->{'min_time'} ) ) {
		$res .= "service min time     = " . $Self->{'min_time'} . "\n";
	}

	if ( exists( $Self->{'max_time'} ) ) {
		$res .= "service max time     = " . $Self->{'max_time'} . "\n";
	}
	return $res;
}

# ------------------------------------------------------------------------
# method: pending_transaction
#
# Returns the number of pending transactions, it is the number of transactions
# which have been started but not stopped.
# ------------------------------------------------------------------------
sub pending_transaction {
	my ( $Self, $transaction ) = @_;

	return scalar( %{ $Self->{'start'} } );
}

# ------------------------------------------------------------------------
# method: start_request
#
# Register the start time of a request.
# ------------------------------------------------------------------------
sub start_request {
	my ( $Self, $transaction ) = @_;
	
    $Self->{'Logger'}->debug("start_request(" . $transaction . ")");

	die "transaction $transaction already started"
	  if ( exists( $Self->{'start'}->{$transaction} ) );
	$Self->{'start'}->{$transaction} = gettimeofday();
}

# ------------------------------------------------------------------------
# method: stop_request
#
# Register the stop time of a request
# ------------------------------------------------------------------------
sub stop_request {
	my ( $Self, $transaction ) = @_;

    $Self->{'Logger'}->debug("stop_request(" . $transaction . ")");

	die "transaction $transaction not started, cannot be stopped"
	  unless ( exists( $Self->{'start'}->{$transaction} ) );
	my $time = gettimeofday - $Self->{'start'}->{$transaction};

	$Self->{'total_time'} += $time;
	$Self->{'transaction_number'}++;

	if ( exists( $Self->{'min_time'} ) ) {
		if ( $time < $Self->{'min_time'} ) {
			$Self->{'min_time'} = $time;
		}
	}
	else {
		$Self->{'min_time'} = $time;
	}

	if ( exists( $Self->{'max_time'} ) ) {    
		if ( $time > $Self->{'max_time'} ) {
			$Self->{'max_time'} = $time;
		}
	}
	else {
		$Self->{'max_time'} = $time;
	}
}

# ------------------------------------------------------------------------
# method: stop_sequence
#
# Register the stop time of a sequence
# ------------------------------------------------------------------------
sub stop_sequence {
	my ($Self) = @_;

    $Self->{'Logger'}->debug("stop_sequence(" . ")");

	$Self->{'stop_time'} = gettimeofday;
}

1;
