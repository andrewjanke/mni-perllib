# test program for MNI::Batch -*- Perl -*-

# This set of tests just check option settings, return values
# and the like.  Testing continues in batch-1.t

use strict;
use MNI::Batch qw(:all);
use MNI::Spawn;

MNI::Batch::SetOptions( execute => 0, verbose => 0 );

print "1..21\n";

my $i = 0;
sub test { printf "%s %d\n", ($_[0] ? "ok" : "not ok"), ++$i; }



# Check return values of StartJob, FinishJob, QueueCommands.
# These return filenames for synchronization purposes.
#
my @syncfiles = ();

# Default is no synchronization.
test( !defined(StartJob()) );
@syncfiles = FinishJob();
test( @syncfiles == 2 );
test( !defined($syncfiles[0]) );
test( !defined($syncfiles[1]) );

# Try sync on start only.
test( defined(StartJob( synchronize => 'start' )));
@syncfiles = FinishJob();
test( @syncfiles == 2 );
test( !defined($syncfiles[0]) );
test( !defined($syncfiles[1]) );

# Synch on both (check_status defaults to on, so we get fail file too)
test( defined(StartJob( synchronize => 'both' )));
@syncfiles = FinishJob();
test( @syncfiles == 2 );
test( defined($syncfiles[0]) );
test( defined($syncfiles[1]) );

# Synch on both, check_status off
test( defined(StartJob( synchronize => 'both', check_status => 0 )));
@syncfiles = FinishJob();
test( @syncfiles == 2 );
test( defined($syncfiles[0]) );
test( !defined($syncfiles[1]) );


# Return value of QueueCommands should be (start, finish, fail)
@syncfiles = QueueCommand( 'ls', synchronize => 'both', check_status => 0 );
test( @syncfiles == 3 );
test( defined($syncfiles[0]) );
test( defined($syncfiles[1]) );
test( !defined($syncfiles[2]) );


# In scalar context, FinishJob returns the finish file name
# (make sure the return value has a slash in it, to guard against
# just returning the number of values in the array)
StartJob( synchronize => 'finish' );
my $finishfile = FinishJob();
test( $finishfile =~ m@/@ );

