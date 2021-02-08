# ------------------------------------------------------------------------
# Title:  Minimal UDP broadcaster Example
#
# File - <file: ../udp_send.pl.html>
# Version - 1.0
#
# Abstract:
# 
#   Small UDP broadcaster
# ------------------------------------------------------------------------
use IO::Socket;

my $handle = IO::Socket::INET->new(Proto => 'udp') 
    or die "socket: $@";     # yes, it uses $@ here

my $HOSTNAME = 'localhost';
my $PORTNO = 12345;

my $ipaddr   = inet_aton($HOSTNAME);
my $portaddr = sockaddr_in($PORTNO, $ipaddr);

for (my $i = 0; $i < 10; $i++) {

    my $msg = "msg $i";

    print "sending $msg\n";

    send($handle, $msg, 0, $portaddr) 
        or die "cannot send to $HOSTNAME($PORTNO): $!";

    select (undef, undef, undef, 0.5);

}
print "end\n";
