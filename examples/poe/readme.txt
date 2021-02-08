This directory contains several short examples
or recipes on how to use POE to handles TCP/IP servers and clients. Most of these examples are test oriented.


Required examples:

    * TCP/IP clients and servers
    * with support for ASCII and binary protocol
    * with SSL support
    * with timeout management
    * with high and low level logging
 
    * Command line analysis
    * Log4perl logging
    * Configuration parameter files.
    * Binary Protocol Filters
    * TLV support
    * Scenario and State Machine Automaton
    * Self reporting tests
    * UDP/IP client and servers
    * external programs control
    * C bindings
    * with self documentation libraries

Script:
        Basic TCP/IP connection
        perl poe_tcp_server.pl
        perl poe_tcp_client.pl

        The same with SSL
        perl poe_tcp_server.pl -s 1             (PEM pass phrase = eeeeee)
        perl poe_tcp_client.pl -ssl


       

        


