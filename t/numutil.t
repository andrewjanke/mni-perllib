#!/usr/local/bin/perl5 -w

use MNI::NumericUtilities qw(:all);

my $i = 0;
sub test { printf "%s %d\n", ($_[0] ? "ok" : "not ok"), ++$i; }

print "1..20\n";


# test in_range (note backwards logic -- might change!)
test (in_range (2, 1, 3)   == 0);
test (in_range (2, 1.5, 2) == 0);
test (in_range (-1, -1, 0) == 0);
test (in_range (-1.001, -1, 0) == -1);
test (in_range (1.001, 0, 1) == +1);

# test labs -- first, array context
@v = (-42, 3.2, 5, 6/-2);
@a = labs (@v);
test (@a == @v && $a[0] == 42 && $a[1] == 3.2 && $a[2] == 5 && $a[3] == 3);
$a = labs (@v);
test ($a == 42);
@a = labs (-3.4);
test (@a == 1 && $a[0] == 3.4);
@a = labs (-3.4, 5, -2);
test (@a == 3 && $a[0] == 3.4 && $a[1] == 5 && $a[2] == 2);


# test round: first, some bone-head boundary checks
test (round (2, 2, 0)     == 2);
test (round (2, 1, 1)     == 2);
test (round (2, 2)        == 2);
test (round (2, 2, -1)    == 2);

# next, the promises made in the documentation
test (round (3.25)        == 3);
test (round (3.25, 1)     == 3);
test (round (3.25, 1, 0)  == 3);
test (round (3.25, 5)     == 5);
test (round (3.25, 5, -1) == 0);
test (round (-1.2, 2, +1) == 0);
test (round (-1.2, 2)     == -2);


