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
use vars qw/@ISA @EXPORT_OK %EXPORT_TAGS
            %Options %SyncFiles $JobPID %JobName
            $ProgramName/;
use Exporter;
use Carp;
use MNI::MiscUtilities qw( timestamp userstamp shellquote); 

@ISA = qw(Exporter);
@EXPORT_OK = qw(StartJob FinishJob Synchronize QueueCommand QueueCommands);
%EXPORT_TAGS = (all => [@EXPORT_OK]);


=head1 NAME

MNI::Batch - execute commands via the UCSF Batch Queuing System

=head1 SYNOPSIS

  use MNI::Batch qw(:all);

  MNI::Batch::SetOptions( Queue => long, Synchronize = 'finish' );

  StartJob( 'doit', 'logfile', undef, 1 );
  QueueCommand( 'ls -lR' );
  QueueCommand( 'gzip *.ps' );
  FinishJob();

  QueueCommands( [ 'mritotal this.mnc this.xfm', 'gzip this.mnc' ] );

  Synchronize( 'finish', 3600, 60, 3600*9 ) 
    or die "jobs took longer than nine hours!";

=head1 DESCRIPTION

F<MNI::Batch> provides a method to submit shell commands to the batch
queuing system.

=over 4

=cut

# Package options (can be changed with &SetOptions)

#    Verbose          should we echo queue commands and other info?
#    Execute          should we actually submit jobs?
#    LogHandle        where to echo queue commands and other info
#    Synchronize      can be "start", "finish", or "both"
#    SyncDir          directory to put sync. files in (must
#                     be accessible from all hosts!)
#    ExportTmpDir     name of temporary directory to create
#                     when job is running
#    NukeTmpDir       "rm -rf" the tmp dir when job finishes?
#    Shell            shell to run under -- must be Bourne-shell compatible!!
#    Host             explicitly specified host(s) to run on
#                     (multiple hosts can be specified by means
#                     [\s,;]+ separated string of hostnames)
#    LocalHost        force to run on local host (unless $Host set)
#    Queue            which queue to run on
#    Restartable      should job be restarted on crash (-R option); default 1
#    MailConditions   code for -m option; default: 'cr' (crash or resource
#                     overrun only)
#    MailAddress      address to mail to (-M option)
#    WriteConditions  code for -w option; default '' (don't write)
#    WriteAddress     address to mail to (-W option)

%Options = (Verbose         => undef,
            Execute         => undef,
            LogHandle       => \*STDOUT,
            Synchronize     => '',
            SyncDir         => "$ENV{'HOME'}/.sync",
            ExportTmpDir    => '',
            NukeTmpDir      => 0,
            CheckStatus     => 1,
            Shell           => '/bin/sh',
            Host            => '',
            LocalHost       => 0,
            Queue           => '',
            Restartable     => 1,
            MailConditions  => 'cr', 
            MailAddress     => '',
            WriteConditions => '',
            WriteAddress    => '',
           );


# Package-private globals #############################################

# These two hashes serve to keep track of pending synchronization
# files.  There are two types of such files: for job start and job
# finish.  Both act the same way, and the client can use them to block
# either until all jobs have started or until all jobs have finished.
# Each hash is keyed on sync filename (the files are touched when the
# job starts/finishes); the values are the time at which the sync
# filename was entered to the hash (ie. when StartJob or FinishJob was
# called).

$JobPID = 0;
%JobName = ();                  # map job pid -> name
%SyncFiles = ();                # map job pid -> filename hash
                                # the filename hash maps condition to filename


# [CC] inspired by (errr, "copied" from ;-) MNI::Spawn.pm 
#		  
if (defined $main::ProgramName) {
    *ProgramName = \$main::ProgramName;
}
else {
    ($ProgramName = $0) =~ s|.*/||;
}   


sub gen_batch_options
{
   my ($jobname, $stdout, $stderr, $merge) = @_;
   my ($options);

   # First, options based on the package-global option variables

   $options = " -s $Options{'Shell'}" if $Options{'Shell'};
   foreach ( split( /[\s,;]+/, $Options{'Host'})) {
       $options .= " -H $_";
   }
   $options .= " -l" if $Options{'LocalHost'};
   $options .= " -Q $Options{'Queue'}" if $Options{'Queue'};
   $options .= " -S" if $Options{'Restartable'};
   $options .= " -m $Options{'MailConditions'}" if $Options{'MailConditions'};
   $options .= " -M $Options{'MailAddress'}" if $Options{'MailAddress'};
   $options .= " -w $Options{'WriteConditions'}" if $Options{'WriteConditions'};
   $options .= " -W $Options{'WriteAddress'}" if $Options{'WriteAddress'};

   # Now the more job-specific stuff (provided by parameters to either
   # &StartJob or &QueueCommand)

   $options .= " -J $jobname" if $jobname;
   $options .= " -o $stdout" if $stdout;
   $options .= " -e $stderr" if $stderr;
   $options .= " -k" if $merge;

   # Should we croak if $stdout && $stderr && $merge ?

   $options;
}


# [CC:98/11/06] - replaced the old 'set_undefined_options' with the 
#                 version from MNI::Spawn
#               - had to copy over 'find_calling_package' as well...

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

   return if defined $MNI::Batch::Options{$option};

   my $package = find_calling_package;
   carp "spawn: fallback variable $package\::$varname undefined " .
        "for option $option"
      unless defined ${ $package . '::' . $varname };
   $MNI::Batch::Options{$option} = ${ $package . '::' . $varname }
}


sub create_sync_file
{
   my ($condition, $dir, $job_name, $host, $job_pid, $hash) = @_;

   my $file = sprintf ("%s/%s_%s-%d.%s", 
		       $dir, $job_name, $host, $job_pid, $condition);
   print BATCH <<END;
if test ! -d $dir; then mkdir -p $dir || exit 1; fi
touch $file || exit 1
END
   $hash->{$job_pid}{$condition} = $file;
}


=item MNI::Batch::SetOptions( option => value, ... )

Used to set various batch-related options, which are briefly documented in the
code.  Dies if any bad options are found.

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
   my (@optval) = @_;
   my ($opt, $val);

   while (@optval)
   {
      $opt = shift @optval;
      $val = shift @optval;

      croak ("Unmatched option $opt")
	unless defined $val;

      croak ("Unknown option $opt") 
	unless exists $Options{$opt};

      $Options{$opt} = $val;
   }
}


=item StartJob( jobname, stdout, stderr, merge )

Create a new job,
Opens a pipe to `batch', into which commands may be fed by calling
QueueCommand.

=cut 

# ------------------------------ MNI Header ----------------------------------
#@NAME       : &StartJob
#@INPUT      : $jobname
#              $stdout
#              $stderr
#              $merge
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
   croak ("MNI::Batch::StartJob: wrong number of arguments")
      unless (@_ == 4);
   my ($jobname, $stdout, $stderr, $merge) = @_;
   my ($options);

   &set_undefined_option( 'Verbose', 'Verbose');
   &set_undefined_option( 'Execute', 'Execute');

   croak ("StartBatchJob: already an open batch job")
     if ($JobPID);

   $options = &gen_batch_options ($jobname, $stdout, $stderr, $merge);
   my $lh = $Options{'LogHandle'};
   printf $lh "[%s] [%s] [%s] starting batch job: batch%s", 
      $ProgramName, userstamp(), timestamp(), $options
      if $Options{'Verbose'};

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

   if ( $Options{'Execute'} ) {
       $JobPID = open (BATCH, "|batch$options");
       croak ("\nUnable to open pipe to batch: $!\n") unless $JobPID;
       printf $lh " (job %d)\n", $JobPID if $Options{'Verbose'};
   } else {
       $JobPID = 1;
       printf $lh " (fake job)\n" if $Options{'Verbose'};
       return 1;
   }

   $JobName{$JobPID} = $jobname;

   if ($Options{'ExportTmpDir'})
   {
      print BATCH <<END;
if test ! -d $Options{'ExportTmpDir'}; then
  mkdir -p $Options{'ExportTmpDir'}
  nuke${JobPID}=$Options{'ExportTmpDir'}
fi
END
   }

   if ($Options{'Synchronize'} eq "start" || $Options{'Synchronize'} eq "both")
   {
      &create_sync_file ("start", $Options{'SyncDir'}, $jobname,
                         $ENV{'HOST'}, $JobPID, \%SyncFiles);
   }

   $JobPID;
}  # &StartJob


=item FinishJob( [delay] )

Close the currently-opened job.  Optionally, sleep for I<delay> seconds.

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
      unless ($JobPID);

   my ($sleeptime) = @_;

   my $lh = $Options{'LogHandle'};
   print $lh " [submitting queued commands]\n" if $Options{'Verbose'};

   if ( ! $Options{'Execute'} ) {
       $JobPID = 0;
       return;
   }

   if ($Options{'Synchronize'} eq "finish" || $Options{'Synchronize'} eq "both")
   {
      &create_sync_file ("finish", $Options{'SyncDir'}, $JobName{$JobPID},
                          $ENV{'HOST'}, $JobPID, \%SyncFiles);
   }

   if ($Options{'ExportTmpDir'} && $Options{'NukeTmpDir'})
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
   sleep $sleeptime if defined $sleeptime;
}


=item Synchronize( onwhat, initial_delay [,periodic_delay [,timeout]] )

Waits for all pending jobs to start or finish (depending on the value of
onwhat) by periodically checking for the existence of synchronization files.

Returns 0 if we timed out waiting for jobs to finish (ie. if timeout was given
and the total delay exceeded it) 1 otherwise.

The commands to create sync files are automatically inserted into your job by
StartJob and FinishJob, depending on the value of the Synchronize option.

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
#              Synchronize option.)
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

   return 1 unless $Options{'Execute'};

   my @conditions = ($condition);
   push (@conditions, "fail") if $condition eq "finish";

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
         if $Options{'Verbose'};

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
               unlink $file || warn "Couldn't delete $file: $!\n";
               $done++;

               push (@{$synced{$cond}}, $JobName{$pid});
            }
         }
      }
      print "\n" if $Options{'Verbose'};

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

   rmdir $Options{'SyncDir'};

   my ($cond, @retval);
   foreach $cond (@conditions)
   {
      push (@retval, $synced{$cond} || []);
   }

   return @retval;
}


=item QueueCommand( command [,jobname, stdout, stderr, merge] ) 

If there is an open batch job, (created with StartJob) add the command to it.
Otherwise create a new job to run just this command.

=cut

# ------------------------------ MNI Header ----------------------------------
#@NAME       : &QueueCommand
#@INPUT      : 
#@OUTPUT     : 
#@RETURNS    : 
#@DESCRIPTION: If there is an open batch job (created with &StartJob),
#              adds $command to it.  Otherwise, starts a new job to
#              run just this command.
#@METHOD     : 
#@GLOBALS    : 
#@CALLS      : 
#@CREATED    : 
#@MODIFIED   : 
#-----------------------------------------------------------------------------
sub QueueCommand
{
   my ($command, $jobname, $stdout, $stderr, $merge) = @_;
   my ($program, $options, $redirect);

   &set_undefined_option( 'Verbose', 'Verbose');
   &set_undefined_option( 'Execute', 'Execute');

   my $lh = $Options{'LogHandle'};
   $command = shellquote (@$command) if ref $command eq 'ARRAY';

   if ($JobPID)		# pipe open to batch already?
   {
      printf $lh " [adding to batch job] %s\n", $command 
	if $Options{'Verbose'};

      return 0 unless $Options{'Execute'};

      ($program) = $command =~ /^(\S+)/;

      $redirect = "";
      $redirect .= " 1>$stdout" if $stdout;
      $redirect .= " 2>$stderr" if $stderr;
      $redirect .= " 2>&1" if $merge && !$stderr;
      $command .= $redirect;
      my $i = 0;
      my $linelength = 79;
      while ($i+$linelength < length ($command))
      {
	 printf BATCH "%s\\\n", substr ($command, $i, $linelength);
	 $i += $linelength;
      }
      printf BATCH "%s\n", substr ($command, $i);

      if ($Options{'CheckStatus'})
      {
         print BATCH <<END;
if test \$? -ne 0 ; then
  echo "PROGRAM FAILED: $program" >&2
END
         &create_sync_file ("fail", $Options{'SyncDir'}, $JobName{$JobPID},
                            $ENV{'HOST'}, $JobPID, \%SyncFiles);
         print BATCH <<END;
  exit 1
fi
END
      }

   }
   else
   {
      carp ("Warning: you're missing out on a lot of features by using QueueCommand like this");
      $options = &gen_batch_options ($jobname, $stdout, $stderr, $merge);
      printf $lh ("[%s] [%s] [batch queued] %s\n", 
                  userstamp(), timestamp(), $command)
	 if $Options{'Verbose'};

      return 0 unless $Options{'Execute'};

      system ("batch$options $command");
      croak ("Error running batch\n") if ($?);
   }
}


=item QueueCommands( commands, jobname, stdout, stderr, merge )


Queues multiple commands to the same job.  If a job is already open, they are
added to it; otherwise, a new job is created for I<all> the commands in
commands.

=cut

# ------------------------------ MNI Header ----------------------------------
#@NAME       : &QueueCommands
#@INPUT      : $commands
#              $jobname
#              $stdout
#              $stderr
#              $merge
#@OUTPUT     : 
#@RETURNS    : 
#@DESCRIPTION: Queues multiple commands to the same job.  If a job is
#              already open, they are added to it; otherwise, a new
#              job is created for *all* the commands in $commands.
#@METHOD     : 
#@GLOBALS    : 
#@CALLS      : 
#@CREATED    : 
#@MODIFIED   : 
#-----------------------------------------------------------------------------
sub QueueCommands
{
   my ($commands, $jobname, $stdout, $stderr, $merge) = @_;

   &set_undefined_option( 'Verbose', 'Verbose');
   &set_undefined_option( 'Execute', 'Execute');

   # Remove any empty commands from the command list

   my @commands = grep ($_, @$commands);

   unless (@commands)
   {
      warn "No commands to queue!\n";
      return;
   }

   my $exclusive = 0;
   unless ($JobPID)	# no batch job open already?
   {
      $exclusive = 1;		# this will be ours to close when done
      &StartBatchJob ($jobname, $stdout, $stderr, $merge);
   }

   my $cmd;
   foreach $cmd (@commands)
   {
      &QueueCommand ($cmd);
   }

   &FinishJob () if $exclusive;
}

=back

=head1 AUTHOR

Greg Ward, <greg@bic.mni.mcgill.ca>.  With modifications by Chris Cocosco,
Steve Robbins, and probably dozens of others.

=head1 COPYRIGHT

Copyright (c) 1997-1999 by Gregory P. Ward, McConnell Brain Imaging Centre,
Montreal Neurological Institute, McGill University.

This file is part of the MNI Perl Library.  It is free software, and may be
distributed under the same terms as Perl itself.

=cut

1;
