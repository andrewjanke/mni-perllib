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

sub copy
{
   my ($src, $dest) = @_;

   local $/;
   undef $/;
   open (IN, $src) || die "couldn't open $src: $!\n";
   $data = <IN>;
   close (IN);
   open (OUT, ">$dest") || die "couldn't open $dest: $!\n";
   print OUT $data;
   close (OUT);
}


# Check assumptions about current dir
die "Must be run from distribution directory\n" unless -d 't';
die "Error in distribution -- t not writeable\n" unless -w 't';
die "Error in distribution -- t/foo/bar already exists\n"
   if -d 't/foo/bar';

# Check assumptions about system dirs
die "Error in system configuration -- / not read-only dir\n"
   unless ($< == 0) || (-d '/' && (! -w '/'));
die "Error in system configuration -- /dev/null not found\n"
   unless -e '/dev/null';
die "Error in system configuration -- /tmp not writeable dir\n"
   unless -d '/tmp' && -w '/tmp';
die "Error in system configuration -- /foo already exists\n"
   if -d '/foo';

# Warnings
warn "warning: running test suite as root means not all tests will be run\n"
   if $< == 0;

# Setup a couple of files and directories in which to perform our tests; 
# resulting tree looks like this:
# 
# $ ls -lRF
# total 22
# -rw-r--r--   1 greg     pet         11003 May  5 13:54 FileUtilities.pm.gz
# -rw-r--r--   1 greg     pet          9813 May  5 13:54 MiscUtilities.pm
# drwxr-xr-x   2 greg     pet           512 May  5 13:54 t/
# 
# t:
# total 9
# -rwxr-xr-x   1 greg     pet          3456 May  5 14:00 checkdirs.t*
# -rwxr-xr-x   1 greg     pet          1342 May  5 14:00 checkfiles.t*
# -rwxr-xr-x   1 greg     pet          2376 May  5 14:00 miscutil.t*

chop ($cwd = `pwd`);
map { $_ = "$cwd/$_" unless m|^/|; } @INC;

$base = "/tmp/fileutil.t_$$";
mkdir ($base, 0755) || die "couldn't mkdir $base: $!\n";
mkdir ("$base/t", 0755) || die "couldn't mkdir $base/t: $!\n";
@modules = qw(FileUtilities.pm MiscUtilities.pm);
@tests = qw(t/checkdirs.t t/checkfiles.t t/miscutil.t);

map { copy ("MNI/$_", "$base/$_") } @modules;
map { copy ("$_", "$base/$_") } @tests;

chdir ($base) || die "couldn't chdir to $base: $!\n";
system 'gzip', 'FileUtilities.pm'; die "gzip failed" if $?;
chmod (0755, @tests) || die "couldn't chmod @tests: $!\n";

# Add an exit handler to cleanup this mess, and a warn handler to
# catch errors from the `check' subroutines
END { chdir '/'; system "/bin/rm -rf $base" if defined $base; }
$SIG{'__WARN__'} = \&catch_warn;

1;
