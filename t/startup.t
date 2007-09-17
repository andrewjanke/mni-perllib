#! /usr/bin/env perl

use warnings "all";

require "t/compare.pl";
require "t/fork_test.pl";

my $i = 0;
sub test { printf "%s %d\n", ($_[0] ? "ok" : "not ok"), ++$i; }
sub announce { printf "test %d: %s\n", $i+1, $_[0] if $DEBUG }

print "1..26\n";

$DEBUG = 1;

$sub_check = <<'SUB';
my $num_errors = 0;
sub check
{
   my ($gripe, $test) = @_;

   unless ($test)
   {
      warn "$gripe\n";
      $num_errors++;
   }
}
SUB

if (1)
{
   announce 'normal usage, check for all exported variables';
   ($status,$out,$err) = fork_script ($sub_check . <<'SCRIPT');
use MNI::Startup;

check ("no verbose", $Verbose);
check ("no execute", $Execute);
check ("no clobber", defined $Clobber && !$Clobber);
check ("no debug"  , defined $Debug && !$Debug);
check ("no progname", $ProgramName && defined $ProgramDir);
check ("bad progdir", $ProgramDir eq '' || $ProgramDir =~ m|/$|);
check ("no startdir", $StartDir && defined $StartDirName);
check ("bad startdir", $StartDir =~ m|^/.*/$|);
check ("bad tmpdir" , $TmpDir && $TmpDir =~ m|/${ProgramName}_${$}/$|);
check ("no keeptmp", defined $KeepTmp && !$KeepTmp);
check ("no option table", @DefaultArgs);
SCRIPT
      
   test ($status == 0 &&
         (shift @$out) eq "** BEGIN TEST" &&
         @$out == 2 &&
         $out->[0] =~ /^Elapsed time/ &&
         $out->[1] =~ /\(user\).*\(system\).*\(total\)/ &&
         @$err == 0);
}

if (1)
{
   announce 'redundant positive options';
   ($status,$out,$err) = fork_script ($sub_check . <<'SCRIPT');
use MNI::Startup qw(optvars opttable progname startdir cputimes cleanup sig);

check ("no verbose", $Verbose);
check ("no execute", $Execute);
check ("no clobber", defined $Clobber && !$Clobber);
check ("no debug"  , defined $Debug && !$Debug);
check ("no progname", $ProgramName && defined $ProgramDir);
check ("no startdir", $StartDir && defined $StartDirName);
check ("bad tmpdir" , $TmpDir && $TmpDir =~ m|/${ProgramName}_${$}/$|);
check ("no keeptmp", defined $KeepTmp && !$KeepTmp);
check ("no option table", @DefaultArgs);
SCRIPT
      
   test ($status == 0 &&
         (shift @$out) eq "** BEGIN TEST" &&
         @$out == 2 &&
         $out->[0] =~ /^Elapsed time/ &&
         $out->[1] =~ /\(user\).*\(system\).*\(total\)/ &&
         @$err == 0);
}

if (1)
{
   announce 'no option variables';
   ($status,$out,$err) = fork_script (<<'SCRIPT');
use MNI::Startup qw(nooptvars);

die "unexpected variables defined\n" 
   if defined $Verbose || defined $Execute || defined $Clobber || 
      defined $Debug || defined $TmpDir || defined $KeepTmp;
die "expected variable not defined\n"
   unless @DefaultArgs && $ProgramName && defined $ProgramDir && 
          $StartDir && defined $StartDirName;
SCRIPT
      
   test ($status == 0 &&
         (shift @$out) eq "** BEGIN TEST" &&
         @$out == 0 &&
         @$err == 0);
}

if (1)
{
   announce 'no option table';
   ($status,$out,$err) = fork_script (<<'SCRIPT');
use MNI::Startup qw(optvars noopttable);

die "expected variables not defined\n" 
   unless defined $Verbose && defined $Execute && defined $Clobber &&
          defined $Debug && defined $TmpDir && defined $KeepTmp &&
          $ProgramName && defined $ProgramDir && 
          $StartDir && defined $StartDirName;
   die "unexpected variable defined\n"
      if @DefaultArgs;
SCRIPT
      
   test ($status == 0 &&
         (shift @$out) eq "** BEGIN TEST" &&
         @$out == 2 &&
         $out->[0] =~ /^Elapsed time/ &&
         $out->[1] =~ /\(user\).*\(system\).*\(total\)/ &&
         @$err == 0);
}

if (1)
{
   announce 'no progname';
   ($status,$out,$err) = fork_script (<<'SCRIPT');
use MNI::Startup qw(noprogname);

die "expected variables not defined\n" 
   unless defined $Verbose && defined $Execute && defined $Clobber &&
          defined $Debug && defined $TmpDir && defined $KeepTmp &&
          $StartDir && defined $StartDirName && @DefaultArgs;
   die "unexpected variable defined\n"
      if defined $ProgramName || defined $ProgramDir;
SCRIPT
      
   test ($status == 0 &&
         (shift @$out) eq "** BEGIN TEST" &&
         @$out == 2 &&
         $out->[0] =~ /^Elapsed time/ &&
         $out->[1] =~ /\(user\).*\(system\).*\(total\)/ &&
         @$err == 0);
}

if (1)
{
   announce 'no startdir';
   ($status,$out,$err) = fork_script (<<'SCRIPT');
use MNI::Startup qw(nostartdir);

die "expected variables not defined\n" 
   unless defined $Verbose && defined $Execute && defined $Clobber &&
          defined $Debug && defined $TmpDir && defined $KeepTmp &&
          $ProgramName && defined $ProgramDir && 
          @DefaultArgs;
   die "unexpected variable defined\n"
      if defined $StartDir || defined $StartDirName;
SCRIPT
      
   test ($status == 0 &&
         (shift @$out) eq "** BEGIN TEST" &&
         @$out == 2 &&
         $out->[0] =~ /^Elapsed time/ &&
         $out->[1] =~ /\(user\).*\(system\).*\(total\)/ &&
         @$err == 0);
}

if (1)
{
   announce 'no cputimes';
   ($status,$out,$err) = fork_script (<<'SCRIPT');
use MNI::Startup qw(nocputimes);

die "expected variables not defined\n" 
   unless defined $Verbose && defined $Execute && defined $Clobber &&
          defined $Debug && defined $TmpDir && defined $KeepTmp &&
          $ProgramName && defined $ProgramDir && 
          $StartDir && defined $StartDirName;
          $ProgramName && defined $ProgramDir;
SCRIPT
      
   test ($status == 0 &&
         (shift @$out) eq "** BEGIN TEST" &&
         @$out == 0 &&
         @$err == 0);
}

if (1)
{
   announce 'no cputimes (because $Verbose false)';
   ($status,$out,$err) = fork_script (<<'SCRIPT');
use MNI::Startup;

die "expected variables not defined\n" 
   unless defined $Verbose && defined $Execute && defined $Clobber &&
          defined $Debug && defined $TmpDir && defined $KeepTmp &&
          $ProgramName && defined $ProgramDir && 
          $StartDir && defined $StartDirName;
          $ProgramName && defined $ProgramDir;
$MNI::Startup::Verbose = 0;
SCRIPT
      
   test ($status == 0 &&
         (shift @$out) eq "** BEGIN TEST" &&
         @$out == 0 &&
         @$err == 0);
}

if (1)
{
   announce 'cleanup of temp directory';
   ($status,$out,$err) = fork_script (<<'SCRIPT');
use MNI::Startup;

print "TmpDir = $TmpDir\n";
die "$TmpDir already exists\n" if -e $TmpDir;
mkdir ($TmpDir, 0755) || die "couldn't create $TmpDir: $!\n";
system "cp t/*.t $TmpDir";
die "cp failed\n" if $?;
SCRIPT

   test ($status == 0 &&
         (shift @$out) eq "** BEGIN TEST" &&
         @$out == 3 &&
         (($tmpdir) = $out->[0] =~ /TmpDir = (.*)/) &&
         ! -e $tmpdir &&
         @$err == 0);
}

if (1)
{
   announce 'non-cleanup of custom temp directory';
   ($status,$out,$err) = fork_script (<<'SCRIPT');
use MNI::Startup;

$TmpDir = "temp";
print "TmpDir = $TmpDir\n";
mkdir ($TmpDir, 0755) || die "couldn't create $TmpDir: $!\n"
   unless -d $TmpDir;
system "cp t/*.t $TmpDir";
die "cp failed\n" if $?;
SCRIPT

   test ($status == 0 &&
         (shift @$out) eq "** BEGIN TEST" &&
         @$out == 3 &&
         (($tmpdir) = $out->[0] =~ /TmpDir = (.*)/) &&
         -d $tmpdir &&
         `cd $tmpdir ; ls *` eq `cd t ; ls *.t` &&
         @$err == 0);
   system 'rm', '-rf', $tmpdir;
   warn "rm -rf $tmpdir failed\n" if $?;
}

if (1)
{
   announce 'cleanup of relative temp directory';
   $ENV{'TMPDIR'} = '.';
   ($status,$out,$err) = fork_script (<<'SCRIPT');
use MNI::Startup;

print "TmpDir = $TmpDir\n";
mkdir ($TmpDir, 0755) || die "couldn't create $TmpDir: $!\n"
   unless -d $TmpDir;
system "cp t/*.t $TmpDir";
die "cp failed\n" if $?;
SCRIPT

   test ($status == 0 &&
         (shift @$out) eq "** BEGIN TEST" &&
         @$out == 3 &&
         (($tmpdir) = $out->[0] =~ /TmpDir = (.*)/) &&
         $tmpdir =~ m|^/.*/./| &&
         ! -e $tmpdir &&
         @$err == 0);
   system 'rm', '-rf', $tmpdir;
   warn "rm -rf $tmpdir failed\n" if $?;
}

if (1)
{
   announce 'suppress cleanup (via nocleanup)';
   ($status,$out,$err) = fork_script (<<'SCRIPT');
use MNI::Startup qw(nocleanup);

print "TmpDir = $TmpDir\n";
die "$TmpDir already exists\n" if -e $TmpDir;
mkdir ($TmpDir, 0755) || die "couldn't create $TmpDir: $!\n";
system "cp t/*.t $TmpDir";
die "cp failed\n" if $?;
SCRIPT

   test ($status == 0 &&
         (shift @$out) eq "** BEGIN TEST" &&
         @$out == 3 &&
         (($tmpdir) = $out->[0] =~ /TmpDir = (.*)/) &&
         -d $tmpdir &&
         `cd $tmpdir ; ls *` eq `cd t ; ls *.t` &&
         @$err == 0);
   system 'rm', '-rf', $tmpdir;
   warn "rm -rf $tmpdir failed\n" if $?;
}

if (1)
{
   announce 'suppress cleanup (via $KeepTmp)';
   ($status,$out,$err) = fork_script (<<'SCRIPT');
use MNI::Startup;

print "TmpDir = $TmpDir\n";
$KeepTmp = 1;
die "$TmpDir already exists\n" if -e $TmpDir;
mkdir ($TmpDir, 0755) || die "couldn't create $TmpDir: $!\n";
system "cp t/*.t $TmpDir";
die "cp failed\n" if $?;
SCRIPT

   test ($status == 0 &&
         (shift @$out) eq "** BEGIN TEST" &&
         @$out == 3 &&
         (($tmpdir) = $out->[0] =~ /TmpDir = (.*)/) &&
         -d $tmpdir &&
         `cd $tmpdir ; ls *` eq `cd t ; ls *.t` &&
         @$err == 0);
   system 'rm', '-rf', $tmpdir;
   warn "rm -rf $tmpdir failed\n" if $?;
}

if (1)
{
   announce 'cleanup (despite $TmpDir undefined)';
   ($status,$out,$err) = fork_script (<<'SCRIPT');
use MNI::Startup;

print "TmpDir = $TmpDir\n";
die "$TmpDir already exists\n" if -e $TmpDir;
mkdir ($TmpDir, 0755) || die "couldn't create $TmpDir: $!\n";
system "cp t/*.t $TmpDir";
die "cp failed\n" if $?;
undef $TmpDir;
SCRIPT

   test ($status == 0 &&
         (shift @$out) eq "** BEGIN TEST" &&
         @$out == 3 &&
         (($tmpdir) = $out->[0] =~ /TmpDir = (.*)/) &&
         ! -e $tmpdir &&
         @$err == 0);
   system 'rm', '-rf', $tmpdir;
   warn "rm -rf $tmpdir failed\n" if $?;
}

if (1)
{
   announce 'signal handling';
   ($status,$out,$err) = fork_script (<<'SCRIPT');
use MNI::Startup;

$| = 1;
print "TmpDir = $TmpDir\n";
die "$TmpDir already exists\n" if -e $TmpDir;
mkdir ($TmpDir, 0755) || die "couldn't create $TmpDir: $!\n";
system "cp t/*.t $TmpDir";
die "cp failed\n" if $?;
kill 15, $$;                            # commit suicide
SCRIPT

   test (($status & 0x7F) == 15 &&    # doesn't work because catch_signal dies
         (shift @$out) eq "** BEGIN TEST" &&
         @$out == 1 &&
         (($tmpdir) = $out->[0] =~ /TmpDir = (.*)/) &&
         ! -e $tmpdir &&
         @$err == 1 &&
         $err->[0] eq '-e: terminated');

   if (defined $tmpdir && -e $tmpdir)
   {
      system 'rm', '-rf', $tmpdir;
      warn "rm -rf $tmpdir failed\n" if $?;
   }
}

if (1)
{
   announce 'suppressed signal handling';
   ($status,$out,$err) = fork_script (<<'SCRIPT');
use MNI::Startup qw(nosig);

$| = 1;
print "TmpDir = $TmpDir\n";
die "$TmpDir already exists\n" if -e $TmpDir;
mkdir ($TmpDir, 0755) || die "couldn't create $TmpDir: $!\n";
system "cp t/*.t $TmpDir";
die "cp failed\n" if $?;
kill 15, $$;                        # commit suicide
SCRIPT

   test (($status & 0x7F) == 15 &&
         (shift @$out) eq "** BEGIN TEST" &&
         @$out == 1 &&
         (($tmpdir) = $out->[0] =~ /TmpDir = (.*)/) &&
         -e $tmpdir &&
         -e "$tmpdir/startup.t" &&
         @$err == 0);

   if (defined $tmpdir && -e $tmpdir)
   {
      system 'rm', '-rf', $tmpdir;
      warn "rm -rf $tmpdir failed\n" if $?;
   }
}

if (1)
{
   announce 'self_announce';
   ($status,$out,$err) = fork_script (<<'SCRIPT', ['foo', '', 'bar()foo']);
use MNI::Startup;

open (SAVE_STDOUT, ">&STDOUT") || die "couldn't save stdout: $!\n";
open (STDOUT, ">/dev/tty") || die "couldn't redirect stdout: $!\n";
self_announce;
open (STDOUT, ">&SAVE_STDOUT") || die "couldn't restore stdout: $!\n";
SCRIPT
   test ($status == 0 &&
         (shift @$out) eq "** BEGIN TEST" &&
         @$out == 2 &&
#         $out->[0] =~ /\[\w+@[\w.]+:\/.*\] \[[\d:\s-]+\]/ &&
#         $out->[1] eq q[  -e foo '' 'bar()foo'] &&
#         $out->[2] eq '' &&
         $out->[0] =~ /^Elapsed time/ &&
         $out->[1] =~ /\(user\).*\(system\).*\(total\)/ &&
         @$err == 0);
}

if (1)
{
   announce 'self_announce (forced)';
   ($status,$out,$err) = fork_script (<<'SCRIPT', ['foo', '', 'bar()foo']);
use MNI::Startup;

self_announce (undef, undef, undef, 1);
SCRIPT
   test ($status == 0 &&
         (shift @$out) eq "** BEGIN TEST" &&
         @$out == 5 &&
         $out->[0] =~ /\[\w+@[\w.]+:\/.*\] \[[\d:\s-]+\]/ &&
         $out->[1] eq q[  -e foo '' 'bar()foo'] &&
         $out->[2] eq '' &&
         $out->[3] =~ /^Elapsed time/ &&
         $out->[4] =~ /\(user\).*\(system\).*\(total\)/ &&
         @$err == 0);
}

if (1)
{
   announce 'self_announce to log (filehandle)';
   unlink ('log');
   ($status,$out,$err) = fork_script (<<'SCRIPT', ['foo', '', 'bar()foo']);
use MNI::Startup;

open (LOG, '>log') || die "couldn't open log: $!\n";
self_announce (\*LOG);
SCRIPT
   @log = file_contents ('log');
   test ($status == 0 &&
         (shift @$out) eq "** BEGIN TEST" &&
         @$out == 2 &&
         $log[0] =~ /\[\w+@[\w.]+:\/.*\] \[[\d:\s-]+\]/ &&
         $log[1] eq q[  -e foo '' 'bar()foo'] &&
         @$err == 0);
   unlink ('log') || warn "couldn't unlink log: $!\n";
}

eval { require IO::File };
if ($@ && $@ =~ m|^Can\'t locate IO/File\.pm|)
{
   $use_filehandle = 1;
}

if (1)
{
   announce 'self_announce to log (IO::File or FileHandle)';
   unlink ('log');
   $script = <<'SCRIPT';
use IO::File;
use MNI::Startup;

$log = new IO::File '>log' or die "couldn't open log: $!\n";
self_announce ($log);
SCRIPT
   $script =~ s/IO::File/FileHandle/gm
      if $use_filehandle;

   ($status,$out,$err) = fork_script ($script, ['foo', '', 'bar()foo']);
   @log = file_contents ('log');
   test ($status == 0 &&
         (shift @$out) eq "** BEGIN TEST" &&
         @$out == 2 &&
         $log[0] =~ /\[\w+@[\w.]+:\/.*\] \[[\d:\s-]+\]/ &&
         $log[1] eq q[  -e foo '' 'bar()foo'] &&
         @$err == 0);
   unlink ('log') || warn "couldn't unlink log: $!\n";
}

if (1)
{
   announce 'self_announce to bogus log';
   ($status,$out,$err) = fork_script (<<'SCRIPT', ['foo', '', 'bar()foo']);
use MNI::Startup;

self_announce ("log");
SCRIPT
   test ($status != 0 &&
         (shift @$out) eq "** BEGIN TEST" &&
         @$out == 0 &&
         @$err == 1 &&
         $err->[0] =~ /if supplied, \$log must be an open filehandle/);
}


            
$bg_script_preamble = <<'PREAMBLE';
END { 
   if (defined $pid && $bg)
   {
      print "signalling process $pid\n";
      kill "USR1", $pid or warn "kill $pid: $!\n";
   }
}

use MNI::Startup;

die "no pid argument\n" unless @ARGV >= 1 && $ARGV[0] =~ /^\d+$/;
$pid = $ARGV[0];
PREAMBLE

if (1)
{
   announce 'backgroundify to filename';

   $script = $bg_script_preamble . <<'SCRIPT';
print "now in foreground\n";
backgroundify ("log");
$bg = 1;
print "now in background\n";
SCRIPT

   unlink ('log');
   my $oktogo = 0;
   $SIG{'USR1'} = sub { $oktogo = 1; };      
   ($status,$out,$err) = fork_script ($script, [$$]);
   sleep 1 while !$oktogo;
   $SIG{'USR1'} = 'DEFAULT';
   
   @log = file_contents ('log');

   test ($status == 0 &&
         (shift @$out) eq "** BEGIN TEST" &&
         @$out == 2 &&
         $out->[0] eq 'now in foreground' &&
         $out->[1] =~ /redirecting output to log and detaching to background/ &&
         @log == 7 &&
         $log[0] =~ /\[\w+@[\w.]+:\/.*\] \[[\d:\s-]+\]/ &&
         $log[1] eq "  -e $$" &&
         $log[3] eq 'now in background' &&
         $log[4] =~ /^Elapsed time/ &&
         $log[5] =~ /\(user\).*\(system\).*\(total\)/ &&
         $log[6] eq "signalling process $$" &&
         @$err == 0);
   unlink ('log') || warn "couldn't unlink log: $!\n";   
}

if (1)
{
   announce 'backgroundify to filehandle';
   unlink ('log');
   $script = $bg_script_preamble . <<'SCRIPT';
print "now in foreground\n";
open (LOG, '>log') || die "couldn't open log: $!\n";
backgroundify (\*LOG);
$bg = 1;
print "now in background\n";
SCRIPT

   unlink ('log');
   my $oktogo = 0;
   $SIG{'USR1'} = sub { $oktogo = 1; };      
   ($status,$out,$err) = fork_script ($script, [$$]);
   sleep 1 while !$oktogo;
   $SIG{'USR1'} = 'DEFAULT';

   @log = file_contents ('log');
   test ($status == 0 &&
         (shift @$out) eq "** BEGIN TEST" &&
         @$out == 2 &&
         $out->[0] eq 'now in foreground' &&
         $out->[1] =~ /redirecting output and detaching to background/ &&
         @log == 7 &&
         $log[0] =~ /\[\w+@[\w.]+:\/.*\] \[[\d:\s-]+\]/ &&
         $log[1] eq "  -e $$" &&
         $log[3] eq 'now in background' &&
         $log[4] =~ /^Elapsed time/ &&
         $log[5] =~ /\(user\).*\(system\).*\(total\)/ &&
         $log[6] eq "signalling process $$" &&
         @$err == 0);
   unlink ('log') || warn "couldn't unlink log: $!\n";   
}

if (1)
{
   announce 'backgroundify to IO::File (or FileHandle) object';
   unlink ('log');
   $script = $bg_script_preamble . <<'SCRIPT';
use IO::File;

print "now in foreground\n";
$log = new IO::File '>log' or die "couldn't open log: $!\n";
backgroundify ($log);
$bg = 1;
print "now in background\n";
SCRIPT

   $script =~ s/IO::File/FileHandle/gm
      if $use_filehandle;

   unlink ('log');
   my $oktogo = 0;
   $SIG{'USR1'} = sub { $oktogo = 1; };      
   ($status,$out,$err) = fork_script ($script, [$$]);
   sleep 1 while !$oktogo;
   $SIG{'USR1'} = 'DEFAULT';

   @log = file_contents ('log');
   test ($status == 0 &&
         (shift @$out) eq "** BEGIN TEST" &&
         @$out == 2 &&
         $out->[0] eq 'now in foreground' &&
         $out->[1] =~ /redirecting output and detaching to background/ &&
         @log == 7 &&
         $log[0] =~ /\[\w+@[\w.]+:\/.*\] \[[\d:\s-]+\]/ &&
         $log[1] eq "  -e $$" &&
         $log[3] eq 'now in background' &&
         $log[4] =~ /^Elapsed time/ &&
         $log[5] =~ /\(user\).*\(system\).*\(total\)/ &&
         $log[6] eq "signalling process $$" &&
         @$err == 0);
   unlink ('log') || warn "couldn't unlink log: $!\n";   
}

if (1)
{
   announce 'die, nothing to cleanup';
   ($status,$out,$err) = fork_script (<<'SCRIPT');
use MNI::Startup;
die;
SCRIPT

#    if (($pid = fork) == 0)              # child
#    {
#       exec $^X, '-e', 'use MNI::Startup; die;'
#    }
#    else                                 # parent
#    {
#       waitpid ($pid, 0) == $pid
#          || die "wrong (or no) child";
#       $status = $?;
#    }

   test ($status != 0 &&
         (shift @$out) eq "** BEGIN TEST" &&
         @$out == 0 &&
         @$err == 1 &&
         $err->[0] =~ /^died at -e line/i);
}

if (1)
{
   announce 'die with cleanup';
   ($status,$out,$err) = fork_script (<<'SCRIPT');
use MNI::Startup;
mkdir ($TmpDir, 0755) || die "couldn't mkdir $TmpDir: $!\n";
die;
SCRIPT
   test ($status != 0 &&
         (shift @$out) eq "** BEGIN TEST" &&
         @$out == 0 &&
         @$err == 1 &&
         $err->[0] =~ /^died at -e line/i);
}
