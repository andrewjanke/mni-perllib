select (STDERR); $| = 1;
select (STDOUT); $| = 1;

$0 =~ s|.*/||;
$tmp_dir = "/tmp/$0_$$";
mkdir ($tmp_dir, 0755) || die "couldn't mkdir $tmp_dir: $!\n";
$stdout_fifo = "$tmp_dir/fifo.stdout";
$stderr_fifo = "$tmp_dir/fifo.stderr";
system "mknod", $stdout_fifo, "p";
die "\"mknod $stdout_fifo\" failed\n" if $?;
system "mknod", $stderr_fifo, "p";
die "\"mknod $stderr_fifo\" failed\n" if $?;

$parent = $$;
sub cleanup
{
   return unless defined $parent && $$ == $parent;
   system "rm", "-rf", $tmp_dir;
   warn "\"rm -rf $tmp_dir\" failed\n" if $?;
}

END { cleanup }

sub file_contents
{
   my ($filename) = @_;

   open (F, $filename) || die "couldn't open $filename: $!\n";
   my @contents = <F>;
   chomp @contents;
   close (F);
   if ($DEBUG)
   {
      print "contents of file \"$filename\":\n";
      map { printf "%d: >%s<\n", $_, $contents[$_] } 0 .. $#contents;
   }

   return @contents;
}

sub fork_test
{
   my ($test, $expect_true) = @_;

#   select (STDERR); $| = 1; print '';
#   select (STDOUT); $| = 1; print '';
   
   my $pid = fork;
   die "couldn't fork: $!\n" unless defined $pid;


   if ($pid == 0)                       # in the child?
   {
#      open (TTY, ">/dev/tty");
      print "in child; pid=$$, now redirecting STDOUT and STDERR\n"
         if $DEBUG;
      open (STDOUT, ">$stdout_fifo");
      open (STDERR, ">$stderr_fifo");
      select (STDERR); $| = 1; print '';
      select (STDOUT); $| = 1; print '';

      print "** BEGIN TEST\n";
      my $result = &$test;
      if (defined $expect_true)
      {
         die "test code returned false unexpectedly\n" 
            if $expect_true && !$result;
         die "test code returned true unexpectedly\n" 
            if !$expect_true && $result;
      }

      print "** END TEST\n";
      
#      print TTY "child: done test, exiting\n";
#      close (TTY);
#      close (STDOUT);
#      close (STDERR);
      exit;
   }
   else                                 # in the parent?
   {
      print "in parent; mypid=$$, child=$pid, reading child's stdout/stderr\n"
         if $DEBUG;
      open (OUT, "<$stdout_fifo");
      open (ERR, "<$stderr_fifo");
      my @out = <OUT>;
      my @err = <ERR>;
      close (OUT);
      close (ERR);

      chomp @out;
      chomp @err;
      if ($DEBUG)
      {
         print "child stdout:\n"; 
         map { printf "%d: >%s<\n", $_, $out[$_] } 0 .. $#out;
         print "child stderr:\n";
         map { printf "%d: >%s<\n", $_, $err[$_] } 0 .. $#err;
      }

      my $done_pid = waitpid ($pid, 0);
      die "no child to wait for!\n" if $done_pid == -1;
      die "wrong child exited!\n" if $done_pid != $pid;
      print "child's termination status = " . ($?) . "\n" if $DEBUG;
      return ($?, \@out, \@err);
   }
}

sub fork_script
{
   my ($script, $args) = @_;

   my @args;
   @args = @$args if $args && ref $args eq 'ARRAY';
   fork_test (sub { exec $^X, '-e', $script, @args; }, 1);
}

1;
