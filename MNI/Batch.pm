# ------------------------------ MNI Header ----------------------------------
#@NAME       : MNI::Batch.pm
#@INPUT      : 
#@OUTPUT     : 
#@RETURNS    : 
#@DESCRIPTION: Routines for interfacing to the UCSF Batch Queuing System,
#              as installed at the BIC.
#@METHOD     : 
#@GLOBALS    : yes, several (but all are kept in the package's namespace)
#              
#@CALLS      : 
#@CREATED    : 95/11/13, Greg Ward
#@MODIFIED   : 98/11/06, Chris Cocosco: -ported from Batch.pm ... (STILL BETA!)
#@VERSION    : 
#-----------------------------------------------------------------------------
require 5.002;

package MNI::Batch;		# just for namespace protection,
				# because we share some globals
				# between subs
use strict;
use vars qw( @ISA @EXPORT_OK %EXPORT_TAGS $ProgramName );

use Exporter;
use Carp;
use MNI::MiscUtilities qw( timestamp userstamp shellquote ); 

@ISA = qw(Exporter);
@EXPORT_OK = qw(StartJob FinishJob Synchronize 
		QueueCommand QueueCommands);
%EXPORT_TAGS = (all => [@EXPORT_OK]);


=head1 NAME

MNI::Batch - execute commands via the UCSF Batch Queuing System

=head1 SYNOPSIS

  use MNI::Batch qw(:all);

  MNI::Batch::SetOptions( queue => 'long', synchronize = 'finish' );

  StartJob( 'Make List', stdout => 'logfile', merge_stderr => 1 );
  QueueCommand( 'ls -lR' );
  QueueCommand( 'gzip *.ps' );
  FinishJob();

  QueueCommands( [ 'mritotal this.mnc this.xfm', 'gzip this.mnc' ] );

  Synchronize( 'finish', 3600, 60, 3600*9 ) 
    or die "jobs took longer than nine hours!";

=head1 DESCRIPTION

F<MNI::Batch> provides a method to submit shell commands to the batch queuing
system.  Commands are sent to the batch system in small sets, termed I<jobs>.  
The commands in a job are all executed sequentially, though many jobs may
be running concurrently.  The job is made up of all the commands submitted
by C<QueueCommand> or C<QueueCommands> between C<StartJob> and C<FinishJob>.
All commands are executed by /bin/sh, or other Bourne-compatible
shell.


=head1 OPTIONS

The following options are used to modify the behaviour of the batch system.
Once set (using C<MNI::Batch::SetOptions>) the options apply to all subsequent
C<StartJob> invocations.

=over 4

=item verbose          

should we echo queue commands and other info?

=item loghandle        

where to echo queue commands and other info

=item execute          

should we actually submit jobs?

=item check_status      

check each submitted command for success?

=item export_tmpdir     

name of temporary directory to create when job is running

=item nuke_tmpdir       

"rm -rf" the tmp dir when job finishes?

=item synchronize      

set to "start", "finish", "both", to create appropriate syncfiles; or
set to undef (default) for no synchronization.

=item syncdir          

directory in which to put synchronization files.  Must be accessible from all
hosts!

=item close_delay

number of seconds to sleep after submitting a job.  Defaults to zero.

=item job_name

string to identify job, passed as B<-J> option to C<batch>; the default is empty.
This option is more usually passed in the call to C<StartJob>.

=item queue            

which queue to run on

=item start_after

specifies that the job will wait for some event before starting -- a
certain time, e.g. "two hours", or a file creation.  Passed as B<-a>
option to C<batch>.

=item localhost        

force to run on local host (unless host option is set)

=item host             

explicitly specified host(s) to run on.  Multiple hosts can be specified
using a space-, comma-, or semicolon-separated list of hostnames

=item restartable      

should job be restarted on crash (B<-R> option)?  Defaults to 1

=item shell            

shell to run under -- must be Bourne-shell compatible!!

=item mail_conditions   

code for B<-m> option; default: 'cr' (crash or resource
overrun only)

=item mail_address      

address to mail to (B<-M> option)

=item write_conditions  

code for B<-w> option; default '' (do not write)

=item write_address     

address to mail to (B<-W> option)

=item stdout

file to which standard output is redirected; default is no redirection.

=item stderr

file to which standard error output is redirected; default is no redirection.

=item merge_stderr

set to 1 to cause error stream to be merged with stdout; must not be used if
stderr is set.

=back

=cut

my %DefaultOptions = ( verbose          => undef,
		       loghandle        => \*STDOUT,
		       execute          => undef,
		       check_status     => 1,
		       export_tmpdir    => '',
		       nuke_tmpdir      => 0,
		       synchronize      => '',
		       syncdir          => "$ENV{'HOME'}/.sync",
		       close_delay      => 0,
		       job_name         => undef,
		       queue            => '',
		       start_after      => undef,
		       localhost        => 0,
		       host             => '',
		       restartable      => 1,
		       shell            => '/bin/sh',
		       mail_conditions  => 'cr', 
		       mail_address     => '',
		       write_conditions => '',
		       write_address    => '',
		       stdout           => undef,
		       stderr           => undef,
		       merge_stderr     => 0,
		     );

my %Options = %DefaultOptions;

=head1 METHODS

=over 4

=cut

# Package-private globals #############################################

# [CC] inspired by (errr, "copied" from ;-) MNI::Spawn.pm 
# MUSING: this idiom appears in MNI::Spawn, and possibly other
# places as well.  Can we abstract something into MNI::Startup?
#
if (defined $main::ProgramName) {
    *ProgramName = \$main::ProgramName;
} else {
    ($ProgramName = $0) =~ s|.*/||;
}   


# We track the process ID of the batch job currently in progress.
# Between StartJob() and FinishJob() calls, this value is the pid of
# the "batch" command currently running (reading commands from standard
# input).  Outside of this, JobPID is set to zero to indicate
# "no job in progress".
#
my $JobPID = 0;


# These two hashes serve to keep track of pending synchronization
# files.  There are three types of such files: for job start, job
# finish, and for job failure.  The caller can use them to block
# either until all jobs have started or until all jobs have finished/failed.

# Map JobPID --> job name
# FIXME: this appears to be an anachronism.  The main of this is in
# generating a syncfile name.  But the syncfile name is remembered in the
# %SyncFiles hash anyway!  The other place this is used, is in Synchronize()
# where we return the set of job names that started or finished/failed.
#
my %JobName = ();

# Map JobPID --> filename hash.  The hash maps a condition
# (one of 'start', 'finish', or 'fail') to the associated sync
# filename.
#
my %SyncFiles = ();


# Input: pid, condition
# Output: synchronizing filename, or undef
#
sub _syncfile_name {
    my( $pid, $cond ) = @_;
    return $SyncFiles{$pid}{$cond};
}


# Input: <nothing>
#
sub _batch_optstring
{
    croak "[internal error]: no arguments expected"
      if @_;

    my $optstring = '';

    $optstring .= " -J $Options{'job_name'}" if $Options{'job_name'};
    $optstring .= " -Q $Options{'queue'}" if $Options{'queue'};
    $optstring .= " -a $Options{'start_after'}" if $Options{'start_after'};

    # MUSING: should we replace option 'localhost' with
    # the ability to translate 'host' eq 'localhost' into "-l" option to batch?
    croak "MNI::Batch: cannot specify both host and localhost"
      if $Options{'localhost'} and $Options{'host'};

    $optstring .= " -l" if $Options{'localhost'};
    if ( $Options{'host'} eq 'localhost' ) {
	$optstring .= ' -l';
    } else {
	foreach ( split( /[\s,;]+/, $Options{'host'})) {
	    $optstring .= " -H $_";
	}
    }

    $optstring .= " -S" if $Options{'restartable'};
    $optstring .= " -s $Options{'shell'}" if $Options{'shell'};
    $optstring .= " -m $Options{'mail_conditions'}" if $Options{'mail_conditions'};
    $optstring .= " -M $Options{'mail_address'}" if $Options{'mail_address'};
    $optstring .= " -w $Options{'write_conditions'}" if $Options{'write_conditions'};
    $optstring .= " -W $Options{'write_address'}" if $Options{'write_address'};

    # Deal with output redirection

    croak "MNI::Batch: cannot both redirect stderr to file and merge with stdout"
      if $Options{'stderr'} and $Options{'merge_stderr'};

    $optstring .= " -o $Options{'stdout'}" if $Options{'stdout'};
    $optstring .= " -e $Options{'stderr'}" if $Options{'stderr'};
    $optstring .= " -k" if $Options{'merge_stderr'};
    
    return $optstring;
}


# [CC:98/11/06] - replaced the old 'set_undefined_options' with the 
#                 version from MNI::Spawn
#               - had to copy over 'find_calling_package' as well...
#
# MUSING: what is the rationale to inheriting $verbose and $execute from
# the caller (potentially another perl module) rather than $main,
# as we do for $ProgramName??


# ------------------------------ MNI Header ----------------------------------
#@NAME       : find_calling_package
#@INPUT      : 
#@OUTPUT     : 
#@RETURNS    : 
#@DESCRIPTION: 
#@CALLERS    : 
#@CALLS      : 
#@CREATED    : 1997/08/08, GPW (from code in &check_status)
#@MODIFIED   : ([CC:98/11/06] copied it from MNI::Spawn)
#-----------------------------------------------------------------------------
sub find_calling_package
{
   my ($i, $this_pkg, $package, $filename, $line);

   $i = 0;
   $i++ while (($package = caller $i) eq 'MNI::Batch');
   $package;
}


# ------------------------------ MNI Header ----------------------------------
#@NAME       : set_undefined_option
#@INPUT      : 
#@OUTPUT     : 
#@RETURNS    : 
#@DESCRIPTION: 
#@CREATED    : 1997/07/07, GPW
#@MODIFIED   : [CC:98/11/06] inspired by the version from MNI::Spawn
#-----------------------------------------------------------------------------
sub set_undefined_option
{
   no strict 'refs';
   my ( $option, $varname) = @_;

   return if defined $Options{$option};

   my $package = find_calling_package;
   carp "spawn: fallback variable $package\::$varname undefined " .
        "for option $option"
      unless defined ${ $package . '::' . $varname };
   $Options{$option} = ${ $package . '::' . $varname }
}


sub create_sync_file
{
   my ($condition, $dir, $job_name, $host, $job_pid, $hash) = @_;

   # FIXME: watch out for illegal characters in $job_name, etc.
   #
   $job_name = '' unless defined($job_name);

   my $file = sprintf ("%s/%s_%s-%d.%s", 
		       $dir, $job_name, $host, $job_pid, $condition);
   print BATCH <<END;
if test ! -d $dir; then mkdir -p $dir || exit 1; fi
touch $file || exit 1
END
   $hash->{$job_pid}{$condition} = $file;
}


=item MNI::Batch::SetOptions( option => value, ... )

Set various batch-related options, documented in section L<"OPTIONS">.  
Dies if any bad options are found.

=cut

# ------------------------------ MNI Header ----------------------------------
#@NAME       : &SetOptions
#@INPUT      : ($option,$value) repeated as many time as you like, where
#              $option is one of the valid batch options (see above for
#              list), and $value is an appropriate value for that option.
#              
#@OUTPUT     : 
#@RETURNS    : 
#@DESCRIPTION: Used to set various batch-related options, which are
#              briefly documented above.  Dies if any bad options are found.
#@METHOD     : 
#@GLOBALS    : 
#@CALLS      : 
#@CREATED    : 
#@MODIFIED   : 
#-----------------------------------------------------------------------------
sub SetOptions
{
    _set_options( @_ );
    %DefaultOptions = %Options;
}


# Input: opt => val, opt => val ...
#
sub _set_options
{
    croak "must supply even number of arguments (option/value pairs)"
      unless (@_ % 2 == 0);
   
    # Options given as parameters override the old values in %Options
    # Overrides must specify keys that currently exist in %Options
    #
    while (@_) {
	my $key = shift;

	croak "MNI::Batch: unknown option $key" 
	  unless exists $Options{$key};

	$Options{$key} = shift;
    }
}


=item StartJob( [options] )

Start a new batch job.  Commands for this job are then submitted by calling
C<QueueCommand> or C<QueueCommands>.  Once all commands are queued, you must
call C<FinishJob>.  

Options described in L<"options"> may be overridden I<for this job only> by
giving them here.

If the I<synchronize> option is set to "start" or "both", the filename
for the start synchronizing file is returned.

=cut 

# ------------------------------ MNI Header ----------------------------------
#@NAME       : &StartJob
#@INPUT      : zero or more key => value pairs
#@OUTPUT     : 
#@RETURNS    : 
#@DESCRIPTION: Opens a pipe to `batch', into which commands may be fed
#              by calling &QueueCommand.
#@METHOD     : 
#@GLOBALS    : 
#@CALLS      : 
#@CREATED    : 
#@MODIFIED   : 
#-----------------------------------------------------------------------------
sub StartJob
{
    croak "StartBatchJob: job already in progress; cannot open two jobs"
      if ($JobPID);

    &set_undefined_option( 'verbose', 'Verbose');
    &set_undefined_option( 'execute', 'Execute');

    # Update options for this job
    %Options = %DefaultOptions;
    _set_options( @_ );

    my $cmd = 'batch ' . _batch_optstring();

    my $lh = $Options{'loghandle'};
    printf $lh "[%s] [%s] [%s] starting batch job: $cmd", 
               $ProgramName, userstamp(), timestamp()
		 if $Options{'verbose'};

    # There is a problem with this code: if `batch' starts up fine, but
    # then bombs due to an error, I don't know how to detect it -- I
    # can't look at the $? from `batch' until I close the pipe, and
    # open doesn't give any indication of the failure.  What happens is
    # that the `batch' process goes zombie until we close the pipe to
    # it, at which point we get hit by a SIGPIPE and die -- not really
    # the best way to deal with it.
    #
    # All we can do to get around this is 1) try to minimize possible
    # error conditions (hence the &CheckOutputPath on $stdout and
    # $stderr), and 2) check $? when we close the pipe, in &FinishJob.

    if ( $Options{'execute'} ) {
	$JobPID = open (BATCH, "|$cmd");
	croak ("\nUnable to open pipe to batch: $!\n") unless $JobPID;
	printf $lh " (job %d)\n", $JobPID if $Options{'verbose'};
    } else {
	$JobPID = 1;
	printf $lh " (fake job)\n" if $Options{'verbose'};
	return 'dummy-start-file-name';
    }

    $JobName{$JobPID} = $Options{'job_name'};

    if ($Options{'export_tmpdir'}) 
    {
	print BATCH <<END;
if test ! -d $Options{'export_tmpdir'}; then
# FIXME: 'mkdir -p' is not portable
  mkdir -p $Options{'export_tmpdir'}
  nuke${JobPID}=$Options{'export_tmpdir'}
fi
END
    }

    my $start_syncfile = '';
    if ($Options{'synchronize'} eq 'start' || $Options{'synchronize'} eq 'both')
    {
	&create_sync_file ("start", $Options{'syncdir'}, $Options{'job_name'},
			   $ENV{'HOST'}, $JobPID, \%SyncFiles);
	$start_syncfile = $SyncFiles{$JobPID}{'start'}
    }

    return $start_syncfile;
}


=item FinishJob( [delay] )

Called after all commands have been queued for the currently-opened job.
This function submits the list of commands to the batch queue.

The program pauses for I<close_delay> seconds after submitting the job.
The delay can be overridden by specifying the optional argument.

If the I<synchronize> option is set to "finish" or "both", the filename
for the finish synchronizing file is returned.

=cut

# ------------------------------ MNI Header ----------------------------------
#@NAME       : &FinishJob
#@INPUT      : $sleeptime
#@OUTPUT     : 
#@RETURNS    : 
#@DESCRIPTION: Closes an existing pipe to `batch', thus submitting the job.
#@METHOD     : 
#@GLOBALS    : 
#@CALLS      : 
#@CREATED    : 
#@MODIFIED   : 
#-----------------------------------------------------------------------------
sub FinishJob
{
   croak ("MNI::Batch::FinishJob: wrong number of arguments")
      unless (@_ <= 1);

   croak ("MNI::Batch::FinishJob: no batch job started")
      unless ($JobPID > 0);

   my $sleeptime = $_[0] || $Options{'close_delay'};

   my $lh = $Options{'loghandle'};
   print $lh " [submitting queued commands]\n" if $Options{'verbose'};

   if ( ! $Options{'execute'} ) {
       $JobPID = 0;
       return;
   }

   my $finish_syncfile = '';
   if ($Options{'synchronize'} eq "finish" ||
       $Options{'synchronize'} eq "both")
   {
      &create_sync_file ("finish", $Options{'syncdir'}, $JobName{$JobPID},
                          $ENV{'HOST'}, $JobPID, \%SyncFiles);
      $finish_syncfile = $SyncFiles{$JobPID}{'finish'};
   }

   if ($Options{'export_tmpdir'} && $Options{'nuke_tmpdir'})
   {
      print BATCH <<END;
if test -n \"\$nuke${JobPID}\"; then
  rm -rf \$nuke${JobPID}
fi
END
   } 

   close (BATCH) || croak ("Error closing pipe to batch: $!\n");
   croak ("`batch' exited with non-zero status code\n") if $?;

   $JobPID = 0;
   sleep $sleeptime if $sleeptime > 0;
   return $finish_syncfile;
}


=item Synchronize( onwhat, delay )
=item Synchronize( onwhat, initial_delay, periodic_delay [,timeout] )

Wait until either all pending jobs start, or all pending jobs finish
(or fail).

The parameter I<onwhat> is either C<start>, or C<finish>.  This function
checks periodically for the existence of synchronization files.  In the first
form, I<delay> specifies, in seconds, how often to check for the
synchronization files.  If you are waiting for long jobs to finish, you can
use the second form of the command, to specify separately the I<initial_delay>
to sleep, after which the files are checked for at the frequency specified by
the I<periodic_delay>.  You can also specify a I<timeout> parameter, after
which time we give up waiting for the synchronization files.

If synchronizing on I<start>, the return value is a reference to an array of
job names that did indeed start.  If synchronizing on I<finish>, then two
array refs are returned.  The first array holds the job names that finished,
the second array contains job names that failed.  The value zero is returned
if we timed out waiting for the synchronization files to appear.  This can
happen only if I<timeout> was specified.

The commands to create sync files are automatically inserted into your job by
StartJob and FinishJob, depending on the value of the synchronize option.

=cut

# ------------------------------ MNI Header ----------------------------------
#@NAME       : &Synchronize
#@INPUT      : $onwhat
#              $initial_delay
#              $periodic_delay [optional]
#              $timeout [optional]
#@OUTPUT     : 
#@RETURNS    : 0 if we timed out waiting for jobs to finish (ie. if
#                 $timeout was given and the total delay exceeded it)
#              1 otherwise
#@DESCRIPTION: Waits for all pending jobs to start or finish (depending
#              on the value of $onwhat) by periodically checking for the
#              existence of synchronization files.  (The commands to
#              create sync files are automatically inserted into your job
#              by &StartJob and &FinishJob, depending on the value of the
#              synchronize option.)
#@METHOD     : 
#@GLOBALS    : 
#@CALLS      : 
#@CREATED    : 
#@MODIFIED   : 1996/07/12, GPW: changed $delay to $initial_delay and 
#                               $periodic_delay; added $timeout
#-----------------------------------------------------------------------------
sub Synchronize 
{
   croak ("MNI::Batch::Synchronize: wrong number of arguments") 
      unless @_ >= 2 && @_ <= 4;
   my ($condition, $initial_delay, $periodic_delay, $timeout) = @_;

   croak ("MNI::Batch::Synchronize : must specify either " .
          "`start' or `finish' to synchronize on")
      unless ($condition =~ /^start|finish$/);

   my @conditions = ($condition);
   push (@conditions, "fail") if $condition eq "finish";

   return map( [], @conditions ) 
     unless $Options{'execute'};

   my $done = 0;
   my $numjobs = scalar (keys %SyncFiles);
   $periodic_delay = $initial_delay unless defined $periodic_delay;

   print "MNI::Batch::Synchronize : starting initial delay ($initial_delay sec)\n";
   sleep $initial_delay;

   my $total_wait = $initial_delay;
   my (%synced) = ();

   while ($done < $numjobs)
   {
      printf "MNI::Batch::Synchronize : checking for sync files (have %d/%d) ", $done, $numjobs
         if $Options{'verbose'};

      # For each sync file, check to see that it exists.  For every file
      # for which this is true, increment $done -- then we will stop
      # when $done == $numjobs (ie., the number of jobs recorded in the
      # %$sync hash)

      my( $pid, $filenames );
      while (($pid,$filenames) = each %SyncFiles)
      {
         my $cond;
         foreach $cond (@conditions)
         {
	    my $file = $filenames->{$cond};
            if (-e $file)
            {
               print "$file ";
               unlink $file || carp "Couldn't delete $file: $!\n";
               $done++;

               push (@{$synced{$cond}}, $JobName{$pid});
            }
         }
      }
      print "\n" if $Options{'verbose'};

      unless ($done == $numjobs)
      {
         if (defined $timeout && $total_wait > $timeout)
         {
            warn "MNI::Batch::Synchronize : waited longer than $timeout sec for jobs to finish; ".
               "giving up\n";
            return 0;
         }
         sleep ($periodic_delay);
         $total_wait += $periodic_delay;
      }
   }

   # Just to be neat, we try to remove the sync dir now -- don't be 
   # too aggressive about it, though, as other jobs might have 
   # files there!

   rmdir $Options{'syncdir'};

   return map( $synced{$_} || [], @conditions );
}


=item QueueCommand( command [, options] )

If there is an open batch job, (created with StartJob) add the command to it.
Otherwise create a new job to run just this command.

If the I<synchronize> option is set to "finish" or "both", the filename for
the finish synchronizing file is returned.

=cut

sub QueueCommand 
{
    my $cmd = shift;
    QueueCommands( [ $cmd ], @_ );
}
	  


=item QueueCommands( commands [,options] )


Queues multiple commands to the same job.  If a job is already open, they are
added to it; otherwise, a new job is created for I<all> the commands in
commands.

If the I<synchronize> option is set to "finish" or "both", the filename for
the finish synchronizing file is returned.

=cut

sub QueueCommands
{
    my $commands = shift;

    # Remove any empty commands from the command list
    my @commands = grep ($_, @$commands);
    carp "No commands to queue!" and return
      unless @commands;

    # If no job is underway, we start one ourselves and apply the
    # output redirecting to the job as a whole.  Otherwise, we add the
    # commands to the job in progress.  Unless there is just one
    # command, output redirection is an error --- it should have been
    # applied at the time of StartJob().

    my( $finish_job, $stdout, $stderr, $merge ) = ();

    if ( $JobPID == 0 ) {
	StartJob( @_ );
	$finish_job = 1;
    } else {
	my %JobOptions = @_;
	($stdout, $stderr, $merge) = @JobOptions{'stdout','stderr','merge_stderr'};

	croak "MNI::Batch::QueueCommands: no redirection options allowed"
	  if (@commands > 1) and ($stdout or $stderr or $merge);
    }

    map( _queue_one_command($_, $stdout, $stderr, $merge), @commands );

    return FinishJob() if $finish_job;
}


# Input: command, stder, stdout, merge
# Precondition: a job is active
#
sub _queue_one_command
{
    my( $command, $stdout, $stderr, $merge ) = @_;
    $command = shellquote (@$command) if ref $command eq 'ARRAY';
    my ($program) = $command =~ /^(\S+)/;
    
    my $lh = $Options{'loghandle'};

    printf $lh " [adding to batch job] %s\n", $command 
      if $Options{'verbose'};

    return unless $Options{'execute'};

    croak "MNI::Batch::QueueCommand: cannot both redirect stderr to file and merge with stdout" 
      if $stderr and $merge;
	
    $command .= " 1>$stdout" if $stdout;
    $command .= " 2>$stderr" if $stderr;
    $command .= " 2>&1" if $merge && !$stderr;

    my $i = 0;
    my $linelength = 79;
    while ($i+$linelength < length ($command)) {
	printf BATCH "%s\\\n", substr ($command, $i, $linelength);
	$i += $linelength;
    }
    printf BATCH "%s\n", substr ($command, $i);

    if ($Options{'check_status'}) {
	print BATCH <<END;
if test \$? -ne 0 ; then
  echo "PROGRAM FAILED: $program" >&2
END
	&create_sync_file ("fail", $Options{'syncdir'}, $JobName{$JobPID},
			   $ENV{'HOST'}, $JobPID, \%SyncFiles);
	print BATCH <<END;
  exit 1
fi
END
    }
}


=back

=head1 AUTHOR

Greg Ward, <greg@bic.mni.mcgill.ca>.  With modifications by Chris Cocosco,
Steve Robbins, possibly others.

=head1 COPYRIGHT

Copyright (c) 1997-1999 by Gregory P. Ward, McConnell Brain Imaging Centre,
Montreal Neurological Institute, McGill University.

This file is part of the MNI Perl Library.  It is free software, and may be
distributed under the same terms as Perl itself.

=cut

1;
