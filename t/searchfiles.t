#!/usr/local/bin/perl5 -w

# test program for the following routines from MNI::FileUtilities:
#   search_directories
#   find_program
#   find_programs

# N.B. this must be run from the distribution directory, i.e. the
# parent of `t'!

use MNI::FileUtilities qw(:search);

my $i = 0;
sub test { printf "%s %d\n", ($_[0] ? "ok" : "not ok"), ++$i; }

print "1..15\n";

# Load up code common to all FileUtilities test programs
require "t/fileutil_common.pl";
sub warning;

# search_directories
test (search_directories ('checkfiles.t', ['', 't', '/']) eq 't/');
test (search_directories ('checkfiles.t', ['', 't', '/'], '-e && -r') eq 't/');
test (! search_directories ('checkfiles.t', ['', 't', '/'], '-e && -d'));

test (search_directories ('MiscUtilities.pm', ['', 't', '/']) eq './');
test (search_directories ('MiscUtilities.pm', ['', 't', '/'], '-e && -r')
      eq './');
test (! search_directories ('MiscUtilities.pm', ['', 't', '/'], '-e && -d'));

test (search_directories ('MiscUtilities.pm', ['.', 't', '/']) eq './');
test (search_directories ('MiscUtilities.pm', ['.', 't', '/'], '-e && -r')
      eq './');

test (search_directories ('ls', [split (':', $ENV{'PATH'})]));
test (search_directories ('ls', [split (':', $ENV{'PATH'})], '-x'));

test (! search_directories ('foo', ['', 't', '/']));

# find_program
test ($ls = find_program ('ls'));
test ($ls =~ m|[^/]/ls$|);
test (find_program ('ls', $ENV{'PATH'}) eq $ls);
test (find_program ('ls', [split (':', $ENV{'PATH'})]) eq $ls);
