use strict;
use warnings;
use Test::More;

use_ok 'DBIx::Oracle::UpgradeUtf8'
  or BAIL_OUT;

diag( "Testing DBIx::Oracle::UpgradeUtf8 $DBIx::Oracle::UpgradeUtf8::VERSION, Perl $], $^X" );

done_testing;




