# test program for MNI::Batch -*- Perl -*-

# Synchronize() tests.
# We just check the return values.  One hopes that this means
# the routine works, but Synchronize() is a complicated beast.


use strict;
use MNI::Batch qw(:all);
use MNI::Spawn;


print "1..3\n";

my $i = 0;
sub test { printf "%s %d\n", ($_[0] ? "ok" : "not ok"), ++$i; }


my $out = ".out$$";
my $err = ".err$$";

MNI::Batch::SetOptions( queue => 'short', 
		        execute => 1,
		        verbose => 1,
			stdout => $out, 
			stderr => $err,
			merge_stderr => 0,
		      );

MNI::Spawn::RegisterPrograms( [ qw(date echo hostname ls sleep) ] );


# Given two array refs, check that the arrays have the same elements, 
# in any order.
sub test_arrays {
    my( $a, $b ) = @_;

    my $all_ok = scalar(@$a) == scalar(@$b);

    foreach my $elem (@$a) {
	$all_ok = 0 
	  unless grep {$elem} @$b;
    }
    test( $all_ok );
}



my $syncdir = "/tmp/.batch.t.sync.$$";
MNI::Batch::SetOptions( host => 'localhost',
			'syncdir' => $syncdir, 'synchronize' => 'both' );

QueueCommand( 'ls', job_name => 'jobA' );
QueueCommand( 'ls', job_name => 'jobB' );

my ($start) = Synchronize('start',1);
test_arrays( $start, [qw/jobA jobB/] );

my ($finish, $fail) = Synchronize('finish',1);
test_arrays( $finish, [qw/jobA jobB/] );
test_arrays( $fail, [] );


