# ----------------------------------------------------------------------------
# Title:  Class FiboSequence
#
# Source - <file:../FiboSequence.pm.html>
#
# Abstract:
#
#       Fibonnaci server test, message sequence manager.
#       
#       Object of this class are responsible of defining the message to send
#       to a Fibonnaci server to test it. They are also responsible ot the control
#       of the reply.
#
#       This class has a window attributes, it is the number of messages
#       that can be sent in advance before to wait have answers for the
#       the previous requests.
# ------------------------------------------------------------------------
package FiboSequence;

use strict;
use vars qw($VERSION @ISA @EXPORT);

use Sequence;
use Log::Log4perl;
use Data::Dumper;

$VERSION = 1;

@ISA = qw(Sequence);

# ------------------------------------------------------------------------
# routine: fibo
#
# Compute the Fibonnaci value. Around 2 sec for fibo(30). This method is
# used to check values returned by the server.
# ------------------------------------------------------------------------
sub fibo {
	my $n = shift;

	if ( ( $n == 0 ) || ( $n == 1 ) ) {
		return 1;
	}
	else {
		return fibo( $n - 1 ) + fibo( $n - 2 );
	}
}

# ------------------------------------------------------------------------
# method: _init (private)
#
# Initialisation of the object. Do not call directly.
# ------------------------------------------------------------------------
sub _init {
	my $Self = shift;

	$Self->Sequence::_init(@_);
	$Self->{'counter'} = $Self->{'min'};
}

# ------------------------------------------------------------------------
# method: next_message
#
# Returns the next message to send or undef when no message is to send.
# Undef can be returned when the sequence is over or when the ahead message
# window has been reached.
#
# This method also starts the request stop watch.
# ------------------------------------------------------------------------
sub next_message {
	my $Self = shift;

    $Self->{'Logger'}->trace("next_message");
    
	# we have reached the limit of the window
	if ( $Self->{'messages_sent'} - $Self->{'messages_received'} >
        $Self->{'window'} ) {
        $Self->{'Logger'}->trace("next_message, end of window");
        return undef;    
    }

	# limit of the number of messages
    if ( $Self->{'messages_sent'} >= $Self->{'number'} ) {
        $Self->{'Logger'}->trace("next_message, end of sequence");
        return undef;
    }
	$Self->{'messages_sent'}++;
	my $cnt = $Self->{'counter'}++;

	$Self->start_request($cnt);
	return "$cnt\n";
}

# ------------------------------------------------------------------------
# method: check_reply
#
# Register a received message, checks its validity, and stop the request
# stop watch.
# ------------------------------------------------------------------------
sub check_reply {
	my ( $Self, $msg ) = @_;

	my $test = $Self->{'test'};
	$Self->{'messages_received'}++;

	chomp($msg);
	my ( $int, $result );
	if ( $msg =~ /fibo \((\d+)\) = (\d+)/ ) {
		$int    = $1;
		$result = $2;
		$Self->stop_request($int);
		my $expected = fibo($int);
		$test->is( $result, $expected, "fibo($int) = $expected" );
		if ( $result != $expected ) {
			$Self->{'errors'}++;
		}
	}
	else {    
		$test->ok( 0, "unrecognized message: $msg" );
		$Self->{'errors'}++;
	}

}

# ------------------------------------------------------------------------
# method: is_completed
#
# Returns true when the sequence is completed, it means when all messages
# to send have been sent and all expected replies have been received.
# ------------------------------------------------------------------------
sub is_completed {
	my $Self = shift;

	$Self->{'Logger'}->trace(
"is_completed, sent=$Self->{'messages_sent'}, received=$Self->{'messages_received'}"
	);

	return 0 if ( $Self->{'messages_sent'} != $Self->{'messages_received'} );
	return 0 if ( $Self->{'messages_received'} < $Self->{'number'} );
	
	$Self->{'Logger'}->trace("is_completed == true");
	$Self->stop_sequence();
	return 1;
}

1;
