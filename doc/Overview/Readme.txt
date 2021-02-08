Title: Fred's Test Framework
############################

       Perl modules for component testing.

       File - doc/Overview/Readme.txt
       Date - Winter 2010

Section: Objectives
###################

        This project contains a set of Perl modules, templates and documentation to speed up and make easier the development of test tools.

        - Simulators
        - Data injectors and analyzers.
        - Automated test suites.

    The main idea is to provide tests, scripts, TCP/IP clients and servers
    that already make things close of what you have to do in real situation.
    Using the provided service libraries you should be able to quickly adapt
    the templates and develop quickly powerful and flexible tests.
    
	It is the third generation. The first one was in Tcl. The second one
	has been rewritten in Perl and included reports generation.
	
	Initially the third generation should have been organized around a 
	centralized data model. The idea was to to manage a test database to handle all information
	related to the test and to provide tools and library to feed
	the database and fetch information. 

	This new feature should make the Framewok even more flexible and powerful.
	Obviously, all previous features will still be supported and will
	stay as simple to use.

	The goal is for you to stop to worry about word documents or test logs
	and start to manage business objects. The whole thing will be organized
	around a data model with specialized importers and exporters.

	I want however the database to be optional, the related data should 
	be storable into a MySQL database, a SQLlite database, a set of XML or
	ASCII files. To insure the compatibility with previous version I also
	want the importer and exporter to be usable by themselves without
	database. It should still be possible to generate a test report from 
	the log files.

        The toolbox purpose is:

        - to increase the test coverage
        - to increase the percentage of automatic tests
        - to speed up the development of test tools
        - to make the test reporting easier 

        It is a "framework" because even if each individual component can be used alone, they have been designed to be used together. It is by combining several of these components that you will get the full power and flexibility of the toolbox.  

Section: Project Status

#######################


The toolbox has already been successfully used in several projects.


Section: Principles
###################

        Development of this toolbox is leaded by some strong
        principles. It is possible to make other choices, that would
        imply a different toolbox. These principles are used
        to drive the development but also to determine what to exclude
        from the toolbox.

Usage of a powerful script language:
------------------------------------

High level scripting languages are very efficient for the development of small to medium applications. A high level scripting language must support object oriented programming, have a lot of facilities to handle system concepts like files, sockets, etc and must have an active community to give access to large repository of packages and modules. 

Unix shells or Windows batch command language are are not powerful enough in this context. It is very difficult to do anything not trivial with these languages. 

On the other end of the range, high level compiled languages usually require more time to develop simple tests. 


Modularity:
----------- 

In this environment it is possible to select the modules that you want to use. In the past we have lost significant development efforts by lack of modularity. If at some point, for any reason, one of the modules of a monolithic system stopped to be available the whole set becomes unusable.

Independence from development framework: 

Automated tests:
----------------

There are a lot of cases where development of an automated test is not really more complicated than a non automated test. If you have the right tools it can even become as simple, it is the purpose of this toolbox. And by using automated tests, you save a lot of time during test campaigns.


Embedded documentation:
----------------------- 

This principle has been experimented. By embedding the documentation inside the tests you can more easily keep the documentation up-to-date. So we intend to limit the amount of documentation provided bu use embedded documentation for the test method description, the modules and services provided and the project test suite. This way API documentation and test plan will be automatically extracted from the test suites. 

Our current choice to do that is NaturalDocs. The document that you are reading has been written in NaturalDocs format. 

NaturalDocs have some strength
            - Support for a lot of languages including C, C++, Ada, Perl and Tcl.
            - very natural marking language. For someone who does not know, it is hard to notice than a source has been annotated for NaturalDocs.
            - Quite good looking generated documentation

and a few weaknesses
            - Some limitations on the structure of the generated documentation
            - A limited set of back-ends, currently only HTML is supported.


No scenario specification language:
-----------------------------------

I was against this idea for the following reason :

- The definition of a scenario definition language powerful enough for our needs is as complex than the design of a regular programming language.

- I did not find third-party tools doing that for a reasonable price with the required features. Furthermore we want to stay in control of our component testing.
- Already existing programming languages have most of the features required for a powerful scenario description language.

- Regular programming languages can be completed by the development of modules to describe the test scenarios.


Robustness:
-----------

	- Each supplied modules should come with its own test suite.

Economy of development resources:
---------------------------------

	Solutions faster and easier to developed have always been
	chosen over more complete but more expensive solutions. The
	main reason is that the toolbox is developed on demand, every
	feature is added when a project need it to develop its test suite.

Section: Product structure
##########################

        Here is the description of what you will find in the toolbox.

	 - the documentation
	 - a set of libraries
	 - some templates
	 - some tools.
         - the unitary tests for the supplied modules
         - the on line documentation, including the recommendations for some standard Perl modules.

Documentation:
--------------

	Most of the documentation will be generated using NaturalDocs. The
	page that you are reading has been written for NaturalDocs.

	It is the best trade-off that we have found between the level
	of effort required to write and maintain the documentation and
	its look. 

	Natural Docs is an open-source, extensible, multi-language documentation generator. You document your code in a natural syntax that reads like plain English.  Natural Docs then scans your code and builds high-quality HTML documentation from it.

	Existing words documents and documents too complex to be
	written in NaturalDocs will be referenced and linked from this
	documentation.

Libraries:
----------

	In libraries you will find packages providing specialized services to be used by your test scripts. 

Templates:
----------

	The templates are here as examples, they are also here to structure the development based on this framework. By deriving your scripts from the templates you can guarantee a common look-and-feel to scripts and tests.

You will find templates for :
        - Scripts, tests and packages for homogeneity.

        - services that we provides, like networking support, or CORBA support.

Scripts:
--------

	The scripts are executable. They provide a service, telnet client, spy, etc.

Examples:
---------

	Examples are not directly ready to use like the scripts, they can
	require more work to be adapted to your needs than templates but they
	can help you to write faster your test programs. We just
	provide a few of them quite representative of the possibilities of the test framework. You will find more on the WEB.

Standard packages:
------------------

	 You will find in this documentation some recommendation for standard or CPAN packages. We do not want to develop anything when wee can find something from an external sources that fit our needs. The policy about the level of testing, documentation and templates that we will provide on these modules is still to be determined.   


Section: Configuration management
#################################


The toobolx is managed under SVN on https://www.prosvn.org/flubber/devtools/Perl/STB


Section: Operating System Support
#################################

	 Most Perl only modules should run on any machine on which Perl is available.  
	 Some packages which include C modules may be not portable or available on all platforms.

Linux: 

       - Full support

Windows:
	- Even if it is not an official target most scripts and
	modules are known to work on Windows.
	
	- The scripts based on Event do not work.

   
Section: Distribution
######################

This section describes the distribution and provides installation instructions. 

- There is no packaging support for the development version. Check it out from SVN and use it without installation.

Some attempts have been done to make the development toolbox available as a standard Perl Module. It works but is not supported.
To install a CPAN module just use the commands.

(start code)
unzip the_module.tar.Z
# untar it
tar xvf - < the_module.tar
# build it
perl Makefile.PL
make
 
# test it
make test

# and install it
make install 
(end code)

Environment Variables:
###########

The toolbox supplies a library.
To be able to use the modules of the library, the environment variable *STB* must be defined. It's the directory where the library is located.

Required CPAN Modules:

The following CPAN modules and their dependencies must be installed :

- HTTP::Daemon
- Log::Log4perl
- Test::More
- Test::Simple
- Test::Harness
- XML::Parser
- XML::Twig
- DBI
- SQLite::DB

Section: ToDo list
##################

This section is both a to do list and a wish list. Some items will actually be implemented, others will stay in the wish list forever. I'll try to maintain the list globally in decreasing priority order but priorities can change at any time. Even something quite close of the top of the list can see its priority suddenly drop, just because it was intended for support testing of a project which has been dropped or because another project has more urgent test needs.

Section: Coding rules
#####################

Toolbox coding standards:

    Here are the rule used for the toolbox development.
    
	- Use NaturalDocs to document scripts and APIs. I used to put a Readme.txt in each
	directory to describe its contents and some activation examples. This documentation
	is easier to maintain in the script and module themselves.

	- Class names start with an upper case letter

	- method names start with a lowercase letter
	- Method names use camel case style

	- use Class.pm as templates for you classes.
	- Code source must be included in the HTML documentation for examples and templates (not for other types of code)
	







