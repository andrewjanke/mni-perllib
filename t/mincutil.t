#! /usr/bin/env perl

use warnings "all";

BEGIN
{ 
   $Execute = 1; 
   $MNI::Startup::StartDir = `pwd`;
   chop ($MNI::Startup::StartDir); 
}

use MNI::FileUtilities 'find_program';
use MNI::MincUtilities ':all';
use MNI::MiscUtilities qw(userstamp timestamp);

require "t/compare.pl";

my $DEBUG = 1;

my $i = 0;
sub test { printf "%s %d\n", ($_[0] ? "ok" : "not ok"), ++$i; }
sub announce { printf "test %d: %s\n", $i+1, $_[0] if $DEBUG }

print "1..22\n";

my ($warning, $have_volume_stats, $have_volume_cog);
{
   local $SIG{'__WARN__'} = sub { $warning = $_[0] };
   $have_volume_stats = find_program ('volume_stats');
   $have_volume_cog = find_program ('volume_cog');
}


my %warned_missing;
sub wrap_test
{
   my ($prog, $have_prog, $code) = @_;;

   if ($have_prog)                      # go ahead and run the test as usual
   {
      test (&$code);
   }
   else
   {
      warn "mincutil.t: couldn't find $prog; " .
           "pretending to pass all tests that depend on it\n"
         unless $warned_missing{$prog};
      $warned_missing{$prog} = 1;
      test (1);
   }
}


die "must run without args\n" if @ARGV;

$testvol = 't/testvol.mnc';
die "$testvol not found\n" unless -e $testvol;

$testcopy = 't/testcopy.mnc';
die "$testcopy already exists\n" if -e $testcopy;

END 
{ 
   unlink $testcopy or warn "couldn't unlink $testcopy: $!\n" 
      if defined $testcopy && -e $testcopy;
}

test (volume_min ($testvol) == 0);
test (volume_max ($testvol) == 10);
@range = volume_minmax ($testvol);
test (flist_equal (\@range, [0, 10]));
#test (@range == 2 && $range[0] == 0 && $range[1] == 10);

wrap_test ('volume_stats', $have_volume_stats, 
           sub { fequal (auto_threshold ($testvol), 2.99213) });

wrap_test ('volume_cog', $have_volume_cog, 
           sub {
              @cog = volume_cog ($testvol);
              flist_equal (\@cog, [2.445926, 19.707161, 14.076544]);
           });

@history = get_history ($testvol);
test (@history == 2 && 
      $history[0] =~ /mincmath -add/ &&
      $history[1] =~ /mincreshape -coronal/);

system ('cp', $testvol, $testcopy) == 0 or die "cp failed";
chmod (0644, $testcopy) == 1 or die "couldn't chmod $testcopy: $!";

$fake_history = sprintf ('[%s] [%s] %s %s',
                         userstamp ('user', 'host', '/foo/bar'),
                         timestamp (75112200),
                         'fakeprog', 'fakeargs');
put_history ($testcopy, $fake_history);
@history = get_history ($testcopy);
test (@history == 1 && $history[0] eq $fake_history);

update_history ($testcopy, 0);
@history = get_history ($testcopy);
test (@history == 2 && 
      $history[0] eq $fake_history &&
      $history[1] =~ /$0/);

put_history ($testcopy, $fake_history);
update_history ($testcopy, 1);
@history = get_history ($testcopy);
test (@history == 1 && 
      $history[0] =~ /$0/);

put_history ($testcopy, $fake_history);
update_history ($testcopy, 0, "ooga booga!");
@history = get_history ($testcopy);
test (@history == 2 && 
      $history[0] eq $fake_history &&
      $history[1] eq "ooga booga!");

volume_params ($testvol, \@start, \@step, \@length, \@dircos, \@dims);
test (flist_equal (\@start, [-5, 2, 20]) &&
      flist_equal (\@step, [1, 2, -1]) &&
      nlist_equal (\@length, [16, 16, 16]) &&
      flist_equal (\@dircos, [1,0,0, 0,1,0, 0,0,1]) &&
      slist_equal (\@dims, [qw(yspace zspace xspace)]));

($order, $perm) = get_dimension_order ($testvol);
test (nlist_equal ($order, [1, 2, 0]) &&
      nlist_equal ($perm, [2, 0, 1]));


# Repeat tests with execution turned off -- should just get dummy values back

$Execute = 0;

@range = volume_minmax ($testvol);
test (flist_equal (\@range, [0, 0]));

test (fequal (auto_threshold ($testvol), 0));

@cog = volume_cog ($testvol);
test (nlist_equal (\@cog, [0, 0, 0]));

volume_params ($testvol, \@start, \@step, \@length, \@dircos, \@dims);
test (nlist_equal (\@start, [0, 0, 0]) &&
      nlist_equal (\@step, [0, 0, 0]) &&
      nlist_equal (\@length, [0, 0, 0]) &&
      nlist_equal (\@dircos, [1,0,0, 0,1,0, 0,0,1]) &&
      slist_equal (\@dims, [qw(xspace yspace zspace)]));

($order, $perm) = get_dimension_order ($testvol);
test (nlist_equal ($order, [0, 1, 2]) &&
      nlist_equal ($perm, [0, 1, 2]));

# Now repeat them again, with a bogus filename -- should act exactly
# the same!

$testvol = 'bogus.mnc';
die "$testvol exists\n" if -e $testvol;
@range = volume_minmax ($testvol);
test (flist_equal (\@range, [0, 0]));

test (fequal (auto_threshold ($testvol), 0));

@cog = volume_cog ($testvol);
test (nlist_equal (\@cog, [0, 0, 0]));

volume_params ($testvol, \@start, \@step, \@length, \@dircos, \@dims);
test (nlist_equal (\@start, [0, 0, 0]) &&
      nlist_equal (\@step, [0, 0, 0]) &&
      nlist_equal (\@length, [0, 0, 0]) &&
      nlist_equal (\@dircos, [1,0,0, 0,1,0, 0,0,1]) &&
      slist_equal (\@dims, [qw(xspace yspace zspace)]));

($order, $perm) = get_dimension_order ($testvol);
test (nlist_equal ($order, [0, 1, 2]) &&
      nlist_equal ($perm, [0, 1, 2]));

# compute_resample_params and compute_reshape_params aren't tested here 
# -- the autocrop test suite should exercise them
# (but eventually I should extract the calls to them from the autocrop
# test suite and put them here, for redundant checking...)
