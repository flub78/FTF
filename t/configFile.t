# ------------------------------------------------------------------------
# Title:  ConfigurationFile Unit Test
#
# File - t/configFile.t
# Version - 1.0
#
# Abstract:
#
#    ConfigurationFile unitary test.
# ------------------------------------------------------------------------
use strict;
use Test::More qw( no_plan );
use lib "$ENV{'FTF'}/lib";
use Log::Log4perl qw(:easy);

use ConfigurationFile;

my $header = "# " . '-' x 76 . "\n";
$header .= "# Configuration file\n";
$header .= "# date = april 9 2008\n";
$header .= "# " . '-' x 76 . "\n";

my $footer = "# end-of-file\n";
$footer .= "# " . '-' x 76 . "\n";
    
# ------------------------------------------------------------------------
# routine: checkGeneratedConfig
#
# Checks a configuration generated from scratch by the test
# ------------------------------------------------------------------------
sub checkGeneratedConfig {
    my $Self = shift;

    # First build a configuration from scratch
    my $cfg = new ConfigurationFile (
        'sections' => ['_anonymous', 'Interfaces'],
        
        'variables' => {
            '_anonymous' => ['cfgName'],
            'Interfaces' => ['cipherSockList', 'Name', 'cryptoDeviceAddresses']
        },
        'values' => {
            '_anonymous' => {
                'cfgName' => "MyName"
            },
            'Interfaces' => {
                'Name' => "_FAKE",
                'cryptoDeviceAddresses' => ['1241', '1242']
            }
        },
    );

    # First subtest
    ok( $cfg, "Aconfig constructor" );
    
    my @sects = @{$cfg->sections()};
    
    # access to existing variables and sections
    is ($sects[0], '_anonymous', 'first section');
    is ($sects[1], 'Interfaces', 'second section');
    is (@sects, 2, 'number of sections');
    
    my @list1 = @{$cfg->variables(undef)};
    is ($list1[0], 'cfgName', 'first variable of the first section');
    
     my @list2 = @{$cfg->variables('Interfaces')};   
    is ($list2[1], 'Name', 'second variable of the second section');
    is (@list2, 3, 'number of variable of the second section');
 
    $cfg->addSection('NewSection'); 
    $cfg->addSection('NewSection'); 
    
    is ($cfg->addVariable('NewSection', 'var1', undef, 1), 1, 'variable creation'); 
    $cfg->addVariable('NewSection', 'var2');
    is($cfg->addVariable(undef, 'var3', undef, 3), 3, 'another variable creation');
    $cfg->addVariable('Interfaces', 'var4');

    $cfg->isString('Interfaces', 'Name', 1);
    
    # Replace [NewSection]var1 by a list
    my $value = $cfg->value('NewSection', 'var1');
    is ($value, 1, 'scalar value ...'); 

    is ($cfg->addVariable('NewSection', 'var1', undef, 2), 2, 'push second element'); 
    is ($cfg->addVariable('NewSection', 'var1', undef, 3), 3, 'push third element'); 
    is ($cfg->eltValue('NewSection', 'var1', 0), 1, 'list[0]'); 
    is ($cfg->eltValue('NewSection', 'var1', 1), 2, 'list[1]'); 
    is ($cfg->eltValue('NewSection', 'var1', 2), 3, 'list[3]');
    $cfg->multiline('NewSection', 'var1', 1); 

    is ($cfg->value ('NewSection', 'var2', 2), 2, 'variable setting');
    
    $cfg->value ('Interfaces', 'var4', 4);

    is ($cfg->value ('NewSection', 'var2'), 2, 'get value of an existing variable');
    is ($cfg->value (undef, 'cfgName'), 'MyName', 'value of a variable from the anonymous section');

    is ($cfg->eltValue ('Interfaces', 'cryptoDeviceAddresses', 0), '1241', 'get element value of an existing variable');
    is ($cfg->eltValue ('Interfaces', 'cryptoDeviceAddresses', 1), '1242', 'get element value of another existing variable');
    is ($cfg->eltValue ('Interfaces', 'cryptoDeviceAddresses', 0, 1243), '1243', 'set element value of an existing variable');
    is ($cfg->eltValue ('Interfaces', 'cryptoDeviceAddresses', 0), '1243', 'get element value after change');

    eval {
        is ($cfg->eltValue ('Interfaces', 'Name', 0), undef, 'indexed access to a scalr');
    };
    is ($cfg->eltValue ('Interfaces', 'cryptoDeviceAddresses', 3), undef, 'get element out of range');
    eval {
        is ($cfg->eltValue ('InXXXterfaces', 'cryptoDeviceAddresses', 1), undef, 'get element unknown section');
    };
    eval {
        is ($cfg->eltValue ('Interfaces', 'cryptoXXXDeviceAddresses', 1), undef, 'get element unknown variable');
    };

    # access to unknown variables
    is ($cfg->value (undef, 'unknown'), undef, 'value of an unknown  variable in the anonymous section');
    is ($cfg->value ('Interfaces', 'unknown'), undef, 'value of an unknown  variable in a known section');
    
    $cfg->header($header);
    
    # is (($cfg->header()), $header, "header value");
    
    $cfg->comment('Interfaces', undef, "\n#  Interface\n");
    $cfg->comment('NewSection', 'var2', "# Variable 2\n");
    
    $cfg->footer($footer);

    # Then save the initial configuration    
    $cfg->save('test.cfg');
}

# ------------------------------------------------------------------------
# routine: checkLoadedConfig
#
# Checks a configuration laoded from a file
# ------------------------------------------------------------------------
sub checkLoadedConfig {
    # Reload it in another configuration
    print "####### Checks on reloaded file #############################################\n";
    my $cfg2 = new ConfigurationFile('filename' => 'test.cfg');
     
    $cfg2->dump(); 
    
    # and check if the loaded configuration matchs the firs one
    ok (! $cfg2->defined("tutu"), "defined for unknown section");
    ok ($cfg2->defined('NewSection'), "defined for known section");
    ok ($cfg2->defined('NewSection', 'var2'), "defined for known variable");
    ok (! $cfg2->defined('NewSection', 'var999'), "defined for unknown variable");

    is ($cfg2->header(), $header, "header value");
    is ($cfg2->comment('Interfaces', undef), "\n#  Interface\n", 'section comment');
    is ($cfg2->comment('NewSection', 'var2'), "# Variable 2\n", 'variable comment');
    is ($cfg2->comment('IntZZZerfaces', undef), undef, 'unknown section comment');
    is ($cfg2->comment('NewSection', 'var2XXX'), undef, 'unknown variable comment');   
    is ($cfg2->footer(), $footer, "footer value");

    is ($cfg2->value ('NewSection', 'var2'), 2, 'get value of an existing variable');
    is ($cfg2->value (undef, 'cfgName'), 'MyName', 'value of a variable from the anonymous section');

    is ($cfg2->eltValue ('Interfaces', 'cryptoDeviceAddresses', 0), '1243', 'get element value of an existing variable');
    is ($cfg2->eltValue ('Interfaces', 'cryptoDeviceAddresses', 1), '1242', 'get element value of another existing variable');
    is ($cfg2->eltValue ('Interfaces', 'cryptoDeviceAddresses', 0, 1244), '1244', 'set element value of an existing variable');
    is ($cfg2->eltValue ('Interfaces', 'cryptoDeviceAddresses', 0), '1244', 'get element value after change');

    eval {
        is ($cfg2->eltValue ('Interfaces', 'Name', 0), undef, 'indexed access to a scalar');
    is ($cfg2->eltValue ('Interfaces', 'cryptoDeviceAddresses', 3), undef, 'get element out of range');
    is ($cfg2->eltValue ('InXXXterfaces', 'cryptoDeviceAddresses', 1), undef, 'get element unknown section');
    is ($cfg2->eltValue ('Interfaces', 'cryptoXXXDeviceAddresses', 1), undef, 'get element unknown variable');
    };

    # access to unknown variables
    is ($cfg2->value (undef, 'unknown'), undef, 'value of an unknown  variable in the anonymous section');
    is ($cfg2->value ('Interfaces', 'unknown'), undef, 'value of an unknown  variable in a known section');
    
    # Check rejection of setting of unknow variables
    eval {    
        $cfg2->value('toto', 'titi', 'tutu');
    };
    eval {
        $cfg2->value('', 'titi', 'tutu');
    };
    eval {
        $cfg2->eltValue('Interfaces', 'tutu', 0, 1);
    };
    
    is ($cfg2->value('Interfaces', 'Name'), "_FAKE", "value a string variable");
    ok ($cfg2->isString('Interfaces', 'Name'), "string function of a string variable");
    ok (!$cfg2->isString('Interfaces', 'var4'), "string function of a non string variable");
    
    my %hash = (
        'Interfaces' => {'Name' => "_NOFAKE",
                              'var4' => '3',
        },
        'NewSection' => {'var1' => 'toto',
            'var1' =>   [1, 1, 1]
        },
    );
    
    my $res = $cfg2->check(%hash);
    ok ($res ne "", "global cheking with differences");

    $cfg2->set(%hash);

    $res = $cfg2->check(%hash);
    ok ($res eq "", "no differences after set");
    
#    Experiment on values with embeeded commas       
#    print $cfg2->eltValue('Interfaces', 'cryptoDeviceAddresses', 0), "\n";
#    print "elementNumber ", scalar(@{$cfg2->value('Interfaces', 'cryptoDeviceAddresses')}), "\n"; 
}

my $static = $ENV{'FTF'} . "/t/static.cfg";
# ------------------------------------------------------------------------
# routine: checkLineNumber
#
# Checks line numbers
# ------------------------------------------------------------------------
sub checkLineNumber {
    # Reload it in another configuration
    my $cfg = new ConfigurationFile('filename' => $static);
     
    is ($cfg->lineNumber(undef, undef), undef, "undef lineNumber");
    is ($cfg->numberOfOccurence(undef, undef), 0, "undef numberOfOccurence");
    
    is ($cfg->lineNumber(undef, 'cfgName'), 5, "lineNumber of an anonymous variable");
    is ($cfg->numberOfOccurence(undef, 'cfgName'), 1, "numberOfOccurence of an anonymous variable");

    is ($cfg->lineNumber('Interfaces', undef), 9, "lineNumber of a section");
    is ($cfg->numberOfOccurence('Interfaces', undef), 1, "numberOfOccurence of a section");
    
    is ($cfg->lineNumber('Interfaces', 'Name'), 11, "lineNumber of a variable inside a section");
    is ($cfg->numberOfOccurence('Interfaces', 'Name'), 1, "numberOfOccurence of a variable inside a section");

    is ($cfg->lineNumber(undef, 'toto'), undef, "lineNumber of an unknown variable");
    is ($cfg->numberOfOccurence(undef, 'toto'), 0, "numberOfOccurence of an unknown variable");
    is ($cfg->lineNumber('titi', undef), undef, "lineNumber of an unknown section");
    is ($cfg->numberOfOccurence('titi', undef), 0, "numberOfOccurence of an unknown section". __LINE__);

    # multiple definition
    my @list = @{$cfg->lineNumber('NewSection', undef)};    
    is ($list[0], 15, "first line number of a section");
    is ($list[1], 23, "second line number of a section");
    is ($cfg->numberOfOccurence('NewSection', undef), 2, "numberOfOccurence of a section present several times");

    @list = @{$cfg->lineNumber('NewSection', "var2")};    
    is ($list[0], 20, "first line number of a variable");
    is ($list[1], 24, "second line number of a variable");
    is ($cfg->numberOfOccurence('NewSection', 'var2'), 2, "numberOfOccurence of a section present several times");

}

# ------------------------------------------------------------------------
# routine: TestMain
#
# Test main routine. It is this method which is executed several times
# when the *-iteration* parameter is more than 1.
# ------------------------------------------------------------------------
 checkGeneratedConfig();
 checkLoadedConfig();
 checkLineNumber();
 
 unlink ('test.cfg');



