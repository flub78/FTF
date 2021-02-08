#!/usr/bin/perl
# server
use strict;
use IO::Socket::Multicast;

use constant DESTINATION => '226.1.1.2:2000'; 
my $sock = IO::Socket::INET->new(Proto=>'udp',PeerAddr=>DESTINATION);

while (1) {
    my $message = localtime;
    $message .= "\n" . `who`;
    $message = `date`;
    $sock->send($message) || die "Couldn't send: $!";
} continue {
    sleep 10;
}
