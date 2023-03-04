package DBIx::Oracle::UpgradeUtf8;
use utf8;
use strict;
use warnings;
use Scalar::Util qw/looks_like_number/;


sub inject_callbacks {
  my ($dbh, $debug) = @_;

  $dbh->{Callbacks}{prepare} = sub {             # ($dbh, $query_string, $attrs) ==> must upgrade $_[1]
    $debug->("prepare callback: $_[1]")    if $debug;
    $debug->("statement will be upgraded") if $debug && !utf8::is_utf8($_[1]);
    utf8::upgrade($_[1]);
    return;
  };

  $dbh->{Callbacks}{ChildCallbacks}{execute} = sub { # ($sth, $bind_val_1, ... $bind_val_n) ==> must upgrade $_[1] to $_[$#_]
    $debug->("execute callback")    if $debug;
    foreach my $i (1 .. $#_) {
      if ($_[$i] && ! ref $_[$i] && ! looks_like_number(($_[$i]))) {
        $debug->("bind value $i will be upgraded") if $debug && !utf8::is_utf8($_[$i]);
        utf8::upgrade($_[$i]);
      }
    }
    return;
  };

  $dbh->{Callbacks}{ChildCallbacks}{bind_param} = sub { # ($sth, $p_num, $bind_val, $attrs) ==> must upgrade $_[2]
    $debug->("bind_param callback ($_[1])")    if $debug;
    if ($_[2] && ! ref $_[2] && ! looks_like_number(($_[2]))) {
      $debug->("bind_param value will be upgraded") if $debug && !utf8::is_utf8($_[2]);
      utf8::upgrade($_[2]);
    }
    return;
  };


  $dbh->{Callbacks}{selectrow_array} = sub {
    $debug->("selectrow_array callback")    if $debug;

    # NOTE = $_[1] (the SQL statement) goes through prepare(), so no need to handle it here

    foreach my $i (3  .. $#_) { # starting at first bind value
      if ($_[$i] && ! ref $_[$i] && ! looks_like_number(($_[$i]))) {
        $debug->("bind value $i will be upgraded") if $debug && !utf8::is_utf8($_[$i]);
        utf8::upgrade($_[$i]);
      }
    }
    return;
  };


}



sub inject_callback {
  my ($hash, $key, $coderef) = @_;
  
  my $previous_cb = $hash->{$key};

  my $new_cb = $previous_cb ? sub {&$coderef; &$previous_cb} # TOFIX
                            : $coderef;
  $hash->{$key} = $new_cb;
}

1;


__END__

TODO:
selectrow_array
selectrow_arrayref
selectrow_hashref
selectall_arrayref
selectall_array
selectall_hashref
selectcol_arrayref
  prepare
  prepare_CACHED




  bind_param
bind_param_inout
bind_param_array
execute
execute_array
execute_for_fetch
last_insert_id
fetchrow_arrayref
fetchrow_array
fetchrow_hashref
fetchall_arrayref
fetchall_hashref
finish
rows
bind_col
bind_columns


foreach my $func (qw/
    prepare do statistics_info begin_work commit rollback
    selectrow_array selectrow_arrayref selectall_arrayref
    selectall_hashref
/)
foreach my $func (qw/execute execute_array execute_for_fetch/) {


=encoding utf8

=head1 NAME

DBIx::Oracle::UpgradeUtf8 - Automatically upgrade Perl strings to utf8 before sending them to DBD::Oracle

=head1 SYNOPSIS

  use DBI;
  use DBIx::Oracle::UpgradeUtf8;
  
  my $dbh = DBI->connect(@oracle_connection_params); # see L<DBD::Oracle> for details
  DBIx::Oracle::UpgradeUtf8::inject_callbacks($dbh);
  
  my $str        = "il était une bergère";
  my $str_native = $str; utf8::downgrade($str_native);
  my $str_utf8   = $str; utf8::upgrade($str_utf8);
  
  # The line below returns true, thanks to the callbacks.
  # Otherwise it returns false because the server version of $str_native is corrupted.
  my ($are_equal) = $dbh->selectrow_array("SELECT ?=? FROM DUAL", {}, $str_native, $str_utf8);




=head1 DESCRIPTION

According to the L<DBI> documentation :

=over

    Perl supports two kinds of strings: Unicode (utf8 internally) and
    non-Unicode (defaults to iso-8859-1 if forced to assume an
    encoding). Drivers should accept both kinds of strings and, if
    required, convert them to the character set of the database being
    used. Similarly, when fetching from the database character data that
    isn't iso-8859-1 the driver should convert it into utf8.

=back

But L<DBD::Oracle> doesn't do the full job (as of v1.83) : when the environment
variable C<NLS_LANG> specifies Unicode for the database character set :

=over

=item *

strings I<coming from the database> are properly flagged as utf8

=item *

Perl Unicode strings are properly sent to the database

=item *

Perl non-Unicode strings (without the utf8 flags) are B<not>
encoded into utf8 before being sent to the database. As a result,
characters in range 126-255 in native strings are not properly
treated on the server side.

=back.

This problem should really be fixed within L<DBD::Oracle>, but
I do not have enough knowledge about its internals to be able
to propose a pull request. The present module


