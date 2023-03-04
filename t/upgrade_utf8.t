use utf8;
use strict;
use warnings;
use Test::More;
use DBIx::Oracle::UpgradeUtf8;
use Local::Ctx;



my $dsn = 'DEVCI';
my $ctx = Local::Ctx->new();
my $dbh = $ctx->db->get_dbh($dsn);


my $str        = "il était une bergère";
my $str_native = $str; utf8::downgrade($str_native);
my $str_utf8   = $str; utf8::upgrade($str_utf8);

do_tests(without_callbacks => 'NE');

DBIx::Oracle::UpgradeUtf8::inject_callbacks($dbh, sub {warn @_, "\n"});
do_tests(with_callbacks => 'EQ');

done_testing;



sub do_tests {
  my ($context, $expected) = @_;

  my ($sth, $result);

  my $sql = "SELECT CASE WHEN ?=? THEN 'EQ' ELSE 'NE' END FROM DUAL";


  # direct select from dbh
  ($result) = $dbh->selectrow_array($sql, {}, copies($str_native, $str_utf8));
  is $result, $expected, "[$context: $expected] native = utf8 (selectrow_array)";


  $result = $dbh->selectrow_arrayref($sql, {}, copies($str_native, $str_utf8));
  is $result->[0], $expected, "[$context: $expected] native = utf8 (selectrow_arrayref)";



  # original strings should not have been modified
  ok !utf8::is_utf8($str_native) && utf8::is_utf8($str_utf8), "strings still have different encodings";

  # prepare / execute
  $sth = $dbh->prepare($sql);
  $sth->execute(copies($str_native, $str_utf8));
  ($result) = $sth->fetchrow_array;
  is $result, $expected, "[$context: $expected] native = utf8 (prepare / execute)";

  # prepare / bind_param / execute
  $sth = $dbh->prepare($sql);
  $sth->bind_param(1, copies($str_native));
  $sth->bind_param(2, copies($str_utf8));
  $sth->execute;
  ($result) = $sth->fetchrow_array;
  is $result, $expected, "[$context: $expected] native = utf8 (prepare / bind_param / execute)";



  # interpolated string
  my $sql1 = "SELECT CASE WHEN 'il était une bergère'=? THEN 'EQ' ELSE 'NE' END FROM DUAL";
  utf8::downgrade($sql1);

  # original strings should not have been modified
  ok !utf8::is_utf8($str_native) && utf8::is_utf8($str_utf8), "strings still have different encodings";

  ($result) = $dbh->selectrow_array($sql1, {}, copies($str_utf8));
  is $result, $expected, "[$context: $expected] native = utf8 (interpolated native string)";
  

  my $sql2 = $sql1;
  utf8::upgrade($sql2);

  # original strings should not have been modified
  ok !utf8::is_utf8($str_native) && utf8::is_utf8($str_utf8), "strings still have different encodings";

  ($result) = $dbh->selectrow_array($sql2, {}, copies($str_native));
  is $result, $expected, "[$context: $expected] native = utf8 (interpolated utf8 string)";

  # TODO : bind_param_inout, bind_param_array
}


sub copies {
  my @c = @_;
  return @c;
}
