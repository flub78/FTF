Another example of test suite;;;;;;;;;;;
Ouput directory;run1;;;;;;;;;;
Host;:2345;;;;;;;;;;
Test cases definition;;;;;;;;;;;
Engine;Scenario;TestId;Synopsis;output;fail;iteration;perf;memory;host;selected;requirements
perl;test1.pl;TEST1;T1 Smoke test check;run1;;1;;;;1;R1, R2, R47
perl;test1.pl;TEST2;T1 Failed test;run1;1;1;;;;;
perl;test1.pl;TEST3;T1, performance, 10 iterations;run1;;10;1;;;;
perl;test1.pl;TEST4;T1, performance, 100 iterations;run1;;100;1;;;1;R1, R17
perl;test1.pl;TEST5;T1, robustness, 10 iterations;run1;;10;;1;;;
perl;test1.pl;TEST6;T1, robustness, 10 iterations;run1;;100;;1;;;
perl;test2.pl;TEST7;T2 Smoke test check;run1;;1;;;;;
perl;test2.pl;TEST8;T2 Failed test;run1;1;1;;;;;
perl;test2.pl;TEST9;T2, performance, 10 iterations;run1;;10;1;;;1;R1, R12, R42
perl;test2.pl;TEST10;T2, performance, 100 iterations;run1;;100;1;;;1;
perl;test2.pl;TEST11;T2, robustness, 10 iterations;run1;;10;;1;;;
perl;test2.pl;TEST12;T2, robustness, 10 iterations;run1;;100;;1;;;
perl;$PTT/templates/ClientTemplate.pl;TEST20;TCP/IP client;run1;;1;;;:2345;;
perl;$PTT/templates/ClientTemplate.pl;TEST21;TCP/IP client, performance;run1;;10;1;;:2345;1;
perl;$PTT/templates/ClientTemplate.pl;TEST22;TCP/IP client,robustness;run1;;10;1;1;:2345;;
