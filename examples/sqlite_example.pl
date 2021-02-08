#!/usr/bin/perl -w

# ------------------------------------------------------------------------------
# Title: SQLite example
#
# Source - <file:../sqlite_example.pl.html>
# Version - 1.0
#
# Abstract:
#
# Small example on sqlite usage.
#
# The first version only insert a value in a pre-existing database.
# A more elaborate project should.
#    - Create the database if it does not exist
#    - Check for existence of a table before to insert something.
#    - Do a little more elaborate SQL queries.
#
# Example:
# (Start code)
#
# $base = DBI->connect( "DBI:SQLite:$database", $user, $password );
# $base->do("insert into responsable values(NULL, \"tutu\");");
#
# $req = $base->prepare("SELECT * FROM responsable;");
# $req->execute;
#
# while ( ( $ir, $nom ) = $req->fetchrow_array ) {
#    print "ir = $ir, nom = $nom\n";
# }
#
# $req->finish;
#
# $base->disconnect;
# (end)
# ------------------------------------------------------------------------------
use DBI;

$database = "projet.db";

# $host = "localhost";
$user     = "";
$password = "";

# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# routine: db_connect
#     Connect to the database create it if required.
# ------------------------------------------------------------------------------
sub db_connect {
    my ( $database, $user, $password ) = @_;

    ( -e $database ) or die "$database does not exist";

    my $base = DBI->connect( "DBI:SQLite:$database", $user, $password );
    return $base;
}

# ------------------------------------------------------------------------------
#
# Main
# ----

$base = db_connect ($database, $user, $password);

$base->do("insert into responsable values(NULL, \"tutu\");");

$req = $base->prepare("SELECT * FROM responsable;");
$req->execute;

while ( ( $ir, $nom ) = $req->fetchrow_array ) {
    print "ir = $ir, nom = $nom\n";
}

$req->finish;

$base->disconnect;

