#!/usr/bin/perl

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

plan tests => 6;

my $N_OPCODES = 50; # how many opcodes before calling the progress handler

# our progress_handler just remembers how many times it was called
my $n_callback = 0;
sub progress_handler {
  $n_callback += 1;
  return 0;
}

# connect and register the progress handler
my $dbh = connect_ok( RaiseError => 1 );
ok($dbh->sqlite_progress_handler( $N_OPCODES, \&progress_handler ));

# populate a temporary table with random numbers
$dbh->do( 'CREATE TEMP TABLE progress_test ( foo )' );
$dbh->begin_work;
for my $count (1 .. 1000) {
  my $rand = rand;
  $dbh->do( "INSERT INTO progress_test(foo) VALUES ( $rand )" );
}
$dbh->commit;

# let the DB do some work (sorting the random numbers)
my $result = $dbh->do( "SELECT * from progress_test ORDER BY foo  " );

# now the progress handler should have been called a number of times
ok($n_callback);


# unregister the progress handler, set counter back to zero, do more work
ok($dbh->sqlite_progress_handler( $N_OPCODES, undef ));
$n_callback = 0;
$result = $dbh->do( "SELECT * from progress_test ORDER BY foo DESC " );

# now the progress handler should have been called zero times
ok(!$n_callback);
