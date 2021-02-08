# ------------------------------------------------------------------------
# Title:  ExecutionContext Unit Test
#
# Abstract:
#
#    Test for the execution context management.
#    Execution context is manage by several modules
#    ExecutionContext    - provides information on the script execution context
#    ScriptConfiguration - manages a unified command line and configuration file
#    Log4Perl            - manages the script loggers 
# ------------------------------------------------------------------------
package ContextTest;

use strict;
use lib "$ENV{'FTF'}/lib";
use vars qw($VERSION @ISA @EXPORT);
use Exporter;
use Test;

$VERSION = 1;
@ISA     = qw(Test);

# Test::More is only used to test Perl modules.
use Test::More qw( no_plan );
use Data::Dumper;
use ExecutionContext;
use ScriptConfiguration;

# ------------------------------------------------------------------------
# method: test CLI options
# ------------------------------------------------------------------------
sub cli {
    my ($Self, $cfg) = @_;
  
    # cli values
    ok ($cfg->value("flag1"), "cli flag");
    is ($cfg->value("string1"), "string1", "cli string");
    is ($cfg->numberOfValues ("flag1"), 1, "cli flag number of values");
    is ($cfg->numberOfValues ("string1"), 1, "cli string number of values");
    is ($cfg->numberOfValues ("array1"), 3, "cli array number of values");
    
    my @array = @{$cfg->value("array1")};
    is (join(", ", @array), "7, 8, 9", "cli array value");
    is ($cfg->eltValue("array1", 0), 7, "cli array first element");
    is ($cfg->eltValue("array1", 1), 8, "cli array second element");
    is ($cfg->eltValue("array1", 2), 9, "cli array last element");
    is ($cfg->eltValue("array1", 3), undef, "cli array non existing element");
}

# ------------------------------------------------------------------------
# method: test configuration file options
# ------------------------------------------------------------------------
sub file {
    my ($Self, $cfg) = @_;
    
    # File values
    ok ($cfg->value("flag2"), "file flag \"" .  $cfg->value("flag2") . '"');
    is ($cfg->value("string2"), "string2", "file string");
    is ($cfg->numberOfValues ("flag2"), 1, "file flag number of values");
    is ($cfg->numberOfValues ("string2"), 1, "file string number of values");
    is ($cfg->numberOfValues ("array2"), 3, "file array number of values");
    
    my @array = @{$cfg->value("array2")};
    is (join(", ", @array), "1234, 4567, 9", "file array value");
    is ($cfg->eltValue("array2", 0), 1234, "file array first element");
    is ($cfg->eltValue("array2", 1), 4567, "file array second element");
    is ($cfg->eltValue("array2", 2), 9, "file array last element");
    is ($cfg->eltValue("array2", 3), undef, "file array non existing element");
}

# ------------------------------------------------------------------------
# method: Test default options
# ------------------------------------------------------------------------
sub default {
    my ($Self, $cfg) = @_;

    # default values
    ok ($cfg->value("flag0"), "default flag set");
    ok (!$cfg->value("flag0unset"), "default flag unset");
    is ($cfg->value("string0"), "default string", "default string");
    is ($cfg->numberOfValues ("flag0"), 1, "default flag number of values");
    is ($cfg->numberOfValues ("string0"), 1, "default string number of values");
    is ($cfg->numberOfValues ("array0"), 2, "default array number of values");
    
    my @array = @{$cfg->value("array0")};
    is (join(", ", @array), "1, 2", "default array value");
    is ($cfg->eltValue("array0", 0), 1, "default array first element");
    is ($cfg->eltValue("array0", 1), 2, "default array second element");
    is ($cfg->eltValue("array0", 2), undef, "default array non existing element");
    
}

# ------------------------------------------------------------------------
# method: Test undefined options
# ------------------------------------------------------------------------
sub undefined {
    my ($Self, $cfg) = @_;

    # undefined values
    eval {
        my $flag = $cfg->value("undeclared_parameter");
    };
    if ($@) {
        ok (($@ =~ /unknown param/), "undeclared parameter detected: " . $@); 
    }
    eval {
        my $flag = $cfg->numberOfValues("undeclared_parameter");
    };
    if ($@) {
        ok (($@ =~ /unknown param/), "undeclared parameter detected 2: " . $@); 
    }
    eval {
        my $flag = $cfg->eltValue("undeclared_parameter", 0);
    };
    if ($@) {
        ok (($@ =~ /unknown param/), "undeclared parameter detected 3: " . $@); 
    }    
}

# ------------------------------------------------------------------------
# method: Test script context
# ------------------------------------------------------------------------
sub context {
    my $Self = shift;

    print ExecutionContext::context(), "\n";
    my $ext = ExecutionContext::extension();

    my $expected_path = "$ENV{'FTF'}/t/" . basename() . ExecutionContext::extension();
    is (ExecutionContext::path(), $expected_path, "Expected path = " . $expected_path);
    my $dir = "$ENV{'FTF'}/t/";
    is (ExecutionContext::directory(), $dir, "Expected directory = $dir");
    
    my $conf = ExecutionContext::directory() . ExecutionContext::basename() . '.ini';
    is (ExecutionContext::configFile(), $conf, "configuration file by default");
    $conf = `pwd`; chomp($conf); 
    $conf .= '/' . ExecutionContext::basename() . '.ini';
    
    is (ExecutionContext::configFile($conf), $conf, "configuration file after setting");
    
    my $log = main::logFilename();
    my $expected_log;
    if (exists($ENV{'FTF_LOG'})) {
        $expected_log = $ENV{'FTF_LOG'} . '/' . basename() . '.log'       
    } else {
        $expected_log = basename() . '.log';
    }
  
    is (main::logFilename(), $expected_log, "default log file");    
    $log = "/tmp/log";
    is (main::logFilename($log), $log, "log file after setting");    

    print ExecutionContext::context(), "\n";    
}

# ------------------------------------------------------------------------
# method: TestMain
#
# Test main routine. It is this method which is executed several times
# when the *-iteration* parameter is more than 1.
# ------------------------------------------------------------------------
sub TestMain {
    my $Self = shift;
    
    $Self->context();

    my $cfg = $Self->{'config'};
    
    print $cfg->usage();

    $Self->undefined($cfg);    
    $Self->default($cfg);
    if ($cfg->value('flag1')) {
        # It is a little weird to test the command line only when
        # a command line parameter is activated, but I want all the test
        # to pass without parameters to test the package.   
        $Self->cli($cfg);
    }
    $Self->file($cfg);
}

# ------------------------------------------------------------------------
my $help_header = "perl executionContext.t -flag1 -string1 string1 -array1 7 -array1 8 -array1 9";
my $help_footer = "";

my $configFile = ExecutionContext::configFile();

print "configuration file = " . $configFile . "\n";

# read CLI and configuration file
my $config = new ScriptConfiguration (
    'header'     => $help_header,
    'footer'     => $help_footer,
    'argv'       => \@ARGV,
    'scheme'     => TEST,
    'parameters' => {
        flag0 => {
            type        => "flag",
            description => "CLI flag for test",
            default     => 1
        },
        flag0unset => {
            type        => "flag",
            description => "CLI flag for test",
            default     => 0
        },        
        flag1 => {
            type        => "flag",
            description => "CLI flag for test",
            default     => 0
        },
        flag2 => {
            type        => "flag",
            description => "File flag for test",
            default     => 0
        },
        string0 => {
            type        => "string",
            description => "CLI string for test",
            default     => "default string"
        },
        string1 => {
            type        => "string",
            description => "CLI string for test",
            default     => ""
        },
        string2 => {
            type        => "string",
            description => "File string for test",
            default     => ""
        },
        array0 => {
            type        => "array",
            description => "CLI array for test",
            default     => [1, 2]
        },
        array1 => {
            type        => "array",
            description => "CLI string for test",
            default     => []
        },
        array2 => {
            type        => "array",
            description => "File array for test",
            default     => []
        },                                                                
    },
    'configFile' => $configFile
);

my @argv = @ARGV;

# initialize logger configuration

my $testid = $config->value('testId');

# Variable: test
# To customize: replace by your package name
my $test = new ContextTest(
    loggerName   => "Tests",
    argv => \@argv,
    testId => $testid,
    config => $config,
    iteration => 1,
    match     => [],
    skip => [],
    synopsis => "Test synopsis",
    memory => 0,
    pid => undef,
    performance => undef
);
$test->requirements($config->value('requirements'));

# To customize: replace by your test documentation
$test->doc( "TestId = $testid");
$test->doc( "This test checks that the software works.");
$test->doc( "");
$test->doc( "The programs is started, then several data sets are submitted.");
$test->doc( "Each outputs are checks for conformity.");
$test->doc( "");
$test->doc( "AcceptationCriteria, this is a self reporting test");
$test->doc( "");

$test->requirements( [ 'REQ4' ] );

$test->run();


