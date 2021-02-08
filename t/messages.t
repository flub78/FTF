# ------------------------------------------------------------------------
# Title:  messages
#
# Abstract:
#
#    Unit test for the Messages class
# ------------------------------------------------------------------------
package messages;

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

use Message;

# ------------------------------------------------------------------------
# method: scalar
# ------------------------------------------------------------------------
sub scalar {
    my $Self = shift;

	my $scalar_msg = new Message (value => 42);
    
    ok( $scalar_msg, "Creation of a scalar message" );
    is ($scalar_msg->value(), 42, "value of scalar message");
    is ($scalar_msg->kind(), 'SCALAR', "kind of scalar message");
}

# ------------------------------------------------------------------------
# ------------------------------------------------------------------------
sub list {
    my $Self = shift;

	my $list_msg = new Message (value => [1, 2, 3]);
    is ($list_msg->kind(), 'ARRAY', "kind of list message");

    is ($list_msg->value(0), 1, "first list element");
    is ($list_msg->value(1), 2, "second list element");
    is ($list_msg->value(2), 3, "last list element");
    is ($list_msg->value(+2), 3, "last list element with +");
    is ($list_msg->value('[+2]'), 3, "last list element with []");
    is ($list_msg->value(0x02), 3, "last list element in hexa");
    
    is ($list_msg->value(3), undef, "non existing list element");
    
    $list_msg->value(0, 47);
    is ($list_msg->value(0), 47, "changed first list element");
    is ($list_msg->value(1), 2, "unchanged second list element");
    $list_msg->value(1, 48);
    $list_msg->value(2, 49);
    is ($list_msg->value(1), 48, "changed second list element");
    is ($list_msg->value(2), 49, "changed last list element");
}

# ------------------------------------------------------------------------
# ------------------------------------------------------------------------
sub record {
    my $Self = shift;
	
	my $record_msg = new Message (value => {MOP => 1, PPID => 0x47});
    is ($record_msg->kind(), 'RECORD', "kind of record message");
    is ($record_msg->value('MOP'), 1, "simple record element");
    is ($record_msg->value('PPID'), 0x47, "simple record element (2)");
    
    is ($record_msg->value('UNKNOWN'), undef, "unknown record element (2)");
}

# ------------------------------------------------------------------------
# method: complex, checks complex messages
# ------------------------------------------------------------------------
sub complex {
    my $Self = shift;
	my $complex_msg = new Message (value => {
		PPID => 0x47,
		OP_LIST => [
			{MOP => 3, DATE => {MONTH => 1, DAY => 1, YEAR => 2009}},
			{MOP => 4, DATE => {MONTH => 12, DAY => 25, YEAR => 2009}}
		]
	});

    is ($complex_msg->kind(), 'RECORD', "kind of record message");
    is ($complex_msg->value('PPID'), 71, "scalar value of complex message");
    is ($complex_msg->value('OP_LIST.[1].DATE.MONTH'), 12, "sub value of complex message");

    is ($complex_msg->kind('PPID'), 'SCALAR', "kind of record message 2");
    is ($complex_msg->kind('OP_LIST'), 'ARRAY', "kind of record message 3");
    is ($complex_msg->kind('OP_LIST.[1]'), 'RECORD', "kind of record message 4");
    is ($complex_msg->kind('OP_LIST.[1].MOP'), 'SCALAR', "kind of record message 5");
    is ($complex_msg->kind('OP_LIST.[1].DATE'), 'RECORD', "kind of record message 6");
    is ($complex_msg->kind('OP_LIST.[1].DATE.YEAR'), 'SCALAR', "kind of record message 7");

    $complex_msg->value('OP_LIST.[1].DATE.MONTH', 11);
    is ($complex_msg->value('OP_LIST.[1].DATE.MONTH'), 11, "changed value");

}

# ------------------------------------------------------------------------
# method: complex, checks complex messages
# ------------------------------------------------------------------------
sub modif {
    my $Self = shift;
	my $msg = new Message (value => {
		PPID => 0x47,
		OP_LIST => [
			{MOP => 3, DATE => {MONTH => 1, DAY => 1, YEAR => 2009}},
			{MOP => 4, DATE => {MONTH => 12, DAY => 25, YEAR => 2009}}
		]
	});
	
	$msg->value('TR_NUMBER', 412);
	$msg->value('OP_LIST.[1].DATE.HOUR', 23);
	$msg->value('OP_LIST.[1].DATE.MINUTE', 59);
	$msg->value('OP_LIST.[1].DATE.SECOND', 59);
	
	$msg->push('OP_LIST', {MOP => 5, DATE => {MONTH => 42, DAY => 125, YEAR => 202009}});
	
	print "field_list = " . join (", ", $msg->field_list()) . "\n";
	print "field_list = " . join (", ", $msg->field_list('OP_LIST.[1].DATE')) . "\n";
	# print "field_list = " . join (", ", $msg->field_list('OP_LIST')) . "\n";
	# print $msg->dump(), "\n";
}

# ------------------------------------------------------------------------
# method: TestMain
#
# Test main routine. It is this method which is executed several times
# when the *-iteration* parameter is more than 1.
# ------------------------------------------------------------------------
sub TestMain {
    my $Self = shift;
    $Self->info("TestMain");

    $Self->scalar();
    $Self->list();
    $Self->record();
    $Self->complex();
    $Self->modif();
}

# ------------------------------------------------------------------------
my $config     = new ScriptConfiguration('scheme'     => TEST);

my $testid = $config->value('testId');
my $testid =
  ( $config->value('testId') )
  ? $config->value('testId')
  : ExecutionContext::basename();

my $test = new messages(
    loggerName   => "Tests",
    config => $config
);

$test->run();


