use IO::Socket;
use IO::Select;

# Create a socket to listen on.
#
my $listener =
  IO::Socket::INET->new( LocalPort => 3456, Listen => 5, Reuse => 1 );

die "Can't create socket for listening: $!" unless $listener;
print "Listening for connections on port 3456\n";

my $readable = IO::Select->new;    # Create a new IO::Select object
$readable->add($listener);         # Add the listener to it

while (1) {

    # Get a list of sockets that are ready to talk to us.
    #
    my ($ready) = IO::Select->select( $readable, undef, undef, 0.01 );
    foreach my $s (@$ready) {

        # Is it a new connection?
        #
        if ( $s == $listener ) {

            # Accept the connection and add it to our readable list.
            #
            my $new_sock = $listener->accept;
            $readable->add($new_sock) if $new_sock;

            print $new_sock "Welcome!\r\n";
        }
        else {    # It's an established connection

            my $buf = <$s>;    # Try to read a line

            # Was there anyone on the other end?
            #
            if ( defined $buf ) {

                # If they said goodbye, close the socket. If not,
                # echo what they said to us.
                #
                if ( $buf =~ /goodbye/i ) {
                    print $s "See you later!\n";
                    $readable->remove($s);
                    $s->close;
                }
                else {
                    print $s "You said: $buf\n";
                }
            }
            else {    # The client disconnected.

                $readable->remove($s);
                $s->close;
                print STDERR "Client Connection closed\n";
            }
        }
    }
}
