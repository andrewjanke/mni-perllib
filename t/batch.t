# test program for MNI::Batch -*- Perl -*-

use strict;
use MNI::Batch qw(:all);
use MNI::Spawn;


print "1..23\n";

my $i = 0;
sub test { printf "%s %d\n", ($_[0] ? "ok" : "not ok"), ++$i; }


my $out = ".out$$";
my $err = ".err$$";

# 1 test
sub start_batchtest {
    unlink( $out, $err );
    test( StartJob( "batch.t.$i", $out, $err, 0 ));
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
    my $sleeptime = 0;
    while( $sleeptime < 30 && (grep {!-f} @_)) {
	sleep( 1 );
	++$sleeptime;
    }
    test( $sleeptime < 30 );
}


MNI::Batch::SetOptions( Queue => 'short', 
		        Execute => 1,
		        Verbose => 1 );

start_batchtest();
QueueCommand( 'echo done' );
end_batchtest( 'done' );

start_batchtest();
QueueCommands( [ 'date', 'echo done' ] );
end_batchtest( 'done' );

{
    my $message;
    local $SIG{'__WARN__'} = sub { $message = $_[0]; };
    QueueCommand( 'echo done', "batch.t.$i", $out, $err, 0 );
    test ( $message =~ /you\'re missing out on a lot of features by using QueueCommand like this/ );
}
wait_for_output( 'done' );

QueueCommands( [ 'hostname', 'echo done' ], "batch.t.$i", $out, $err, 0 );
wait_for_output( 'done' );

MNI::Batch::SetOptions( LocalHost => 1 );
start_batchtest();
QueueCommand( 'hostname' );
chop( $_ = `hostname` );
end_batchtest( $_ );


# Test that sync file gets created
my $syncdir = '/tmp/.batch.t.sync';
MNI::Batch::SetOptions( 'SyncDir' => $syncdir,
                        'Synchronize' => 'finish' );
test( StartJob( "batch.t.$i", undef, undef, 0 ) );
QueueCommand( 'ls' );
wait_for_files( FinishJob() );


# Test StartAfter option
my $syncfile = "$syncdir/startnextjob";
unlink $syncfile;
test( StartJob( "batch.t.$i", undef, undef, 0, StartAfter => $syncfile ));
QueueCommand( 'ls' );
my $finishfile = FinishJob();
sleep( 10 );
test( ! -f $finishfile );
`touch $syncfile`;
die if $?;

# StartAfter tests don't work right ... 
# One often (always?) needs > 30 seconds for the job to complete
# so just forget about testing it.
#
#wait_for_files( $finishfile );
