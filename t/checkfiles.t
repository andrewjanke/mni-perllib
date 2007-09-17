#! /usr/bin/env perl

use warnings "all";

# test program for the following routines from MNI::FileUtilities:
#   check_files
#   test_file

# N.B. this must be run from the distribution directory, i.e. the
# parent of `t'!

use MNI::FileUtilities qw(:check);

my $i = 0;
sub test { printf "%s %d\n", ($_[0] ? "ok" : "not ok"), ++$i; }

print "1..41\n";

# Load up code common to all MNI::FileUtilities test programs
require "t/fileutil_common.pl";
sub warning;

# test_file

test (test_file ('-e', 'FileUtilities.pm') eq 'FileUtilities.pm.gz');
test (! test_file ('-e', 'bleargh'));
test (! test_file ('-e', 'FileUtilities.pm', 0));
test (! test_file ('-e', 'FileUtilities.pm', []));

test (test_file ('-e && -f && ! -x', 'FileUtilities.pm') 
      eq 'FileUtilities.pm.gz');
test (test_file ('-e && -f && -x', 't/checkfiles.t') eq 't/checkfiles.t');
test (test_file ('-e && -f && -x', 't/checkfiles.t', 0) eq 't/checkfiles.t');
test (! test_file ('-l', 't/checkfiles.t'));
test (! test_file ('-l', 't/checkfiles.t', 0));

test (test_file ('-e', 'MiscUtilities', ['pm']) eq 'MiscUtilities.pm');
test (test_file ('-e', 'MiscUtilities.pm.gz') eq 'MiscUtilities.pm');
test (test_file ('-e', 'MiscUtilities', ['pm', 'gz'])
      eq 'MiscUtilities.pm');


# check_files

test (check_files ('MiscUtilities.pm'));
test (check_files ('t/checkfiles.t'));
test (check_files ('MiscUtilities.pm', 't/checkfiles.t'));
test (! check_files ('t'));
test (warning =~ /not a regular file/);
test (! check_files ('/dev/null'));
test (warning =~ /not a regular file/);
symlink ('foo', 'bar') || die "couldn't symlink foo to bar: $!\n";
test (! check_files ('foo'));
test (warning =~ /does not exist/);
test (! check_files ('bar'));
test (warning =~ /is a dangling link/);
unlink ('bar') || die "couldn't unlink bar: $!\n";
$mode = (stat ('MiscUtilities.pm'))[2] 
   || die "couldn't stat MiscUtilities.pm: $!\n";
chmod (0, 'MiscUtilities.pm')
   || die "couldn't chmod MiscUtilities.pm: $!\n";
test (! check_files ('MiscUtilities.pm'));
test (warning =~ /not readable/);
chmod ($mode, 'MiscUtilities.pm')
   || die "couldn't chmod MiscUtilities.pm: $!\n";

@files = ('MiscUtilities.pm', 'FileUtilities.pm');
test (check_files (\@files, ['gz', 'z']));
test (! check_files (\@files, ['pgp']));
test (warning =~ /FileUtilities.pm does not exist/);
test (check_files (\@files, 1));
test (! check_files (\@files));
test (warning =~ /FileUtilities.pm does not exist/);
test (! check_files (\@files), undef);
test (warning =~ /FileUtilities.pm does not exist/);
test (! check_files (\@files), 0);
test (warning =~ /FileUtilities.pm does not exist/);

@ok_files = check_files (\@files, ['gz', 'z']);
test (@ok_files == 2 && 
      $ok_files[0] eq $files[0] && 
      $ok_files[1] eq "$files[1].gz");

@ok_files = check_files (\@files, ['pgp']);
test (@ok_files == 2 && 
      $ok_files[0] eq $files[0] && 
      !defined $ok_files[1]);
test (warning =~ /FileUtilities.pm does not exist/);

@ok_files = check_files (\@files, 1);
test (@ok_files == 2 && 
      $ok_files[0] eq $files[0] && 
      $ok_files[1] eq "$files[1].gz");

@ok_files = check_files (\@files);
test (@ok_files == 2 && 
      $ok_files[0] eq $files[0] && 
      !defined $ok_files[1]);
test (warning =~ /FileUtilities.pm does not exist/);
