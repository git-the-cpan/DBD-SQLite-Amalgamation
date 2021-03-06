#!/usr/bin/perl

# Test that two processes can write at once, assuming we commit timely.

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}

use t::lib::Test;
use Test::More;

BEGIN {
	plan skip_all => 'requires DBI v1.608' if $DBI::VERSION < 1.608;
}

use Test::NoWarnings;

plan tests => 12;

my $dbh = connect_ok(
    RaiseError => 1,
    PrintError => 0,
    AutoCommit => 0,
);

my $dbh2 = connect_ok(
    RaiseError => 1,
    PrintError => 0,
    AutoCommit => 0,
);

ok($dbh2->sqlite_busy_timeout(3000));

ok($dbh->do("CREATE TABLE Blah ( id INTEGER, val VARCHAR )"));
ok($dbh->commit);
ok($dbh->do("INSERT INTO Blah VALUES ( 1, 'Test1' )"));
my $start = time;
eval {
    $dbh2->do("INSERT INTO Blah VALUES ( 2, 'Test2' )");
};
ok($@);
if ($@) {
    print "# insert failed : $@";
    $dbh2->rollback;
}

$dbh->commit;
ok($dbh2->do("INSERT INTO Blah VALUES ( 2, 'Test2' )"));
$dbh2->commit;

$dbh2->disconnect;
undef($dbh2);

pipe(READER, WRITER);
my $pid = fork;
if (!defined($pid)) {
    # fork failed
    skip("No fork here", 1);
    skip("No fork here", 1);
} elsif (!$pid) {
    # child
    my $dbh2 = DBI->connect('dbi:SQLite:foo', '', '', 
    {
        RaiseError => 1,
        PrintError => 0,
        AutoCommit => 0,
    });
    $dbh2->do("INSERT INTO Blah VALUES ( 3, 'Test3' )");
    select WRITER; $| = 1; select STDOUT;
    print WRITER "Ready\n";
    sleep(5);
    $dbh2->commit;
} else {
    # parent
    close WRITER;
    my $line = <READER>;
    chomp($line);
    ok($line, "Ready");
    ok($dbh->sqlite_busy_timeout(10000));
    ok($dbh->do("INSERT INTO Blah VALUES (4, 'Test4' )"));
    $dbh->commit;
    wait;
}
