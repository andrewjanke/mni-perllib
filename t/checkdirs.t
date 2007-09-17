#! /usr/bin/env perl

use warnings "all";

# test program for the following routines from MNI::FileUtilities:
#   check_output_dirs
#   check_output_path
#   check_input_dirs

# N.B. this must be run from the distribution directory, i.e. the
# parent of `t'!

use MNI::FileUtilities qw(:check);

my $i = 0;
sub test { printf "%s %d\n", ($_[0] ? "ok" : "not ok"), ++$i; }

print "1..42\n";

# Load up code common to all FileUtilities test programs
require "t/fileutil_common.pl";
sub warning;

# test check_output_dirs -- simple stuff
test (check_output_dirs ('t'));
test (! check_output_dirs ('t/foo/bar'));
test (warning =~ /couldn't create/);
test (check_output_dirs ('t/foo/'));
rmdir 't/foo' or die "couldn't rmdir t/foo: $!\n";

# conflict with existing file (not a directory)
test (! check_output_dirs ('/dev/null'));
test (warning =~ /already exists but is not a directory/);

# existing directory, but can't write to it (test only makes
# sense for ordinary users, as superuser can write anywhere)
if ($< != 0)
{
   test (! check_output_dirs ('/'));
   test (warning =~ /is a directory but not writeable/);
   test (! check_output_dirs ('/foo'));
   test (warning =~ /couldn\'t create/);
}
else
{
   test (1);                            # to keep number of tests constant
   test (1);
}

# conflict with dangling link
symlink ('t/barf', 't/foo') || die "couldn't create symlink t/foo: $!\n";
test (! check_output_dirs ('t/foo'));
test (warning =~ /already exists but is not a directory/);
unlink ('t/foo') || die "couldn't delete t/foo: $!\n";

# check_output_path -- relative paths
test (check_output_path ('t'));
test (check_output_path ('t/'));
test (check_output_path ('t/foo/') && -d 't/foo' && -w 't/foo');
rmdir 't/foo' or die "couldn't rmdir t/foo: $!\n";
test (check_output_path ('t/foo/bar') && -d 't/foo' && -w 't/foo');
rmdir 't/foo' or die "couldn't rmdir t/foo: $!\n";
test (check_output_path ('t/foo/bar/') && -d 't/foo' && -d 't/foo/bar' && -w 't/foo/bar');
rmdir 't/foo/bar' or die "couldn't rmdir t/foo/bar: $!\n";
rmdir 't/foo' or die "couldn't rmdir t/foo: $!\n";

# check_output_path -- absolute paths
test (check_output_path ('/tmp/'));
test (check_output_path ('/tmp/foo'));
test (check_output_path ('/tmp/foo/bar/baz/zip') &&
      -d '/tmp/foo' && -d '/tmp/foo/bar' && 
      -d '/tmp/foo/bar/baz' && -w '/tmp/foo/bar/baz');

# check_output_path -- absolute path with errors
if ($< != 0)
{
   test (! check_output_path ('/'));
   test (warning =~ /not a writeable directory/);
   test (! check_output_path ('/foo'));
   test (warning =~ /not a writeable directory/);
   test (! check_output_path ('/foo/'));
   test (warning =~ /not a writeable path: couldn\'t create/);
}
else
{
   test (1);
   test (1);
   test (1);
   test (1);
   test (1);
   test (1);
}

test (! check_output_path ('/dev/null/foo'));
test (warning =~ /not a writeable directory/);
test (! check_output_path ('/dev/null/foo/'));
test (warning =~ /is not a directory/);

# check_input_dirs
test (check_input_dirs ('t'));
test (check_input_dirs ('t/'));
test (check_input_dirs ('/tmp'));
test (check_input_dirs ('/tmp/'));
test (! check_input_dirs ('MiscUtilities.pm'));
test (warning =~ /exists but is not a directory/);
test (! check_input_dirs ('t/checkdirs.t'));
test (warning =~ /exists but is not a directory/);
test (! check_input_dirs ('foo'));
test (warning =~ /does not exist/);
test (! check_input_dirs ('/foo'));
test (warning =~ /does not exist/);

