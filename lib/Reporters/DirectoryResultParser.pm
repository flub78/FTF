# ----------------------------------------------------------------------------
#
# Title: Class Reporters::DirectoryResultParser
#
# Name:
#
#    package Reporters::DirectoryResultParser
#
# Abstract:
#
#    Test results directory parser. After parsing it is possible to query
#    the object about test results.
# ----------------------------------------------------------------------------
package Reporters::DirectoryResultParser;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

use Exporter;
use Log::Log4perl;
use Data::Dumper;
use File::Basename;
use Reporters::TestResultParser;

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

    # Attribute initialization
    $Self->{'filter'} = "";

    # Takes the constructor parameters as object attributs
    foreach my $key ( keys %attr ) {
        $Self->{$key} = $attr{$key};
    }

    $Self->reset();

    # Others initialisation
    if ( -d $Self->{'directory'} ) {
        $Self->scan( $Self->{'directory'} );
    }
    
    # Compare the results found with the TCL
    if (defined($Self->{'test_cases_list'})) {
        my $tcl = $Self->{'test_cases_list'};
        
        foreach my $tst ($tcl->selectedTests()) {
            
            unless (exists ($Self->{'test'}->{$tst})) {
                # No result found in the directory
                $Self->{'totalCount'}++;
                $Self->{'result'}->{ 'NOT_FOUND' }++;
                push( @{ $Self->{'tests'} }, $tst );
                $Self->{'test'}->{$tst} = new Reporters::TestResultParser( 
                    'global' => 'NOT_FOUND', 
                    'expected' => 1,
                    'synopsis' => $tcl->testSynopsis($tst) );
            } else {
                $Self->{'test'}->{$tst}->{'expected'} = 1;
            }
        }
    }
    
    # Generates requirements matrices
    $Self->{'req_list'} = [];
    foreach my $tstName ( @{ $Self->{'tests'} } ) {
        my $tst = $Self->{'test'}->{$tstName};
        my @reqs = split( ", ", $tst->variable("Requirements") );
        foreach my $r (@reqs) {
            if ( exists( $Self->{'requirement'}->{$r} ) ) {
                push( @{ $Self->{'requirement'}->{$r} }, $tstName );
            }
            else {
                $Self->{'requirement'}->{$r} = [$tstName];
                $Self->{'passed'}->{$r}      = 0;
                push( @{ $Self->{'req_list'} }, $r );
            }
            if ( $tst->globalStatus() eq 'PASSED' ) {
                $Self->{'passed'}->{$r}++;      
            }
        }
    }        
}

# ------------------------------------------------------------------------
# method: reset
#
# Initialisation
# ------------------------------------------------------------------------
sub reset {
    my $Self = shift;

    $Self->{Logger}->debug("reset");
    $Self->{'totalCount'}            = 0;
    $Self->{'result'}->{'NOT_FOUND'} = 0;
    $Self->{'result'}->{'ABORTED'}   = 0;
    $Self->{'result'}->{'PASSED'}    = 0;
    $Self->{'result'}->{'FAILED'}    = 0;
    $Self->{'tests'}                 = [];
    $Self->{'requirements'}          = [];
}

# ------------------------------------------------------------------------
# routine: scan
#
#    File or directory treatment
# ------------------------------------------------------------------------
sub scan {
    my ( $Self, $file ) = @_;

    return  if ($file =~ /^\./);
    
    $Self->{Logger}->trace("scan $file");

    if ( -f $file ) {
        $Self->treatfile($file);
    }
    if ( -d $file ) {
        my $dirname = $file;

        eval {
            opendir( my $fh, $dirname ) or die "can't opendir $dirname: $!";
            while ( defined( my $subfile = readdir($fh) ) ) {
                next if ($subfile =~ /^\./);

                # do something with "$dirname/$subfile"
                my $name = $dirname . '/' . $subfile;
                $Self->scan($name);
            }
            closedir($fh);
        };
        if ($@) {
        	print "error = $@\n";
        }
    }
}

# ------------------------------------------------------------------------
# routine: treatfile
#
#    Plain file treatment
# ------------------------------------------------------------------------
sub treatfile {
    my ( $Self, $file ) = @_;

    $Self->{Logger}->trace("treatFile $file");    

    if ( $Self->{'filter'} ne "" ) {
        my $filter = $Self->{'filter'};
        return unless $file =~ /$filter/;
    }

    my ( $base, $dir, $ext ) = fileparse($file);
    
    my @splitted = split( /\./, $base );
    my $basename = $splitted[0];
    $ext = $splitted[ @splitted - 1 ];

    # print "test=$basename, file=$file\n";
    my $tr = new Reporters::TestResultParser( filename => $file );
    $Self->{'totalCount'}++;
    $Self->{'result'}->{ $tr->globalStatus() }++;

    push( @{ $Self->{'tests'} }, $basename );
    $Self->{'test'}->{$basename} = $tr;
}

# ------------------------------------------------------------------------
# method: testResult
#
# Returns the rest result for a test or undef
# ------------------------------------------------------------------------
sub testResult {
    my ( $Self, $tst ) = @_;
    
    if (exists($Self->{'test'}->{$tst})) {
        $Self->{'Logger'}->trace("testResult for $tst");
        return $Self->{'test'}->{$tst}; 
    } else {
        $Self->{'Logger'}->trace("testResult for $tst, not found");
        return undef;
    }
}

1;