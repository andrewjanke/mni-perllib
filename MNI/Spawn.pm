# ------------------------------ MNI Header ----------------------------------
#@NAME       : MNI::Spawn
#@DESCRIPTION: All-singing, all-dancing program runner (includes path 
#              searching, default arguments, verbose command logging, 
#              interface to UCSF Batch, output redirect/capture, and
#              error checking).
#@EXPORT     : SetOptions FindPrograms AddDefaultArgs ClearDefaultArgs Spawn
#              UNTOUCHED, REDIRECT, CAPTURE, MERGE
#@EXPORT_OK  : 
#@EXPORT_TAGS: all, const
#@USES       : Carp, Cwd, 
#              MNI::FileUtilities, MNI::PathUtilities, MNI::MiscUtilities
#@REQUIRES   : Exporter
#@CREATED    : 1997/07/07, Greg Ward (loosely based on JobControl.pm, rev 2.8)
#@MODIFIED   : 
#@VERSION    : $Id: Spawn.pm,v 1.6 1997-08-08 14:56:04 greg Exp $
#@COPYRIGHT  : Copyright (c) 1997 by Gregory P. Ward, McConnell Brain Imaging
#              Centre, Montreal Neurological Institute, McGill University.
#
#              This file is part of the MNI Perl Library.  It is free 
#              software, and may be distributed under the same terms
#              as Perl itself.
#-----------------------------------------------------------------------------

package MNI::Spawn;

use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
use Carp;
use Cwd;
use MNI::FileUtilities ();
use MNI::PathUtilities qw(split_path);
use MNI::MiscUtilities qw(userstamp timestamp shellquote);

require 5.002;
require Exporter;
@ISA = qw(Exporter);
@EXPORT_OK = qw();
%EXPORT_TAGS = (const => [qw(UNTOUCHED REDIRECT CAPTURE MERGE)],
                subs  => [qw(SetOptions FindPrograms 
                             AddDefaultArgs ClearDefaultArgs Spawn)]);
@EXPORT = (@{$EXPORT_TAGS{'const'}}, @{$EXPORT_TAGS{'subs'}});
$EXPORT_TAGS{all} = [@EXPORT, @EXPORT_OK];


sub UNTOUCHED { \1 }
sub REDIRECT  { \2 }
sub CAPTURE   { \4 }
sub MERGE     { \8 }


# This provides default values for all options, as well as a standard list
# of all the options, so we can check them for validity when the user sets
# them
my %DefaultOptions =
   (verbose      => undef,              # print commands as we execute them?
    execute      => undef,              # actually execute commands?
    strict       => 1,                  # complain about unknown programs?
    complete     => 1,                  # should we search, add def. args?
    search       => 1,                  # should we search?
    add_defaults => 1,                  # should we add default arguments?
    search_path  => undef,              # list of directories to search
#   merge_stderr => REDIRECT,           # when to automatically merge stderr
    err_action   => '',                 # what to do when a command fails
    batch        => 0,                  # submit commands to batch system?
    clobber      => 0,                  # overwrite output files (not append)
    loghandle    => \*STDOUT,           # filehandle to write commands to
    notify       => $ENV{'USER'},       # should &Obituary actually send mail?
    stdout       => undef,              # what to do with stdout
    stderr       => undef);             # what to do with stderr


# ----------------------------------------------------------------------
# The public part of the object-oriented interface:
#   new
#   copy
#   set_options
#   find_programs
#   add_default_args
#   clear_default_args
#   spawn
# ----------------------------------------------------------------------

# ------------------------------ MNI Header ----------------------------------
#@NAME       : new
#@INPUT      : 
#@OUTPUT     : 
#@RETURNS    : 
#@DESCRIPTION: 
#@CREATED    : 1997/07/07, GPW
#@MODIFIED   : 
#-----------------------------------------------------------------------------
sub new
{
   my $type = shift;

   my $self = bless { %DefaultOptions }, $type;
   $self->{programs} = {};
   $self->{defargs}{pre} = {};
   $self->{defargs}{post} = {};
   $self->set_options (@_);
   $self;
}


# ------------------------------ MNI Header ----------------------------------
#@NAME       : copy
#@INPUT      : 
#@OUTPUT     : 
#@RETURNS    : 
#@DESCRIPTION: 
#@CREATED    : 1997/07/07, GPW
#@MODIFIED   : 
#-----------------------------------------------------------------------------
sub copy
{
   my $self = shift;

   my $newself = {%$self};
   $newself->{programs} = {%{$self->{programs}}};
   $newself->{defargs}{pre} = {%{$self->{defargs}{pre}}};
   $newself->{defargs}{post} = {%{$self->{defargs}{post}}};
   bless $newself, ref $self;
}


# ------------------------------ MNI Header ----------------------------------
#@NAME       : set_options
#@INPUT      : 
#@OUTPUT     : 
#@RETURNS    : 
#@DESCRIPTION: 
#@CREATED    : 1997/07/07, GPW
#@MODIFIED   : 
#-----------------------------------------------------------------------------
sub set_options
{
   my $self = shift;

   croak "set_options: must supply even number of args (option/value pairs)"
      unless (@_ % 2 == 0);

   my ($opt, $val);
   while (@_)
   {
      ($opt, $val) = (shift, shift);
      croak "set_options: unknown option \"$opt\""
         unless exists $DefaultOptions{$opt};
      $self->{$opt} = $val;
   }
   $self;
}


# ------------------------------ MNI Header ----------------------------------
#@NAME       : find_programs
#@INPUT      : 
#@OUTPUT     : 
#@RETURNS    : 
#@DESCRIPTION: 
#@CREATED    : 1997/07/07, GPW, from FindPrograms in JobControl.pm
#@MODIFIED   : 
#-----------------------------------------------------------------------------
sub find_programs
{
   my ($self, $programs, $path) = shift;

   croak 'find_programs: $programs must be an array reference'
      unless ref $programs eq 'ARRAY';
   croak 'find_programs: if supplied, $path must be a scalar or list reference'
      unless (ref $path eq 'ARRAY' || ! ref $path);

   my @fullpaths = MNI::FileUtilities::find_programs 
      ($programs, $path || $self->{search_path});
   if (@fullpaths)              # all found successfully?
   {
      confess "Wrong number of full paths to go with program list"
         unless (@fullpaths == @$programs);

      map { $self->{programs}{$_} = shift @fullpaths } @$programs;
      return 1;
   }
   else
   {
      return 0;
   }
}


# ------------------------------ MNI Header ----------------------------------
#@NAME       : add_default_args
#@INPUT      : 
#@OUTPUT     : 
#@RETURNS    : 
#@DESCRIPTION: 
#@CREATED    : 1997/07/07, GPW, from AddProgramOptions in JobControl.pm
#@MODIFIED   : 
#-----------------------------------------------------------------------------
sub add_default_args
{
   my ($self, $programs, $args, $where) = @_;

   croak "add_default_args: if given, \$where must be 'pre' or 'post'"
      if defined $where and $where !~ /^(pre|post)$/;
   croak "add_default_args: \$programs must be an array ref or string"
      unless ref $programs eq 'ARRAY' || ! ref $programs;
   croak "add_default_args: \$args must be an array ref or string"
      unless ref $args eq 'ARRAY' || ! ref $args;

   $where ||= 'pre';
   my @programs = (ref $programs eq 'ARRAY') ? (@$programs) : ($programs);
   my @args = (ref $args eq 'ARRAY') ? (@$args) : ($args);

   my $program;
   foreach $program (@programs)
   {
      carp ("add_default_args: warning: " .
            "adding default arguments for unregistered program \"$program\"")
         if ($self->{strict} && ! exists $self->{programs}{$program});
      push (@{$self->{defargs}{$where}{$program}}, @args);
   }
}


# ------------------------------ MNI Header ----------------------------------
#@NAME       : clear_default_args
#@INPUT      : 
#@OUTPUT     : 
#@RETURNS    : 
#@DESCRIPTION: 
#@CREATED    : 1997/07/07, GPW
#@MODIFIED   : 
#-----------------------------------------------------------------------------
sub clear_default_args
{
   my ($self, $program, $where) = @_;

   croak "clear_default_args: if given, \$where must be " .
         "'pre', 'post', or 'both'"
      if defined $where and $where !~ /^(pre|post|both)$/;

   my @programs = (ref $program eq 'ARRAY') ? (@$program) : ($program);
   my ($clear_pre, $clear_post);

   if (defined $where)
   {
      $clear_pre = ($where eq 'pre') || ($where eq 'both');
      $clear_post = ($where eq 'post') || ($where eq 'both');
   }
   else
   {
      $clear_pre = $clear_post = 1;     # default to 'both'
   }

   foreach $program (@programs)
   {
      carp ("clear_default_args: warning: " .
            "clearing default arguments for unregistered program \"$program\"")
         if ($self->{strict} && ! exists $self->{programs}{$program});
      delete $self->{defargs}{pre}{$program} if $clear_pre;
      delete $self->{defargs}{post}{$program} if $clear_post;
   }
}



# ------------------------------ MNI Header ----------------------------------
#@NAME       : spawn
#@INPUT      : 
#@OUTPUT     : 
#@RETURNS    : 
#@DESCRIPTION: 
#@CREATED    : 1997/07/07, GPW, from Spawn in JobControl.pm
#@MODIFIED   : 
#-----------------------------------------------------------------------------
sub spawn
{
   my ($self, $command, @options) = @_;
   my ($program);

   # Inherit `verbose' and `execute' options from variables in main
   # package if they aren't already defined

   $self->set_undefined_option ('verbose', 'Verbose');
   $self->set_undefined_option ('execute', 'Execute');


   # If caller supplied any options, make a copy of the spawning vat
   # and override those options in the copy only

   if (@options)
   {
      $self = $self->copy;
      $self->set_options (@options);
   }


   # Complete the command (ie. program name to full path, insert
   # options fore and aft)

   ($command, $program) = $self->complete_command
      ($command, $self->{verbose} && !$self->{batch});


   # Figure out just what the user wants us to do with stdout and stderr

   my ($stdout, $stderr) = @$self{'stdout','stderr'};
   my ($stdout_mode, $stderr_mode);
   ($stdout, $stdout_mode) = output_mode ('stdout', $stdout);
   croak "spawn: you can't merge stdout with itself!"
      if $stdout_mode == MERGE;
   ($stderr, $stderr_mode) = output_mode ('stderr', $stderr);


   # Determine if we should merge stderr with stdout: first, the caller
   # must not have explicitly specified what to do with stderr already; and
   # second, we must be redirecting stdout.  Note that this is the only
   # place where we distinguish between the empty string and undef for
   # stderr; the empty string means "definitely leave it untouched", and
   # undef means "maybe leave it untouched, maybe merge it".  (output_mode
   # treates them as equivalent -- both result in $stderr_mode being set to
   # UNTOUCHED.)

   if (!defined $stderr && $stdout_mode == REDIRECT) 
   {
      $stderr_mode = MERGE;
   }


   # If we're in `batch' mode, pass this one off to the batch system

   if ($self->{batch})
   {
      croak "spawn: can't capture stdout or stderr when running through batch"
         if ($stdout_mode == CAPTURE || $stderr_mode == CAPTURE);

      confess "spawn: batch mode not implemented yet";
   }


   # Figure out how to open files ('>' to overwrite or '>>' to append), and
   # prepend that to $stdout and $stderr if they don't already have such a
   # code in them.

   my $open_prefix = $self->{clobber} ? '>' : '>>';
   $stdout = $open_prefix . $stdout 
      if ($stdout_mode == REDIRECT && $stdout !~ /^>/);
   $stderr = $open_prefix . $stderr 
      if ($stderr_mode == REDIRECT && $stderr !~ /^>/);


   # Warn if the user is calling us in array context

   carp "spawn: called in an array context (no longer useful)"
      if wantarray;


   # Return now unless the `execute' option is true.  (Note that spawn's
   # return value is bass-ackwards: 0 implies success, just like a
   # program's exit status [this is not coincidental!].)

   return 0 unless $self->{execute};


   # Now, we finally get to run the command.  This is done via either
   # spawn_capture or spawn_redirect, depending on what we're doing with
   # stdout.  (Doing nothing is handled by spawn_redirect.)

   if ($stdout_mode == CAPTURE)         # capturing to a variable?
   {
      $self->spawn_capture ($command, $program,
                            $stdout_mode, $stdout, $stderr_mode, $stderr);
   }
   else
   {
      $self->spawn_redirect ($command, $program,
                             $stdout_mode, $stdout, $stderr_mode, $stderr);
   }
}



# ----------------------------------------------------------------------
# End of externally-used stuff -- now come the methods and subroutines
# only called internally (i.e. by `spawn' itself or by other interal
# routines):
#   set_undefined_option (method)
#   check_program    (method)
#   complete_command (method)
#   output_mode      (subroutine)
#   exec_command     (subroutine)
#   gather_error     (subroutine)
#   obituary         (method)
#   check_status     (method)
#   spawn_capture    (method)
#   spawn_redirect   (method)
# ----------------------------------------------------------------------


# ------------------------------ MNI Header ----------------------------------
#@NAME       : find_calling_package
#@INPUT      : 
#@OUTPUT     : 
#@RETURNS    : 
#@DESCRIPTION: 
#@CALLERS    : 
#@CALLS      : 
#@CREATED    : 1997/08/08, GPW (from code in &check_status)
#@MODIFIED   : 
#-----------------------------------------------------------------------------
sub find_calling_package
{
   my ($i, $this_pkg, $package, $filename, $line);

   $i = 0;
   $i++ while (($package = caller $i) eq 'MNI::Spawn');
#   print "caller $i is $package\n";
   $package;
}


# ------------------------------ MNI Header ----------------------------------
#@NAME       : set_undefined_option
#@INPUT      : 
#@OUTPUT     : 
#@RETURNS    : 
#@DESCRIPTION: 
#@CREATED    : 1997/07/07, GPW
#@MODIFIED   : 
#-----------------------------------------------------------------------------
sub set_undefined_option
{
   no strict 'refs';
   my ($self, $option, $varname) = @_;

   return if defined $self->{$option};

   my $package = find_calling_package;
   carp "spawn: fallback variable $package\::$varname undefined " .
        "for option $option"
#      unless exists ${$package . '::'}{$varname};
      unless defined ${ $package . '::' . $varname };
   $self->{$option} = ${ $package . '::' . $varname }
}


# ------------------------------ MNI Header ----------------------------------
#@NAME       : check_program
#@INPUT      : $command - the full command
#              $program - the first word from a command, ie. the program
#                         to execute
#@OUTPUT     : 
#@RETURNS    : $fullpath    - full path (possibly relative) to the program;
#                             if the input $program was a path, then this
#                             will be identical to it
#              $pre_defargs - [array ref] list of options associated with
#                             this program
#              $post_defargs- [array ref] list of options associated with
#                             this program that are meant to come at the
#                             *end* of the command line
#@DESCRIPTION: Makes sure that a program we wish to execute actually exists.
#              How this is done depends on how the program name is specified;
#              if it is just a filename (no slashes), then we first look
#              in the %Programs hash to see if it was registered via
#              FindProgram; if not, we (optionally) complain and try to
#              find out ourselves via an explicit search.  If this fails,
#              we fail via &check_status (meaning we might just
#              return 0, or completely bomb out, or whatever the caller
#              asked for).
#
#              If, however, the program is supplied as a path of some sort
#              (ie. there're slashes in it), then we simply check that the
#              specified file exists and is executable.  If not, we again
#              bomb via &check_status.
#@METHOD     : 
#@GLOBALS    : %Programs, %PreOptions, %PostOptions
#@CALLERS    : complete_command
#@CALLS      : MNI::FileUtilities::find_program
#              MNI::PathUtilities::split_path
#              check_status
#@CREATED    : 1996/11/19, GPW (from prototype code in &Execute)
#@MODIFIED   : 1997/07/08, GPW (copied from JobControl.pm)
#-----------------------------------------------------------------------------
sub check_program
{
   my ($self, $command, $program) = @_;
   my ($fullpath, @pre_defargs, @post_defargs);

   # If $program was supplied as a bare filename, then we poke around a bit
   # to find it.  First try the `programs' hash; if it's not found there,
   # then we issue a warning (if the `strict' flag is set) and try to find
   # it ourselves with &MNI::FileUtilities::find_program.  If this also
   # fails, then we call &check_status with an artificial failure
   # status (the same status that Perl sets if system() fails because the
   # program doesn't exist) to provoke the appropriate failure action.
   # It's ok to do this without printing "$program not found" because
   # MNI::FileUtilities::find_program does this for us.

   if ($program !~ m|/|)      # just a name, no directories at all
   {
      $fullpath = $self->{programs}{$program};
      if (! defined $fullpath && $self->{search})
      {
         croak ("spawn: warning: program \"$program\" not registered")
            if ($self->{strict} == 2);
         carp ("spawn: warning: program \"$program\" not registered")
            if ($self->{strict} == 1);

         $fullpath = MNI::FileUtilities::find_program
            ($program, $self->{search_path});
         if (! defined $fullpath)
         {
            return $self->check_status (255 << 8, $program, $command);
         }
      }
      else                              # program not registered or caller
      {                                 # disallowed searching -- so mere
         $fullpath = $program;          # program name will have to do
      }
   }
   else                                 # caller supplied a path (possibly
   {                                    # relative, but that doesn't matter)
      unless (-e $program && -x $program)
      {
         warn "spawn: warning: " . 
              "program \"$program\" doesn't exist or isn't executable\n";
         return $self->check_status (255 << 8, $program, $command);
      }

      $fullpath = $program;
      $program = (split_path ($fullpath, 'none'))[1];
   }

   # Now, $program is base filename, and $fullpath is the full path to it
   # (possibly relative, if that's what we were supplied with; or it might
   # just be the bare program name, if we should have searched but the
   # caller disallowed that).  Look up program options in the two options
   # hashes for use by the caller.

   if ($self->{add_defaults})
   {
      @pre_defargs = (exists $self->{defargs}{pre}{$program})
         ? @{$self->{defargs}{pre}{$program}}
         : ();
      @post_defargs = (exists $self->{defargs}{post}{$program})
         ? @{$self->{defargs}{post}{$program}}
         : ();
   }

   ($fullpath, \@pre_defargs, \@post_defargs);

}  # &check_program


# ------------------------------ MNI Header ----------------------------------
#@NAME       : complete_command
#@INPUT      : $command  - [list ref or string]
#              $verbose  - true to print out full command
#@OUTPUT     : 
#@RETURNS    : $command  - [list ref or string -- whichever the input is]
#                          input $command with full path to program and
#                          any standard options included
#              $program  - the program name extracted from $command
#@DESCRIPTION: Extracts the program name from a command (list or string),
#              calls &check_program to get the full path and options
#              for the program, and constructs a new command (list or
#              string) with these goodies included.
#@METHOD     : 
#@GLOBALS    : 
#@CALLERS    : spawn
#@CALLS      : check_program
#              usestamp, timestamp, shellquote (from MNI::MiscUtilities)
#@CREATED    : 1996/12/10, GPW (from &Execute)
#@MODIFIED   : 1997/07/08, GPW (copied from JobControl.pm)
#-----------------------------------------------------------------------------
sub complete_command
{
   my ($self, $command, $verbose) = @_;
   my ($complete, $program, $pre_defargs, $post_defargs);

   if (ref $command)
   {
      croak ("spawn: \$command must be either a list ref or a simple string")
         unless (ref $command eq 'ARRAY');

      # Make our own copy of the command list to scribble on (and eventually
      # return to `spawn')
         
      my @command = @$command;

      # Check for "escaped" command (starts with a backslash) -- if found,
      # remove the backslash, warn that this is obsolete, and clear $complete.
      # XXX the "escape" hack should eventually be removed!
      
      if ($command[0] =~ s|^\\||)
      {
         carp "spawn: warning: escaping commands with backslash is deprecated".
              " -- you should instead set the `complete' option to false";
         $complete = 0;
      }
      else                              # otherwise the `complete' option
      {                                 # is used
         $complete = $self->{complete};
      }

      # Now we actually pay attention to $complete (either from the
      # escapedness of the command or, usually, from the `complete'
      # option) -- only do the fancy stuff (search, add options) if
      # it's true

      if ($complete)
      {
         $program = shift @command;
         my ($fullpath, $pre_defargs, $post_defargs) =
            $self->check_program ($command, $program);
         
         # Build a new command list using the full path and default options;
         # use this to print and execute
         
         unshift (@command, $fullpath, @$pre_defargs);
         push (@command, @$post_defargs);
      }
      else
      {
         $program = $command[0];
      }

      # Finally, print the command if the Verbose flag is true

      if ($verbose)
      {
         my $lh = $self->{loghandle};
         printf $lh ("[%s] [%s] [%s] %s\n",
                     $::ProgramName, userstamp(), timestamp(),
                     shellquote (@command));
      }

      # And return the augmented command list

      return (\@command, $program);
   }
   else                                 # $command is just a string
   {
      if ($command =~ s|^\\||)
      {
         carp "spawn: warning: escaping commands with backslash is deprecated".
              " -- you should instead set the `complete' option to false";
         $complete = 0;
      }
      else                              # otherwise the `complete' option
      {                                 # is used
         $complete = $self->{complete};
      }

      if ($complete)
      {
         # Get the first word (i.e. the program to run) from the command
         # string; we do this via a regexp rather than split so we can
         # remove the program name and put it back in later, with default
         # options added

         # XXX uh... what if $command is "ls>foo" ??? -- this regexp won't
         # do the right thing!

         $command =~ s/^(\S+)\s*//;
         $program = $1;
         my ($fullpath, $pre_defargs, $post_defargs) = 
            $self->check_program ($command, $program);

         # Build a new command string using the full path and default options;
         # print the command and execute it

         $command = join (" ", $fullpath,
                          @$pre_defargs, $command || (), @$post_defargs);
      }
      else
      {
         ($program) = $command =~ /^(\S+)\s*/;
      }
         

      if ($verbose)
      {
         my $lh = $self->{loghandle};
         printf $lh ("[%s] [%s] [%s] %s\n",
                     $::ProgramName, userstamp(), timestamp(), $command);
      }

      return ($command, $program);
   }

}  # complete_command


# ------------------------------ MNI Header ----------------------------------
#@NAME       : output_mode
#@INPUT      : $name - name of the option describing some output stream
#                      (for error messages)
#              $dest - the value of the option that the user supplied 
#                      (either a string [filename], reference, or one of
#                      the output mode constants)
#@OUTPUT     : 
#@RETURNS    : an output mode constant (UNTOUCHED, MERGE, REDIRECT, or CAPTURE)
#@DESCRIPTION: Generalizes a particular value of the `stdout' or `stderr'
#              options into one of the four possible things we can do
#              with an output stream (leave it untouched, merge it with 
#              stdout [stderr only], redirect it, or capture it).
#@CALLERS    : spawn
#@CALLS      : 
#@CREATED    : 1997/07/07, GPW
#@MODIFIED   : 
#-----------------------------------------------------------------------------
sub output_mode
{
   my ($name, $dest) = @_;
   my $mode;

   MODE:
   {
      if (ref $dest)
      {
         ($mode = UNTOUCHED, $dest = '', last MODE)
            if $dest == UNTOUCHED;
         ($mode = MERGE, last MODE)
            if $dest == MERGE;
         croak "spawn: $name must be a filename to redirect" 
            if $dest == REDIRECT;
         croak "spawn: $name must be a reference to capture"
            if $dest == CAPTURE;
         croak "spawn: $name must be a scalar or array reference to capture"
            unless ref $dest eq 'SCALAR' || ref $dest eq 'ARRAY';
         $mode = CAPTURE, last MODE;
      }
      else
      {
         $mode = UNTOUCHED, last MODE if (!defined $dest || $dest eq '');
         $mode = REDIRECT;
      }
   }
   ($dest, $mode);
}


# ------------------------------ MNI Header ----------------------------------
#@NAME       : &exec_command
#@INPUT      : $command - the whole command, either as string or list ref
#              $program - the program name
#              $stdout  - where to redirect stdout to
#              $stderr  - where to redirect stderr to (or "-" to emulate
#                         capturing it by redirecting to temp file)
#@OUTPUT     : 
#@RETURNS    : does not return -- either execs successfully or dies
#@DESCRIPTION: Run by the child process after we fork -- this takes care
#              of redirecting stdout (if appropriate) and stderr (likewise),
#              exec's the command, and bombs if the exec fails.
#@CALLERS    : spawn_redirect, spawn_capture
#@CALLS      : 
#@CREATED    : 1996/12/10, GPW
#@MODIFIED   : 1997/07/08, GPW (from JobControl.pm)
#-----------------------------------------------------------------------------
sub exec_command
{
   my ($command, $program, $stdout_mode, $stdout, $stderr_mode, $stderr) = @_;

   # Redirect stdout and/or stderr if the caller specified file
   # destination(s) (also possibly "capture" stderr via temp file)

   if ($stdout_mode == REDIRECT)
   {
      open (STDOUT, $stdout)
         || croak ("spawn: unable to redirect stdout to \"$stdout\": $!");
   }

   my $stderr_dest;
   if ($stderr_mode == REDIRECT)    { $stderr_dest = $stderr }
   elsif ($stderr_mode == CAPTURE)  { $stderr_dest = ">/tmp/error$$.log" }
   elsif ($stderr_mode == MERGE)    { $stderr_dest = ">&STDOUT" }

   if ($stderr_dest)
   {
      open (STDERR, $stderr_dest)
         || croak ("spawn: unable to redirect stderr to \"$stderr_dest\": $!");
   }

   # Exec that sucker!

   (ref $command)
      ? exec @$command
      : exec $command;

   # If we get here, the exec failed -- should not happen because of
   # the care we take to find the program in &check_program

   confess "spawn: exec of $program failed: $!";

}  # exec_command


# ------------------------------ MNI Header ----------------------------------
#@NAME       : capture_stream
#@INPUT      : $stream
#@OUTPUT     : $dest
#@RETURNS    : 
#@DESCRIPTION: Captures an entire input stream to a variable, which can
#              be either a scalar or array.  If we capture to a scalar,
#              all lines on the stream are concatenated with newlines 
#              preserved; if to an array, each array element gets one 
#              line, with newlines stripped.
#@METHOD     : 
#@GLOBALS    : 
#@CALLERS    : 
#@CALLS      : 
#@CREATED    : 1997/07/24, GPW
#@MODIFIED   : 
#-----------------------------------------------------------------------------
sub capture_stream
{
   my ($stream, $dest) = @_;

   local $/ = "\n";                     # just in case!
   $$dest = join ("", <$stream>), return if (ref $dest eq 'SCALAR');
   chomp (@$dest = <$stream>),    return if (ref $dest eq 'ARRAY');
   confess "capture_stream: \$dest must be scalar or array ref";
}



# ------------------------------ MNI Header ----------------------------------
#@NAME       : &gather_error
#@INPUT      : $pid   - process id of the now deceased child, presumed
#                       to have written its stderr to /tmp/error$pid.log
#                       (in fact, we crash 'n burn if this file is not found)
#@OUTPUT     : $dest  - (scalar or array ref) contents of stderr are put
#                       into the referenced variable
#@RETURNS    : $error - the contents of that temporary file -- all lines
#                       are concatented together, but the newlines are
#                       preserved
#@DESCRIPTION: Reads in a temporary file that was created to hold a
#              child process' stderr.
#@METHOD     : 
#@GLOBALS    : 
#@CALLERS    : spawn_redirect, spawn_capture
#@CALLS      : 
#@CREATED    : 1996/12/10, GPW (from &spawn_redirect and &spawn_capture)
#@MODIFIED   : 1997/07/08, GPW (from JobControl.pm)
#-----------------------------------------------------------------------------
sub gather_error
{
   my ($pid, $dest) = @_;
   my ($filename);

   $filename = "/tmp/error${pid}.log";

   open (ERROR, "<$filename") || 
      confess ("spawn: unable to open \"$filename\": $!");
   capture_stream (\*ERROR, $dest);
   close (ERROR);
   unlink ($filename) ||
      carp ("spawn: warning: unable to delete temporary file $filename: $!");
}  # gather_error


# ------------------------------ MNI Header ----------------------------------
#@NAME       : obituary
#@INPUT      : $status
#              $program
#              $command
#              $stdout_mode
#              $stderr_mode
#              $output
#              $error
#@OUTPUT     : 
#@RETURNS    : 
#@DESCRIPTION: Generates and mails a fairly detailed death notice to the 
#              address from the `notify' option.  (`notify' must be non-
#              empty, and `execute' must be true, for this to be done.)
#@GLOBALS    : $main::ProgramName
#@CALLERS    : check_status
#@CALLS      : 
#@CREATED    : 
#-----------------------------------------------------------------------------
sub obituary
{
   my ($self, $status, $program, $command, 
       $stdout_mode, $stderr_mode, $output, $error) = @_;

   my ($text, $cwd);

   if ($self->{notify} && $self->{execute})
   {
      $text = '';
      $cwd = getcwd();

      $text .= "$::ProgramName crashed" . 
         ($program ? " while running $program" : "") . "\n";
      $text .= "from directory: $cwd\n";

      if ($command)
      {
         $command = shellquote (@$command) if ref $command;
         $text .= "full command: $command\n";
      }

      if (($stdout_mode == CAPTURE && $output) ||
          ($stderr_mode == CAPTURE && $error))
      {
         my $p = $program || "the child program";
         $output = ref ($output eq 'ARRAY') ? join ("\n", @$output) : $$output;
         $error = ref ($error eq 'ARRAY') ? join ("\n", @$error) : $$error;
         $text .= "\nHere is ${p}'s standard output:\n$output\n"
            if ($stdout_mode == CAPTURE && $output);
         $text .= "\n\nHere is ${p}'s standard error:\n$error\n"
            if ($stderr_mode == CAPTURE && $error);
      }

      open (MAIL, "|/usr/lib/sendmail $self->{notify}");

      print MAIL <<EOM;
From: ($::ProgramName)
Subject: $::ProgramName crashed while running $program

Dear $self->{notify},

$text

EOM
      close (MAIL);
   }

   $program
      ? die "$::ProgramName: crashed while running $program " .
            "(termination status=$status)\n"
      : die "$::ProgramName: crashed while running another program " .
            "(termination status=$status)\n";

}  # obituary   
   
   
# ------------------------------ MNI Header ----------------------------------
#@NAME       : &check_status
#@INPUT      : $status
#              $program
#              $command
#              $stdout
#              $stderr
#              $output
#              $error
#@OUTPUT     : 
#@RETURNS    : 
#@DESCRIPTION: Checks the termination status of a program.  If it is zero
#              (the program exited normally, indicating "success" through a
#              zero exit status), we do nothing and return true.  (Note
#              that `spawn' then returns the termination status, which in
#              this case will be zero, to its caller.)
# 
#              If the termination status was non-zero, carries out the
#              instructions implicit in the `err_action' option.
#              Currently the following values are supported for
#              `err_action':
#                 `fatal'   - crash the whole program immediately
#                 `notify'  - send email to the address specified in the
#                             `notify' option, and *then* crash the whole
#                             program
#                 `warn'    - print a warning and return false
#                 `ignore'  - say nothing and return false
#
#              Alternately, `err_action' can be an arbitrary chunk of Perl
#              code, which is evaluated in the calling package; if there
#              are errors in this code, we again crash by calling croak.
#              Beware of making this code a single string of lowercase
#              letters, as I reserve the right to add more options like
#              `fatal' or `notify' that might cause conflicts.
#
#              Finally, if `err_action' is not supplied (eg. undefined or
#              the empty string), we act as though it were really `warn'
#              (for backwards compatibility).  Again, note that the return
#              value is turned around by `spawn' -- it will return the
#              termination status to its caller, which this time is
#              non-zero.
#@METHOD     : 
#@GLOBALS    : 
#@CALLERS    : 
#@CALLS      : 
#@CREATED    : 1996/01/17, GPW (from code in &Spawn)
#@MODIFIED   : 1997/07/08, GPW (from JobControl.pm)
#-----------------------------------------------------------------------------
sub check_status
{
   my ($self, $status, $program, $command,
       $stdout_mode, $stderr_mode, $output, $error) = @_;

   # Note to myself: $status is now the full 16-bit value as returned by
   # wait(2) (the termination status, as opposed to the exit status which
   # is passed to exit()).  I should do some bit-twiddling (preferably with
   # the help of "sys/wait.ph", but it's not cooperating right now) to
   # figure out what kind of crash, exit status, signal number, etc.

   if ($status)
   {
      my $ea = $self->{err_action};
      $ea = 'warn' unless $ea;          # backwards compatibility (empty string
                                        # or undefined same as 'warn')

      if ($ea eq 'fatal')
      {
         die "$::ProgramName: crashed while running $program " .
             "(termination status=$status)\n";
      }
      elsif ($ea eq 'notify')
      {
         $self->obituary ($status, $program, $command,
                          $stdout_mode, $stderr_mode, $output, $error);
      }
      elsif ($ea eq 'ignore')
      {
         return 0;
      }
      elsif ($ea eq 'warn')
      {
         warn "$::ProgramName: warning: " .
              "$program crashed (termination status=$status)\n";
         return 0;
      }
      elsif ($ea =~ /^[a-z_]+$/)        # looks like some other keyword
      {
         croak "spawn: unknown err_action keyword \"$ea\"";
      }
      elsif ($ea)                       # some chunk of code to be eval'd
      {
         carp "spawn: you should be using `notify' rather than " .
               "hard-coding a call to \&Obituary in `err_action'" 
            if $ea =~ /obituary/i;
         carp "spawn: you should be using `fatal' rather than " .
              "hard-coding a `die' in `err_action'" 
            if $ea =~ /die/;

         my $up_pkg = find_calling_package;

	 eval "package $up_pkg; $ea";
	 croak "spawn: error in err_action code: $@" if $@;
         return 0;
      }
   }
   else
   {
      return 1;
   }

}  # check_status


# ------------------------------ MNI Header ----------------------------------
#@NAME       : &spawn_capture
#@INPUT      : $command - [list ref or string] the full command
#              $program - the program name, as extracted by &complete_command
#              $stderr  - what to do with stderr.  Possible values:
#                  scalar ref : capture to referenced variable
#                  a string   : redirect to the named file
#@OUTPUT     : 
#@RETURNS    : $status - termination status of $command, ie. non-zero means
#                        failure or abnormal termination
#@DESCRIPTION: Run a command, capturing stdout to a variable.  stderr might
#              also be captured, but then again it might be redirected
#              (including possibly merged with stdout) or left intact.
#@METHOD     : forks and execs desired command with a pipe between parent
#              and child; captures stderr via a temporary file if it has
#              to
#@GLOBALS    : 
#@CALLERS    : spawn
#@CALLS      : exec_command, gather_error, check_status
#@CREATED    : 1996/12/10, GPW (from &Spawn)
#@MODIFIED   : 1997/07/08, GPW (from JobControl.pm)
#-----------------------------------------------------------------------------
sub spawn_capture
{
   my ($self, $command, $program,
       $stdout_mode, $stdout, $stderr_mode, $stderr) = @_;
   my ($pid, $status);

   # Run the command through a pipe.  In the child, stdout automagically
   # goes to the pipe; in the parent, we will slurp the child's output from
   # the pipe.  stderr is dealt with according to $stderr_mode -- either
   # it's captured (via a temporary file), or it's redirected to some other
   # file, or it's merged with stdout (which is actually handled as a
   # redirect to "&STDOUT" -- this is done by exec_command), or it's
   # left untouched.

   $pid = open (PIPE, "-|");
   croak "spawn: failed to start child process: $!" unless defined $pid;

   if ($pid == 0)                       # if in the child, then exec --
   {                                    # this doesn't return!
      exec_command ($command, $program,
                    $stdout_mode, $stdout, $stderr_mode, $stderr);
   }

   # $pid is not 0, so we're in the parent.  We read in the child's stdout
   # (and stderr too if it was captured).

   capture_stream (\*PIPE, $stdout);
   close (PIPE);
   $status = $?;                        # get child's termination status

   if ($stderr_mode == CAPTURE)         # did we "capture" stderr?
   {                                    # then read it in from temp file
      gather_error ($pid, $stderr);
   }

   $self->check_status ($status, $program, $command,
                        $stdout_mode, $stderr_mode,
                        $stdout, 
                        ($stderr_mode == CAPTURE) ? $stderr : undef);

   return $status;
}


# ------------------------------ MNI Header ----------------------------------
#@NAME       : &spawn_redirect
#@INPUT      : $command - [list ref or string] the full command
#              $program - the program name, as extracted by &complete_command
#              $stdout  - what to do with stdout
#              $stderr  - what to do with stderr
#@OUTPUT     : 
#@RETURNS    : $status  - termination status of $command, ie. non-zero means
#                         failure or abnormal termination
#@DESCRIPTION: Run a command, redirecting stdout to a file or leaving it
#              intact.  stderr might likewise be redirected to file, merged
#              with stdout, captured to a variable (via a temporary file),
#              or left untouched.
#@METHOD     : 
#@GLOBALS    : 
#@CALLERS    : spawn
#@CALLS      : exec_command, gather_error, check_status
#@CREATED    : 1996/12/10, GPW (from &Spawn)
#@MODIFIED   : 1997/07/08, GPW (from JobControl.pm)
#-----------------------------------------------------------------------------
sub spawn_redirect
{
   my ($self, $command, $program,
       $stdout_mode, $stdout, $stderr_mode, $stderr) = @_;
   my ($pid, $status);

   $pid = fork;
   croak "spawn: failed to start child process: $!" unless defined $pid;

   if ($pid == 0)                       # if in the child, then exec --
   {                                    # this doesn't return!
      exec_command ($command, $program,
                    $stdout_mode, $stdout, $stderr_mode, $stderr);
   }


   # $pid is not 0, so we're in the parent; block and wait for child.

   if (waitpid ($pid, 0) == -1)
   {
      confess "spawn: no child processes even though I just forked!";
   }

   $status = $?;

   if ($stderr_mode == CAPTURE)
   {
      gather_error ($pid, $stderr);
   }

   $self->check_status ($status, $program, $command,
                        $stdout_mode, $stderr_mode,
                        undef,
                        ($stderr_mode == CAPTURE) ? $stderr : undef);

   return $status;
}


# ----------------------------------------------------------------------
# The conventional, subroutine interface
# ----------------------------------------------------------------------

my $default_spawner = new MNI::Spawn;

sub SetOptions        { $default_spawner->set_options (@_); }
sub FindPrograms      { $default_spawner->find_programs (@_); }
sub AddDefaultArgs    { $default_spawner->add_default_args (@_); }
sub ClearDefaultArgs  { $default_spawner->clear_default_args (@_); }
sub Spawn             { $default_spawner->spawn (@_); }

1;
