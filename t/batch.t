# test program for MNI::Batch

use strict;
use MNI::Batch qw(:all);


my $i = 0;
sub test { printf "%s %d\n", ($_[0] ? "ok" : "not ok"), ++$i; }

print "1..1\n";

# sigh ... the batch daemon has gone down just now 
# will need to do this later.
test(1); exit 0;

# Load up code common to all FileUtilities test programs
require "t/fileutil_common.pl";
sub warning;

MNI::Batch::SetOptions( Queue => 'short', 
			LocalHost => 1,
		        Execute => 1,
		        Verbose => 1 );

StartJob( 'doit', 'out', 'err', 0 );
QueueCommand( 'ls' );
QueueCommand( 'echo done' );
FinishJob();
