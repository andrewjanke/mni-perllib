# test program for MNI::Batch -*- Perl -*-

use strict;
use MNI::Batch qw(:all);
use MNI::Spawn;


print "1..19\n";

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

MNI::Spawn::RegisterPrograms( [ qw(date echo hostname ls) ] );


# 0 tests
sub start_batchtest {
    unlink( $out, $err );
    StartJob( job_name => "batch.t.$i" );
}

# 3 tests
sub end_batchtest {
    FinishJob();
    wait_for_output( @_ );
}

# 3 tests
sub wait_for_output {
    my $expected_output = shift;

    wait_for_files( $out, $err );

    chop( $_ = `tail -1 $out` );
    test( $_ eq $expected_output );
    test( -z $err );

    unlink( $out, $err );
}


# 1 test
sub wait_for_files {
    my $time = 90;
    while ( $time-- > 0 && (grep {!-f} @_) ) {
        sleep(1);
    }
    test( scalar(grep {!-f} @_) == 0 );
}


# 3 tests
start_batchtest();
QueueCommand( 'echo done' );
end_batchtest( 'done' );

# 3 tests
start_batchtest();
QueueCommands( [ 'date', 'echo done2' ] );
end_batchtest( 'done2' );

# 4 tests
# It used to be that using QueueCommand without StartJob/FinishJob resulted
# in a warning.  It no longer does, so we check that.
{
    unlink( $out, $err );
    my $message = '_no_message_';
    local $SIG{'__WARN__'} = sub { $message = $_[0]; };
    QueueCommand( 'echo done', job_name => "batch.t.$i" );
    test ( $message eq '_no_message_' );
}
wait_for_output( 'done' );

# 3 tests
QueueCommands( [ 'hostname', 'echo done3' ], job_name => "batch.t.$i" );
wait_for_output( 'done3' );

# The tests above run on any host, so they are more likely to work than the 
# following tests, which are constrained to run on the localhost.
MNI::Batch::SetOptions( host => 'localhost' );

# 3 tests
# Check that we actually run on the local host!
start_batchtest();
QueueCommand( 'hostname' );
chop( $_ = `hostname` );
end_batchtest( $_ );


# Test that sync files get created
my $syncdir = "/tmp/.batch.t.sync.$$";
MNI::Batch::SetOptions( 'syncdir' => $syncdir, 'synchronize' => 'both' );

# 1 test
my $startfile = StartJob( job_name => "batch.t.$i" );
QueueCommand( 'ls' );
my $finishfile = FinishJob();
wait_for_files( $startfile, $finishfile );


# Test StartAfter option
# Syncfile must start with a slash, else it will be interpreted as a time
# string or job id!
my $syncfile = "$syncdir/startnextjob";
unlink $syncfile;

# 2 tests
StartJob( job_name => "batch.t.$i", start_after => $syncfile );
QueueCommand( 'ls' );
$finishfile = FinishJob();

# The batch daemon checks for "startafter" files with something like a
# five minute granularity, so this only catches if the job started immediately.
sleep( 10 );
test( ! -f $finishfile );

# Now we create the syncfile and wait for the job to complete.
`touch $syncfile`; die if $?;

# I once had a "delayed" jot sitting around for minutes and minutes in the
# short queue, even though the syncfile existed.  After submitting another job
# to the queue, the first job finished promptly!
# Does this help?  
QueueCommand( 'echo dummy command', synchronize => 'none' );

wait_for_files( $finishfile );
`/bin/rm -rf $syncdir`; die if $?
