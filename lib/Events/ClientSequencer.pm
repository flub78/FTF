# ----------------------------------------------------------------------------
# Title: Class ClientSequencer
#
# Author - frederic
#
# Name:
#
#    package ClientSequencer
#
# Abstract:
#
#    The TCP/IP client ClientSequencer just activates and runs
#    a message sequence. In fact all the logic of most TCP/IP
#    clients tests and simulators are handled by their
#    message sequence, so this client has just a reference to
#    a few configuration objects and activates the sequence.
#
# Usage:
# (Start code)
# my $client = new Events::ClientSequencer(
#    loggerName => "Network",
#    codec => $codec,
#    block_size => $block_size,
#    sequence => $seq,
#    test => $Self);
# (end)
# ----------------------------------------------------------------------------
package Events::ClientSequencer;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

use Events::Socket;
use Data::Dumper;

$VERSION = 1;

@ISA = qw(Events::Socket);

# ----------------------------------------------------------------------------
# method: connected
#
#    Callback activated when the communication with the peer has been
#    established. You should overload this method to send the first message
#    of the communication.
# ----------------------------------------------------------------------------
sub connected {
    my ($Self) = @_;

    $Self->debug("$Self->{'id'} connected");

    my $seq = $Self->{'sequence'};
    while ( my $msg = $seq->next_message() ) {
        $Self->send($msg);
    }
}

# ----------------------------------------------------------------------------
# method: messageReceived
#
#    Callback activated when a full application message has been received.
#
#    Parameters:
#       $msg - binary buffer truncated to a full and unique application message
# ----------------------------------------------------------------------------
sub messageReceived {
    my ( $Self, $msg ) = @_;

    my $seq = $Self->{'sequence'};

    $Self->debug("Sequence message received");

    # process received messages
    $seq->check_reply($msg);

    # send the messages to send
    while ( my $msg = $seq->next_message() ) {
        $Self->send($msg);
    }

    if ( $seq->is_completed() ) {
        $Self->close();

        if ( exists( $Self->{'test'} ) ) {
            my $tst = $Self->{'test'};
            $tst->{'transaction_number'} += $seq->{'transaction_number'};
            $tst->{'window'}             += $seq->{'window'};
            $tst->{'messages_sent'}      += $seq->{'messages_sent'};
            $tst->{'messages_received'}  += $seq->{'messages_received'};
            $tst->{'errors'}             += $seq->{'errors'};

            $tst->{'total_time'} += $seq->{'total_time'};

            if ( $seq->{'max_time'} > $tst->{'max_time'} ) {
                $tst->{'max_time'} = $seq->{'max_time'};
            }
            if ( $tst->{'min_time'} ) {
                if ( $seq->{'min_time'} < $tst->{'min_time'} ) {
                    $tst->{'min_time'} = $seq->{'min_time'};
                }
            }
            else {
                $tst->{'min_time'} = $seq->{'min_time'};
            }

        }

    }
}

1;
