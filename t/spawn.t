#! /usr/bin/env perl

use warnings "all";

# TODO (tests to add for recently found-and-fixed bugs):
# 
#  * make sure a copied spawning vat can have programs and default
#    args updated independently of its parent

use MNI::Spawn;
use FileHandle;

require "t/compare.pl";
require "t/fork_test.pl";

my $i = 0;
sub test { printf "%s %d\n", ($_[0] ? "ok" : "not ok"), ++$i; }
sub announce { printf "test %d: %s\n", $i+1, $_[0] if $DEBUG }

die "t/toy_ls not found (or not executable)\n"
   unless -x "t/toy_ls";

print "1..56\n";

($ProgramName = $0);                    # needed by Spawn!

chop ($cwd = `pwd`);
map { $_ = "$cwd/$_" unless m|^/|; } @INC; # so autoload will work after chdir

@sigs = qw(INT TERM QUIT HUP PIPE);
@SIG{@sigs} = map (\&cleanup, @sigs);

$DEBUG = exists $ENV{'SPAWN_TEST_DEBUG'} ? $ENV{'SPAWN_TEST_DEBUG'} : 0;

@path = grep ($_ ne '.', split (':', $ENV{'PATH'}));
$ENV{'PATH'} = join (':', '.', @path);

$errfile = "$tmp_dir/err";
$outfile = "$tmp_dir/out";

# This seems to be fairly standard -- it's just what toy_ls prints
# when its `stat' fails because a file isn't found.
$err_msg = "No such file or directory";


# create spawning vat w/ a couple of options
my $spawner = new MNI::Spawn (verbose => 0);
$spawner->set_options (execute => 1, 
                       strict => 0,
                       search_path => '.:t');
announce "object creation and option setting";
test (defined $spawner->{verbose} && 
      ! $spawner->{verbose} &&
      $spawner->{execute});

# very basic test
if (1)
{
   announce "basic spawn";
   test ($spawner->spawn ("toy_ls > /dev/null") == 0);
}


# just make sure the fork/pipe business is working (no spawns yet)
if (1)
{
   announce "fork/pipe with warning";
   ($status,$out,$err) = fork_test 
      (sub { print "Hello there\n"; warn "test warning\n"; }, undef);
   test ($status == 0 &&
         @$out == 3 &&
         $out->[0] eq "** BEGIN TEST" &&
         $out->[1] eq "Hello there" &&
         $out->[2] eq "** END TEST" &&
         @$err == 1 &&
         $err->[0] eq "test warning");
}

if (1)
{
   announce "fork/pipe with die";
   ($status,$out,$err) = fork_test 
      (sub { print "Another test\n"; die "ugh I'm dead\n"; }, undef);
   test ($status != 0 &&
         @$out == 2 &&
         $out->[0] eq "** BEGIN TEST" &&
         $out->[1] eq "Another test" &&
         @$err == 1 &&
         $err->[0] eq "ugh I'm dead");
}

chdir "t" || die "couldn't chdir into t: $!\n";
opendir (TDIR, ".") || die "couldn't opendir .: $!\n";
@files = sort grep (! /^\./, readdir (TDIR));
@t_files = grep (/\.t$/, @files);
closedir (TDIR);

if ($DEBUG >= 2)
{
   print "files:\n  " . join ("\n  ", @files) . "\n";
   print "t_files:\n  " . join ("\n  ", @t_files) . "\n";
}

# OK, now some simple tests with spawn; first, just execute a command
if (1)
{
   announce "basic spawn (string)";
   ($status,$out,$err) = fork_test 
      (sub { $spawner->spawn ("toy_ls") }, 0);
   test ($status == 0 && 
         (shift @$out) eq "** BEGIN TEST" &&
         (pop @$out) eq "** END TEST" &&
         @$out == @files &&
         slist_equal ($out, \@files) &&
         @$err == 0);
}

if (1)
{
   announce "basic spawn (with strictness)";
   ($status,$out,$err) = fork_test 
      (sub { $spawner->spawn ("toy_ls", strict => 1) }, 0);
   test ($status == 0 && 
         (shift @$out) eq "** BEGIN TEST" &&
         (pop @$out) eq "** END TEST" &&
         @$out == @files &&
         slist_equal ($out, \@files) &&
         @$err == 1 &&
         $err->[0] =~ /^spawn: warning: program.*not registered/);
}

# Now the same with an argument for the shell to expand
if (1)
{
   announce "spawn (string): argument for shell to expand";
   ($status,$out,$err) = fork_test 
      (sub { $spawner->spawn ("toy_ls *.t") }, 0);
   test ($status == 0 && 
         (shift @$out) eq "** BEGIN TEST" &&
         (pop @$out) eq "** END TEST" &&
         @$out == @t_files &&
         slist_equal ($out, \@t_files) &&
         @$err == 0);
}


# Try getting it to 'inherit' the verbose option from $main::Verbose...
# (NB. we can't test that $spawner is affected as expected, because that
# change takes place in the forked child process -- oops!)
if (1)
{
   announce "inherit default verbosity (on)";
   $spawner->set_options (verbose => undef);
   $Verbose = 1;
   ($status,$out,$err) = fork_test 
      (sub {
          $spawner->spawn ("toy_ls") && die "spawn failed\n";
          die "verbose not set\n" unless $spawner->{verbose};
       }, 1);
   test (@$out == @files+3 && 
         @$err == 0);

   announce "inherit default verbosity (off)";
#   $spawner->set_options (verbose => undef);
   $Verbose = 0;
   ($status,$out,$err) = fork_test 
      (sub {
          $spawner->spawn ("toy_ls") && die "spawn failed\n";
          die "verbose not defined-but-false\n" 
             unless defined $spawner->{verbose} && !$spawner->{verbose};
       }, 1);
   test (@$out == @files+2 && 
         @$err == 0);
}

# Try the no-args one again, this time with verbosity turned on
$spawner->set_options (verbose => 1);
if (1)
{
   announce "spawn (string) with verbosity";
   ($status,$out,$err) = fork_test 
      (sub { $spawner->spawn ("toy_ls") }, 0);
   test ($status == 0 && 
         (shift @$out) eq "** BEGIN TEST" &&
         (shift @$out) =~ m|^\[$ProgramName\] \[.+\@.+\:.+\] \[[\d-]+ [\d:]+\] ./toy_ls$| &&
         (pop @$out) eq "** END TEST" &&
         @$out == @files &&
         slist_equal ($out, \@files) &&
         @$err == 0);
}

# Now try command-as-list (no args)
if (1)
{
   announce "spawn (list) with verbosity";
   ($status,$out,$err) = fork_test 
      (sub { $spawner->spawn (["toy_ls"]) }, 0);
   test ($status == 0 && 
         (shift @$out) eq "** BEGIN TEST" &&
         (shift @$out) =~ m|^\[$ProgramName\] \[.+\@.+\:.+\] \[[\d-]+ [\d:]+\] ./toy_ls$| &&
         (pop @$out) eq "** END TEST" &&
         @$out == @files &&
         slist_equal ($out, \@files) &&
         @$err == 0);
}

# Command-as-list, with args
if (1)
{
   announce "spawn (list) with args";
   ($status,$out,$err) = fork_test 
      (sub { $spawner->spawn (["toy_ls", @t_files]) }, 0);
   test ($status == 0 && 
         (shift @$out) eq "** BEGIN TEST" &&
         (shift @$out) =~ m|^\[$ProgramName\] \[.+\@.+\:.+\] \[[\d-]+ [\d:]+\] ./toy_ls @t_files| &&
         (pop @$out) eq "** END TEST" &&
         @$out == @t_files &&
         slist_equal ($out, \@t_files) &&
         @$err == 0);
}


# ok, let's turn verbosity off so we don't have to keep checking it
$spawner->set_options (verbose => 0);

# Now one with an error -- we set err_action to 'warn' as a temporary
# override to the default 'fatal'.  (We also do a little sanity check here,
# to make sure that the "err_action => 'warn'" in spawn's arguments is
# indeed only temporary, ie. that the method indeed makes a copy of
# $spawner before modifying it.)

if (1)
{
   announce "spawn (list) with args and error";
   ($status,$out,$err) = fork_test 
      (sub
       {
          $spawner->spawn (["toy_ls", $files[0], "sldjfghf"],
                           err_action => 'warn');
          die "bad err_action\n"
             unless $spawner->{err_action} eq 'fatal';
       }, 1);
   test ($status == 0 &&                # non-zero only if spawn die's
         (shift @$out) eq "** BEGIN TEST" &&
         (pop @$out) eq "** END TEST" &&
         @$out == 1 && $out->[0] eq $files[0] &&
         @$err == 2 && 
         $err->[0] =~ /$err_msg/i &&
         $err->[1] =~ /toy_ls crashed/);
}

# Same error, but this time with the default err_action (which should be
# 'fatal')
if (1)
{
   announce "spawn (list) with args and fatal error";
   ($status,$out,$err) = fork_test 
      (sub
       {
          $spawner->spawn (["toy_ls", $files[0], "sldjfghf"]);
       }, 1);
   test ($status != 0 &&                # non-zero only if spawn die's
         (shift @$out) eq "** BEGIN TEST" &&
         @$out == 1 && $out->[0] eq $files[0] &&
         @$err == 2 && 
         $err->[0] =~ /$err_msg/i &&
         $err->[1] =~ /crashed while running toy_ls/);
}

# And again, but this time have spawn not report the error
if (1)
{
   announce "spawn (list) with args and ignored error";
   ($status,$out,$err) = fork_test 
      (sub
       {
          $spawner->spawn (["toy_ls", $files[0], "sldjfghf"],
                           err_action => 'ignore') && return 1;
          die "bad copy!" unless $spawner->{err_action} eq '';
          return 0;
       }, 1);
   test ($status == 0 &&                # non-zero only if spawn die's
         (shift @$out) eq "** BEGIN TEST" &&
         (pop @$out) eq "** END TEST" &&
         @$out == 1 && $out->[0] eq $files[0] &&
         @$err == 1 && 
         $err->[0] =~ /$err_msg/i);
}


# Try some redirection; first get the shell to do it

if (1)
{
   announce "spawn (string): shell redirect";
   ($status,$out,$err) = fork_test 
      (sub { $spawner->spawn ("toy_ls $files[0] > $outfile") },
       0);
   @outfile = file_contents ($outfile);
   test ($status == 0 &&
         (shift @$out) eq "** BEGIN TEST" &&
         (pop @$out) eq "** END TEST" &&
         @$out == 0 && @$err == 0 &&
         slist_equal (\@outfile, [$files[0]]));
   unlink ($outfile) || warn "couldn't unlink $outfile: $!\n";
}

# Now get spawn to redirect
if (1)
{
   announce "spawn (string): spawn redirect";
   ($status,$out,$err) = fork_test 
      (sub
       { 
          $spawner->spawn ("toy_ls $files[0]", stdout => $outfile) && return 1;
          die "bad copy!" 
             unless exists $spawner->{stdout} && ! defined $spawner->{stdout};
          return 0;
       }, 0);
   test ($status == 0 &&
         (shift @$out) eq "** BEGIN TEST" &&
         (pop @$out) eq "** END TEST" &&
         @$out == 0 && @$err == 0 &&
         slist_equal ([file_contents ($outfile)], [$files[0]]));
   unlink ($outfile) || warn "couldn't unlink $outfile: $!\n";
}

# And again, but this time with command-as-list
if (1)
{
   announce "spawn (list): spawn redirect";
   ($status,$out,$err) = fork_test 
      (sub { $spawner->spawn (["toy_ls", $files[0]], stdout => $outfile) },
       0);
   test ($status == 0 &&
         (shift @$out) eq "** BEGIN TEST" &&
         (pop @$out) eq "** END TEST" &&
         @$out == 0 && @$err == 0 &&
         slist_equal ([file_contents ($outfile)], [$files[0]]));
   unlink ($outfile) || warn "couldn't unlink $outfile: $!\n";
}

$spawner->set_options (err_action => 'warn');

# Same thing, but with an error merged with stdout (the default)
if (1)
{
   announce "spawn (list): spawn redirect with merged error";
   ($status,$out,$err) = fork_test 
      (sub { $spawner->spawn (["toy_ls", $files[0], "asdf"], 
                              stdout => $outfile) },
       1);

   @outfile = file_contents ($outfile);

   test ($status == 0 &&
         (shift @$out) eq "** BEGIN TEST" &&
         (pop @$out) eq "** END TEST" &&
         @$out == 0 &&
         @$err == 1 && 
         $err->[0] =~ /toy_ls crashed/ &&
         (shift @outfile) =~ /$err_msg/i &&
         slist_equal (\@outfile, [$files[0]]));
   unlink ($outfile) || warn "couldn't unlink $outfile: $!\n";
}

# kill 'STOP', $$;

# Now explicitly leave the error untouched
if (1)
{
   announce "spawn (list): spawn redirect with untouched error";
   ($status,$out,$err) = fork_test 
      (sub { $spawner->spawn (["toy_ls", $files[0], "asdf"], 
                              stdout => $outfile,
                              stderr => UNTOUCHED) },
       1);

   @out = file_contents ($outfile);

   test ($status == 0 &&
         ! -e 'UNTOUCHED' &&
         (shift @$out) eq "** BEGIN TEST" &&
         (pop @$out) eq "** END TEST" &&
         @$out == 0 &&
         @$err == 2 && 
         $err->[0] =~ /$err_msg/i &&
         $err->[1] =~ /toy_ls crashed/ &&
         slist_equal (\@outfile, [$files[0]]));
   unlink ($outfile) || warn "couldn't unlink $outfile: $!\n";
}

# Leave stdout alone, explicitly redirect stderr
if (1)
{
   announce "spawn (list): spawn with redirected error";
   ($status,$out,$err) = fork_test 
      (sub { $spawner->spawn (["toy_ls", $files[0], "asdf"], 
                              stderr => $errfile) },
       1);

   @err = file_contents ($errfile);
   test ($status == 0 &&
         (shift @$out) eq "** BEGIN TEST" &&
         (pop @$out) eq "** END TEST" &&
         @$out == 1 &&
         $out->[0] eq $files[0] &&
         @$err == 1 && 
         $err->[0] =~ /toy_ls crashed/ &&
         @err == 1 &&
         $err[0] =~ /$err_msg/i);
   unlink ($errfile) || warn "couldn't unlink $errfile: $!\n";
}

# Redirect stdout and stderr separately
if (1)
{
   announce "spawn (list): spawn with separately redirected stdout and stderr";
   ($status,$out,$err) = fork_test 
      (sub { $spawner->spawn (["toy_ls", $files[0], "asdf"], 
                              stdout => $outfile,
                              stderr => $errfile) },
       1);


   @out = file_contents ($outfile);
   @err = file_contents ($errfile);
   test ($status == 0 &&
         (shift @$out) eq "** BEGIN TEST" &&
         (pop @$out) eq "** END TEST" &&
         @$out == 0 &&
         @out == 1 &&
         $out[0] eq $files[0] &&
         @$err == 1 &&
         $err->[0] =~ /toy_ls crashed/ &&
         @err == 1 &&
         $err[0] =~ /$err_msg/i);
   unlink ($errfile) || warn "couldn't unlink $errfile: $!\n";
}

# Capture stdout, leave stderr alone
if (1)
{
   announce "spawn (list): spawn with captured stdout";
   ($status,$out,$err) = fork_test 
      (sub
       { 
          my $cap_out;
          $spawner->spawn (["toy_ls", $files[0], "asdf"], 
                           stdout => \$cap_out);
          chomp $cap_out;
          print "captured stdout = >$cap_out<\n";
       }, 
       1);

   test ($status == 0 &&
         (shift @$out) eq "** BEGIN TEST" &&
         (pop @$out) eq "** END TEST" &&
         @$out == 1 &&
         $out->[0] eq "captured stdout = >$files[0]<" &&
         @$err == 2 &&
         $err->[0] =~ /$err_msg/i &&
         $err->[1] =~ /toy_ls crashed/);
}

# Capture stdout and stderr separately
if (1)
{
   announce "spawn (list): spawn with separately captured stdout and stderr";
   ($status,$out,$err) = fork_test 
      (sub
       { 
          my ($cap_out, $cap_err);
          $spawner->spawn (["toy_ls", @files[0..2], "asdf"], 
                           stdout => \$cap_out,
                           stderr => \$cap_err);
          chomp $cap_out; chomp $cap_err;
          print "captured stdout:\n$cap_out\n";
          print "captured stderr:\n$cap_err\n";
       }, 
       1);

   test ($status == 0 &&
         (shift @$out) eq "** BEGIN TEST" &&
         (pop @$out) eq "** END TEST" &&
         @$out == 6 &&
         $out->[0] eq "captured stdout:" &&
         slist_equal ([@$out[1..3]], [@files[0..2]]) &&
         $out->[4] eq "captured stderr:" &&
         $out->[5] =~ /$err_msg/i &&
         @$err == 1 &&
         $err->[0] =~ /toy_ls crashed/);
}

# Same, but capture to array variables
if (1)
{
   announce "spawn (list): spawn with capture to arrays";
   ($status,$out,$err) = fork_test 
      (sub
       { 
          my ($cap_out, $cap_err);
          $spawner->spawn (["toy_ls", @files[0..2], "asdf"], 
                           stdout => \@cap_out,
                           stderr => \@cap_err);
          print "captured stdout:\n" . join ("\n", @cap_out) . "\n";
          print "captured stderr:\n" . join ("\n", @cap_err) . "\n";
       }, 
       1);

   test ($status == 0 &&
         (shift @$out) eq "** BEGIN TEST" &&
         (pop @$out) eq "** END TEST" &&
         @$out == 6 &&
         $out->[0] eq "captured stdout:" &&
         slist_equal ([@$out[1..3]], [@files[0..2]]) &&
         $out->[4] eq "captured stderr:" &&
         $out->[5] =~ /$err_msg/i &&
         @$err == 1 &&
         $err->[0] =~ /toy_ls crashed/);
}

# redirect to a filehandle
if (1)
{
   announce "spawn: redirect to filehandle";
   ($status,$out,$err) = fork_test (sub {
      open (LOG, ">$outfile") || die "couldn't create $outfile: $!\n";
      LOG->autoflush;
      print LOG "junk in log file before spawning\n";
      $spawner->spawn (["toy_ls", @t_files], stdout => ">&::LOG");
   }, 0);

   @outfile = file_contents ($outfile);
   test ($status == 0 &&
         (shift @$out) eq "** BEGIN TEST" &&
         (pop @$out) eq "** END TEST" &&
         @$out == 0 &&
         @$err == 0 &&
         (shift @outfile) eq 'junk in log file before spawning' &&
         slist_equal (\@outfile, \@t_files));
}

$spawner->set_options (err_action => 'fatal');

# Fiddle around with command completion features (searching and option
# adding); first make sure that 1) we get a warning when `strict' is 1 and
# 2) searching turns 'toy_ls' into './toy_ls'

$spawner->set_options (verbose => 1);
if (1)
{
   announce "spawn: strictness and path search";
#   $spawner->spawn ("toy_ls", strict => 1);
   ($status,$out,$err) = fork_test 
      (sub { $spawner->spawn ("toy_ls", strict => 1) },
       0);

   test ($status == 0 &&
         (shift @$out) eq "** BEGIN TEST" &&
         (pop @$out) eq "** END TEST" &&
         (shift @$out) =~ m|\] ./toy_ls$| &&
         @$out == @files &&
         slist_equal ($out, \@files) &&
         @$err == 1 &&
         $err->[0] =~ /program \"toy_ls\" not registered/);
}

# Now let's set a default option for "toy_ls", and make sure it has the
# expected effect.

$spawner->add_default_args ('toy_ls', ['-s']);
if (1)
{
   announce "spawn (string): default arguments (pre only)";
#   $spawner->spawn (["toy_ls"]);
    ($status,$out,$err) = fork_test (sub { $spawner->spawn ("toy_ls") }, 0);

   test (slist_equal ($spawner->{defargs}{pre}{toy_ls}, ['-s']) &&
         $status == 0 &&
         (shift @$out) eq "** BEGIN TEST" &&
         (pop @$out) eq "** END TEST" &&
         (shift @$out) =~ m|\] ./toy_ls -s$| &&
         @$out == @files &&
         (grep (s/^\s*\d+\s*//, @$out) == @$out) &&
         slist_equal ($out, \@files) &&
         @$err == 0);
}

# Do some default-args stuff in a child process just to make sure
# we get warnings as expected
if (1)
{
   announce "add_default_args: check for strictness warnings";
   ($status,$out,$err) = fork_test 
      (sub
       {
          $spawner->set_options (strict => 1);
          $spawner->add_default_args ('toy_ls', ['-s']);
          $spawner->clear_default_args ('toy_ls');
       }, 0);

   test ($status == 0 &&
         (shift @$out) eq "** BEGIN TEST" &&
         (pop @$out) eq "** END TEST" &&
         @$out == 0 &&
         @$err == 2 &&
         $err->[0] =~ /add_default_args: warning: adding default arguments for unregistered program/ &&
         $err->[1] =~ /clear_default_args: warning: clearing default arguments for unregistered program/);
}                                    

         
# Play around a bit with add_default_args and clear_default_args, just 
# to make sure they manipulate the spawning vat's internal data structures
# as expected

if (1)
{
   $spawner->add_default_args ('toy_ls', '-lt', 'pre');
   test (slist_equal ($spawner->{defargs}{pre}{toy_ls}, ['-s', '-lt']) &&
         ! defined $spawner->{defargs}{post}{toy_ls});

   $spawner->add_default_args ('toy_ls', ['*.foo'], 'post');
   test (slist_equal ($spawner->{defargs}{pre}{toy_ls}, ['-s', '-lt']) &&
         slist_equal ($spawner->{defargs}{post}{toy_ls}, ['*.foo']));

   $spawner->clear_default_args ('toy_ls', 'post');
   test (slist_equal ($spawner->{defargs}{pre}{toy_ls}, ['-s', '-lt']) &&
         ! defined $spawner->{defargs}{post}{toy_ls});

   $spawner->add_default_args ('toy_ls', ['*.foo', 'bar.*'], 'post');
   $spawner->clear_default_args ('toy_ls', 'pre');
   test (! defined $spawner->{defargs}{pre}{toy_ls} &&
         slist_equal ($spawner->{defargs}{post}{toy_ls}, ['*.foo', 'bar.*']));

   $spawner->add_default_args ('toy_ls', ['-alF', '-zonk']);
   $spawner->add_default_args ('toy_ls', 'zap', 'post');
   test (slist_equal ($spawner->{defargs}{pre}{toy_ls}, ['-alF', '-zonk']) &&
         slist_equal ($spawner->{defargs}{post}{toy_ls}, ['*.foo', 'bar.*', 'zap']));
   $spawner->clear_default_args ('toy_ls');
   test (! defined $spawner->{defargs}{pre}{toy_ls} &&
         ! defined $spawner->{defargs}{post}{toy_ls});

   $spawner->add_default_args ('toy_ls', ['-alF', '-zonk']);
   $spawner->add_default_args ('toy_ls', ['foo', 'bar', 'baz'], 'post');
   $spawner->clear_default_args ('toy_ls', 'both');
   test (! defined $spawner->{defargs}{pre}{toy_ls} &&
         ! defined $spawner->{defargs}{post}{toy_ls});
}

# Now a test with both "pre" and "post" default args
$spawner->clear_default_args ('toy_ls', 'both');
$spawner->add_default_args ('toy_ls', ['-s'], 'pre');
$spawner->add_default_args ('toy_ls', ['*.t'], 'post');
if (1)
{
   announce "spawn (string): default arguments (pre and post both)";
   ($status,$out,$err) = fork_test (sub { $spawner->spawn ("toy_ls") }, 0);

   test ($status == 0 &&
         (shift @$out) eq "** BEGIN TEST" &&
         (pop @$out) eq "** END TEST" &&
         (shift @$out) =~ m|\] ./toy_ls -s \*\.t$| &&
         @$out == @t_files &&
         (grep (s/^\s*\d+\s*//, @$out) == @$out) &&
         slist_equal ($out, \@t_files) &&
         @$err == 0);

}

# Same, but with command-as-list
$spawner->clear_default_args ('toy_ls', 'post');
$spawner->add_default_args ('toy_ls', [@t_files], 'post');
if (1)
{
   announce "spawn (list): default arguments (pre and post both)";
   ($status,$out,$err) = fork_test (sub { $spawner->spawn (["toy_ls"]) }, 0);

   test ($status == 0 &&
         (shift @$out) eq "** BEGIN TEST" &&
         (pop @$out) eq "** END TEST" &&
         (shift @$out) =~ m|\] ./toy_ls -s (.*\.t)+$| &&
         @$out == @t_files &&
         (grep (s/^\s*\d+\s*//, @$out) == @$out) &&
         slist_equal ($out, \@t_files) &&
         @$err == 0);
}

# OK, leave the default args in place, and fiddle around with disabling 
# them -- first by turning off `add_defaults'
if (1)
{
   announce "spawn (list): default arguments in place but disabled";
   ($status,$out,$err) = fork_test 
      (sub {
         $spawner->spawn (["toy_ls"], add_defaults => 0) 
      }, 0);

   test ($status == 0 &&
         (shift @$out) eq "** BEGIN TEST" &&
         (pop @$out) eq "** END TEST" &&
         (shift @$out) =~ m|\] ./toy_ls$| &&
         slist_equal ($out, \@files) &&
         @$err == 0);
}

# Now disable searching but leave default args enabled
if (1)
{
   announce "spawn (list): default args enabled, but searching disabled";
   ($status,$out,$err) = fork_test 
      (sub {
         $spawner->spawn (["toy_ls"], search => 0) 
      }, 0);

   test ($status == 0 &&
         (shift @$out) eq "** BEGIN TEST" &&
         (pop @$out) eq "** END TEST" &&
         (shift @$out) =~ m|\] toy_ls -s (.*\.t)+$| &&
         @$out == @t_files &&
         (grep (s/^\s*\d+\s*//, @$out) == @$out) &&
         slist_equal ($out, \@t_files) &&
         @$err == 0);
}

# Now disable all command completion (i.e. `add_options' and `search' 
# are ignored)
if (1)
{
   announce "spawn (list): all command completion disabled";
   ($status,$out,$err) = fork_test 
      (sub {
         $spawner->spawn (["toy_ls"], complete => 0) 
      }, 0);

   test ($status == 0 &&
         (shift @$out) eq "** BEGIN TEST" &&
         (pop @$out) eq "** END TEST" &&
         (shift @$out) =~ m|\] toy_ls$| &&
         slist_equal ($out, \@files) &&
         @$err == 0);
}

# Ditto, but with a backslash to disable completion (should also trigger
# a warning)
if (1)
{
   announce "spawn (list): command completion disabled with backslash";
   ($status,$out,$err) = fork_test (sub { $spawner->spawn (['\toy_ls']) }, 0);

   test ($status == 0 &&
         (shift @$out) eq "** BEGIN TEST" &&
         (pop @$out) eq "** END TEST" &&
         (shift @$out) =~ m|\] toy_ls$| &&
         slist_equal ($out, \@files) &&
         @$err == 1 &&
         $err->[0] =~ /spawn: warning: escaping commands with backslash is deprecated/);
}

# Same, but with command-as-string (don't need to do a string version
# for all the add_defaults/search tests because that's handled by
# check_program, which isn't involved in the string-vs-list stuff)

if (1)
{
   announce "spawn (string): all command completion disabled";
   ($status,$out,$err) = fork_test 
      (sub {
         $spawner->spawn ("toy_ls", complete => 0) 
      }, 0);

   test ($status == 0 &&
         (shift @$out) eq "** BEGIN TEST" &&
         (pop @$out) eq "** END TEST" &&
         (shift @$out) =~ m|\] toy_ls$| &&
         slist_equal ($out, \@files) &&
         @$err == 0);
}

# Again, repeat the no-complete test but with escape-by-backslash method
if (1)
{
   announce "spawn (string): all command completion disabled";
   ($status,$out,$err) = fork_test 
      (sub {
         $spawner->spawn ('\toy_ls') 
      }, 0);

   test ($status == 0 &&
         (shift @$out) eq "** BEGIN TEST" &&
         (pop @$out) eq "** END TEST" &&
         (shift @$out) =~ m|\] toy_ls$| &&
         slist_equal ($out, \@files) &&
         @$err == 1 &&
         $err->[0] =~ /spawn: warning: escaping commands with backslash is deprecated/);
}

$spawner->clear_default_args ('toy_ls');

open (LS, ">ls") || die "couldn't create \"ls\": $!\n";
print LS <<END;
#!/bin/sh
./toy_ls \$*
END
close (LS);
chmod (0755, "ls") || die "couldn't chmod \"ls\": $!\n";
die "\"ls\" isn't executable even though I chmod'd it!\n" unless -x "ls";

if (1)
{
   announce "test search path";
   ($status,$out,$err) = fork_test 
      (sub { $spawner->spawn ("ls *.t", search_path => ".") } );

   test ($status == 0 &&
         (shift @$out) eq "** BEGIN TEST" &&
         (pop @$out) eq "** END TEST" &&
         (shift @$out) =~ m|\] \./ls| &&
         slist_equal ($out, \@t_files) &&
         @$err == 0);
}

unlink "ls";


# A bunch of tests with a bogus program name -- these just check up on the
# various warning and error messages that result from trying to run a 
# non-registered, non-existent program

if (1)
{
   announce "spawn bogus command (with search)";
   ($status,$out,$err) = fork_test 
      (sub { $spawner->spawn ("blargsnob") } );
   test ($status != 0 &&
         (shift @$out) eq "** BEGIN TEST" &&
         @$out == 0 &&
         @$err == 2 &&
         $err->[0] =~ /^spawn: warning: couldn\'t find program/ &&
         $err->[1] =~ /: crashed while running/);
}

if (1)
{
   announce "spawn bogus command (strictness check)";
   ($status,$out,$err) = fork_test 
      (sub { $spawner->spawn ("blargsnob", strict => 1) } );
   test ($status != 0 &&
         (shift @$out) eq "** BEGIN TEST" &&
         @$out == 0 &&
         @$err == 3 &&
         $err->[0] =~ /^spawn: warning: program.*not registered/ &&
         $err->[1] =~ /^spawn: warning: couldn\'t find program/ &&
         $err->[2] =~ /: crashed while running/);
}

if (1)
{
   announce "spawn bogus command (super-strictness check)";
   ($status,$out,$err) = fork_test 
      (sub { $spawner->spawn ("blargsnob", strict => 2) } );
   test ($status != 0 &&
         (shift @$out) eq "** BEGIN TEST" &&
         @$out == 0 &&
         @$err == 1 &&
         $err->[0] =~ /^spawn: error: program.*not registered/);
}

if (1)
{
   announce "spawn bogus command (no search)";
   ($status,$out,$err) = fork_test 
      (sub { $spawner->spawn ("blargsnob", search => 0) } );
   test ($status != 0 &&
         (shift @$out) eq "** BEGIN TEST" &&
         (shift @$out) =~ /\] blargsnob$/ &&
         @$out == 0 &&
         @$err == 2 &&
         $err->[0] =~ /^spawn: exec.*failed/ &&
         $err->[1] =~ /: crashed while running/);
}

if (1)
{
   announce "spawn bogus command (strict, no search)";
   ($status,$out,$err) = fork_test 
      (sub { $spawner->spawn ("blargsnob", strict => 1, search => 0) } );
   test ($status != 0 &&
         (shift @$out) eq "** BEGIN TEST" &&
         (shift @$out) =~ /\] blargsnob$/ &&
         @$out == 0 &&
         @$err == 3 &&
         $err->[0] =~ /^spawn: warning: program.*not registered/ &&
         $err->[1] =~ /^spawn: exec.*failed/ &&
         $err->[2] =~ /: crashed while running/);
}

if (1)
{
   announce "spawn bogus command (strict, no completion)";
   ($status,$out,$err) = fork_test 
      (sub { $spawner->spawn ("blargsnob", strict => 1, complete => 0) } );
   test ($status != 0 &&
         (shift @$out) eq "** BEGIN TEST" &&
         (shift @$out) =~ /\] blargsnob$/ &&
         @$out == 0 &&
         @$err == 2 &&
         $err->[0] =~ /^spawn: exec.*failed/ &&
         $err->[1] =~ /: crashed while running/);
}


# Now test register_programs

$spawner->set_options (verbose => 1, strict => 1);

if (1)
{
   announce "register_programs and spawn (string): existing program";
   ($status,$out,$err) = fork_test 
      (sub
       {
          $spawner->register_programs (['toy_ls']);
          die "unexpected result of register_programs\n" 
             unless $spawner->{programs}{'toy_ls'} eq './toy_ls';
          $spawner->spawn ("toy_ls $files[0]")
             && die "spawn failed";
          return 0;
       }, 0);

   test ($status == 0 &&
         (shift @$out) eq "** BEGIN TEST" &&
         (pop @$out) eq "** END TEST" &&
         @$out == 2 &&
         $out->[0] =~ m|\] ./toy_ls $files[0]$| &&
         $out->[1] eq $files[0] &&
         @$err == 0);         
}

if (1)
{
   announce "register_programs and spawn (list): existing program";
   ($status,$out,$err) = fork_test 
      (sub
       {
          $spawner->register_programs (['toy_ls']);
          die "unexpected result of register_programs\n" 
             unless $spawner->{programs}{'toy_ls'} eq './toy_ls';
          $spawner->spawn (['toy_ls', $files[0]])
             && die "spawn failed";
          return 0;
       }, 0);

   test ($status == 0 &&
         (shift @$out) eq "** BEGIN TEST" &&
         (pop @$out) eq "** END TEST" &&
         @$out == 2 &&
         $out->[0] =~ m|\] ./toy_ls $files[0]$| &&
         $out->[1] eq $files[0] &&
         @$err == 0);         
}

if (1)
{
   announce "register_programs: bogus program";
   ($status,$out,$err) = fork_test 
      (sub
       {
          $ok = $spawner->register_programs (['blargsnob']);
          die "unexpected result of register_programs" if $ok;
          return $spawner->spawn ("blargsnob $files[0]");
       }, 1);

   test ($status != 0 &&
         (shift @$out) eq "** BEGIN TEST" &&
         @$out == 0 &&
         @$err == 4 &&
         $err->[0] =~ /: couldn\'t find program/i &&
         $err->[1] =~ /spawn: warning: program.*not registered/ &&
         $err->[2] =~ /spawn: warning: couldn\'t find program/ &&
         $err->[3] =~ /crashed while running/);
}

if (1)
{
   announce "register_programs: specific program override";
   ($status,$out,$err) = fork_test 
      (sub
       {
          $ok = $spawner->register_programs ({ls => './toy_ls'});
          die "unexpected result of register_programs" unless $ok;
          return $spawner->spawn ("ls $files[0]");
       }, 0);

   test ($status == 0 &&
         (shift @$out) eq "** BEGIN TEST" &&
         (pop @$out) eq "** END TEST" &&
         @$out == 2 &&
         $out->[0] =~ m|\] ./toy_ls $files[0]$| &&
         $out->[1] eq $files[0] &&
         @$err == 0);         
}

if (1)
{
   announce "register_programs: bogus override";
   ($status,$out,$err) = fork_test 
      (sub
       {
          $ok = $spawner->register_programs ({ls => 'blargsnob'});
          die "unexpected result of register_programs" if $ok;
          return $spawner->spawn ("ls $files[0]");
       }, 1);

   test ($status != 0 &&
         (shift @$out) eq "** BEGIN TEST" &&
         @$out == 0 &&
         @$err == 4 &&
         $err->[0] =~ /doesn\'t exist or not executable/i &&
         $err->[1] =~ /spawn: warning: program \"ls\" not registered/ &&
         $err->[2] =~ /spawn: warning: couldn\'t find program/ &&
         $err->[3] =~ /crashed while running/);
}
