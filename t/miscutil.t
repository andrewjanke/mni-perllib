#!/usr/local/bin/perl5 -w

use MNI::MiscUtilities qw(:all);

my $i = 0;
sub test { printf "%s %d\n", ($_[0] ? "ok" : "not ok"), ++$i; }

print "1..28\n";

# Test timestamp routine
test (timestamp =~ /^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/);
($sec,$min,$hour,$mday,$mon,$year) = localtime (0);
$local_epoch = sprintf ("%4d-%02d-%02d %02d:%02d:%02d", 
                        $year+1900, $mon+1, $mday, $hour, $min, $sec);
test (timestamp (0) eq $local_epoch);

# Test userstamp routine
test (($user, $host, $dir) = (userstamp =~ /^(\w+) \@ ([\w\.]+) : (\/.*)$/x));
test (userstamp ('XXUSERXX') =~ /^XXUSERXX \@ ${host} : ${dir}$/x);
test (userstamp (undef, 'XXHOSTXX') =~ /^${user} \@ XXHOSTXX : ${dir} $/x);
test (userstamp (undef, undef, '/foo/bar')
      =~ m|^${user} \@ ${host} : /foo/bar $|x);
test (userstamp ('XXUSERXX', 'XXHOSTXX', 'XXDIRXX')
      eq 'XXUSERXX@XXHOSTXX:XXDIRXX');

# Test lcompare and nlist_equal
$ncomp = sub { $_[0] <=> $_[1] };
$scomp = sub { $_[0] cmp $_[1] };
@a = (3,4,5);                           # a is greater
@b = (3,4,4);
test (lcompare ($ncomp, \@a, \@b) == 1);
test (lcompare ($ncomp, \@b, \@a) == -1);
test (lcompare ($ncomp, \@a, \@a) == 0);
test (! nlist_equal (\@a, \@b));
test (nlist_equal (\@a, \@a));

@a = (3,4);                             # b is greater
@b = (3,4,4);
test (lcompare ($ncomp, \@a, \@b) == -1);
test (lcompare ($ncomp, \@b, \@a) == 1);

@a = (3,4,5);                           # a is greater again
@b = (3,4);
test (lcompare ($ncomp, \@a, \@b) == 1);
test (lcompare ($ncomp, \@b, \@a) == -1);
test (lcompare ($ncomp, \@a, \@a) == 0);

@a = split ('', $a = 'abcd');           # b is greater
@b = split ('', $b = 'abce');
test (lcompare ($scomp, \@a, \@b) == ($a cmp $b));
test (lcompare ($scomp, \@b, \@a) == ($b cmp $a));
test (lcompare ($scomp, \@b, \@b) == ($b cmp $b));

@a = split ('', $a = 'abcde');           # a is greater
@b = split ('', $b = 'abcd');
test (lcompare ($scomp, \@a, \@b) == ($a cmp $b));
test (lcompare ($scomp, \@b, \@a) == ($b cmp $a));
test (lcompare ($scomp, \@b, \@b) == ($b cmp $b));

# test make_banner
test (make_banner ("foo!", "x", 10) eq "xx foo! xx\n");

# test shellquote
test (shellquote (qw(foo bar baz)) eq q(foo bar baz));
test (shellquote ('foo', '', ' bar ') eq q(foo '' ' bar '));
test (shellquote ('foo', '*.bla') eq q(foo '*.bla'));
test (shellquote ("foo'bar", q("foo')) eq q("foo'bar" \"foo\'));
