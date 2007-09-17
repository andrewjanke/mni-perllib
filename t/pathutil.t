#! /usr/bin/env perl

use warnings "all";

use MNI::PathUtilities qw(normalize_dirs 
                          split_path 
                          replace_dir
                          replace_ext
                          merge_paths
                          expand_path);

my $i = 0;
sub test { printf "%s %d\n", ($_[0] ? "ok" : "not ok"), ++$i; }

print "1..66\n";

my $warning;
my $num_warnings = 0;

sub catch_warn 
{
#  print STDERR "warning: $_[0]";
   $warning = $_[0];
   $num_warnings++;
}

sub warning
{
   my $w = $warning;
   undef $warning;
   $w;
}

# test normalize_dirs:
%normalized = 
   ('.',                            './',
    '',                             '',
    '/foo/bar',                     '/foo/bar/',
    '/foo/bar/',                    '/foo/bar/');

foreach $d (keys %normalized)
{
   $n = $normalized{$d};
   normalize_dirs ($d);
   test ($d eq $n);
}


# test split_path; first with no ext_opt

%split = 
   ('foo.c'                => ['', 'foo', '.c'],
    '/unix'                => ['/', 'unix', undef],
    '/bin/ls'              => ['/bin/', 'ls', undef],
    '/foo/bar/zap.mnc'     => ['/foo/bar/', 'zap', '.mnc'],
    '/foo/bar/zap.mnc.gz'  => ['/foo/bar/', 'zap', '.mnc.gz'],
    '/junk/foo.bar.mnc.gz' => ['/junk/', 'foo', '.bar.mnc.gz']);

foreach $p (keys %split)
{
   @s = split_path ($p);
   @ok = map { (!defined $s[$_] && !defined $split{$p}[$_]) ||
               ($s[$_] eq $split{$p}[$_]) } (0 .. $#s);
   test (@s == 3 && @ok == 3 && $ok[0] && $ok[1] && $ok[2]);
}

# now with 'none' ext_opt

%split = 
   ('foo.c'                => ['', 'foo.c', undef],
    '/unix'                => ['/', 'unix', undef],
    '/bin/ls'              => ['/bin/', 'ls', undef],
    '/foo/bar/zap.mnc'     => ['/foo/bar/', 'zap.mnc', undef],
    '/foo/bar/zap.mnc.gz'  => ['/foo/bar/', 'zap.mnc.gz', undef],
    '/junk/foo.bar.mnc.gz' => ['/junk/', 'foo.bar.mnc.gz', undef]);

foreach $p (keys %split)
{
   @s = split_path ($p, 'none');
   @ok = map { (!defined $s[$_] && !defined $split{$p}[$_]) ||
               ($s[$_] eq $split{$p}[$_]) } (0 .. $#s);
   test (@s == 3 && @ok == 3 && $ok[0] && $ok[1] && $ok[2]);
}

# now with 'last' ext_opt

%split = 
   ('foo.c'                => ['', 'foo', '.c'],
    '/unix'                => ['/', 'unix', undef],
    '/bin/ls'              => ['/bin/', 'ls', undef],
    '/foo/bar/zap.mnc'     => ['/foo/bar/', 'zap', '.mnc'],
    '/foo/bar/zap.mnc.gz'  => ['/foo/bar/', 'zap.mnc', '.gz'],
    '/junk/foo.bar.mnc.gz' => ['/junk/', 'foo.bar.mnc', '.gz']);

foreach $p (keys %split)
{
   @s = split_path ($p, 'last');
   @ok = map { (!defined $s[$_] && !defined $split{$p}[$_]) ||
               ($s[$_] eq $split{$p}[$_]) } (0 .. $#s);
   test (@s == 3 && @ok == 3 && $ok[0] && $ok[1] && $ok[2]);
}

# and with 'last' ext_opt with a list of 'skip extensions'

%split = 
   ('foo.c'                => ['', 'foo', '.c'],
    '/unix'                => ['/', 'unix', undef],
    '/bin/ls'              => ['/bin/', 'ls', undef],
    '/foo/bar/zap.mnc'     => ['/foo/bar/', 'zap', '.mnc'],
    '/foo/bar/zap.mnc.gz'  => ['/foo/bar/', 'zap', '.mnc.gz'],
    '/junk/foo.bar.mnc.gz' => ['/junk/', 'foo.bar', '.mnc.gz'],
    'barf.pgp.gz'          => ['', 'barf', '.pgp.gz'],
    'barf.gz.pgp'          => ['', 'barf', '.gz.pgp']);

foreach $p (keys %split)
{
   @s = split_path ($p, 'last', [qw(gz z Z pgp)]);
   @ok = map { (!defined $s[$_] && !defined $split{$p}[$_]) ||
               ($s[$_] eq $split{$p}[$_]) } (0 .. $#s);
   test (@s == 3 && @ok == 3 && $ok[0] && $ok[1] && $ok[2]);

   @s = split_path ($p, 'last', [qw(pgp gz)]);
   @ok = map { (!defined $s[$_] && !defined $split{$p}[$_]) ||
               ($s[$_] eq $split{$p}[$_]) } (0 .. $#s);
   test (@s == 3 && @ok == 3 && $ok[0] && $ok[1] && $ok[2]);
}


# test replace_dir:
@f = replace_dir ('/tmp', '/foo/bar/baz', 'blam', '../bong');
test (@f == 3 && 
      $f[0] eq '/tmp/baz' && $f[1] eq '/tmp/blam' && $f[2] eq '/tmp/bong');
$f = replace_dir ('/tmp', './bong');
test ($f eq '/tmp/bong');
$f = '/foo/bar';
test (replace_dir ('/tmp', $f) eq '/tmp/bar');
@f = ('/foo/bar/baz', 'blam', '../bong');
$f = replace_dir ('/tmp', @f);
test ($f eq '/tmp/baz');


# test replace_ext:
test (replace_ext ('xfm', 'blow_joe_mri.mnc') eq 'blow_joe_mri.xfm');
$f = replace_ext ('xfm', 'blow_joe_mri.mnc');
test ($f eq 'blow_joe_mri.xfm');
@f = replace_ext ('xfm', 'blow_joe_mri.mnc');
test ($f[0] eq 'blow_joe_mri.xfm');

$f1 = '/ding/dong/blow_joe_mri.mnc';
$f2 = '/zip/zap/foo.bar.blah';
($f1, $f2) = replace_ext ('qux', $f1, $f2);
test ($f1 eq '/ding/dong/blow_joe_mri.qux' &&
      $f2 eq '/zip/zap/foo.bar.qux');
$f = replace_ext ('qux', $f1, $f2);
test ($f eq '/ding/dong/blow_joe_mri.qux');


# test merge_paths:
@p = merge_paths ('/usr/bin', '/bin', '/usr/local/bin', '/bin/', '', '/');
test (@p == 5 &&
      $p[0] eq '/usr/bin' &&
      $p[1] eq '/bin' &&
      $p[2] eq '/usr/local/bin' &&
      $p[3] eq '.' &&
      $p[4] eq '/');

# test expand_path

$home = $ENV{'HOME'};
$ENV{'foo'} = 'foo/bar';
$ENV{'qux'} = 'biff';
test (expand_path ('~') eq $home);
test (expand_path ('~/foo/bar') eq "$home/foo/bar");
test (expand_path ('/~') eq '/~');
test (expand_path ('$foo') eq 'foo/bar');
test (expand_path ('/zip/$foo/') eq '/zip/foo/bar/');
test (expand_path ('/$foo/bang$qux') eq '/foo/bar/bangbiff');
test (expand_path ('~/foo/$qux') eq "$home/foo/biff");

while (@pwent = getpwent)
{
   $users{$pwent[0]} = 1;
   @prev = @pwent;
}
setpwent;                               # rewind passwd file
($name,$dir) = @prev[0,7];
test (expand_path ("~$name") eq $dir);
test (expand_path ("~$name/foo/bar") eq "$dir/foo/bar");
test (expand_path ("/~$name") eq "/~$name");
test (expand_path ("~$name/foo/\$qux") eq "$dir/foo/biff");

$SIG{'__WARN__'} = \&catch_warn;
$name = 'x';
$name .= 'x' while exists $users{$name};
$var = 'x';
$var .= 'x' while exists $ENV{$var};
test (!expand_path ("~$name") && warning =~ /unknown username/);
test (!expand_path ("~$name/") && warning =~ /unknown username/);
test (!expand_path ("~$name/$var") && warning =~ /unknown username/);
test (expand_path ("/~$name") eq "/~$name");
test (!expand_path ("\$$var") && warning =~ /unknown environment variable/);
test (!expand_path ("/foo/\$$var") && warning =~ /unknown environment variable/);
test (!expand_path ("\$foo/\$$var") && warning =~ /unknown environment variable/);
delete $SIG{'__WARN__'};
