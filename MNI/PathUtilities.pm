# ------------------------------ MNI Header ----------------------------------
#@NAME       : MNI::PathUtilities
#@DESCRIPTION: Subroutines for recognizing, parsing, and tweaking POSIX
#              filenames and paths:
#                 split_path
#                 replace_dir
#                 replace_ext
#@EXPORT     : 
#@EXPORT_OK  : normalize_dirs
#              split_path
#              replace_dir
#              replace_ext
#              merge_paths
#@EXPORT_TAGS: all
#@USES       : 
#@REQUIRES   : Exporter
#@CREATED    : 1997/05/13, Greg Ward (from path_utilities.pl, revision 1.10)
#@MODIFIED   : 
#@VERSION    : $Id: PathUtilities.pm,v 1.2 1997-05-29 22:30:41 greg Exp $
#@COPYRIGHT  : Copyright (c) 1997 by Gregory P. Ward, McConnell Brain Imaging
#              Centre, Montreal Neurological Institute, McGill University.
#
#              This file is part of the MNI Perl Library.  It is free 
#              software, and may be distributed under the same terms
#              as Perl itself.
#-----------------------------------------------------------------------------

package MNI::PathUtilities;

use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

# I require 5.004 because this module interacts with Perl 5.002 in 
# a weird way -- it compiles and runs the module successfully, and
# then just quits.  I have no explanation for this; but it works
# fine under 5.004.  Go figure.

require 5.004;
require Exporter;

@ISA = qw(Exporter);
@EXPORT = ();
@EXPORT_OK = qw(normalize_dirs
                split_path
                replace_dir 
                replace_ext
                merge_paths);
%EXPORT_TAGS = (all => [@EXPORT_OK]);


=head1 NAME

MNI::PathUtilities - recognize, parse, and tweak POSIX file and path names

=head1 SYNOPSIS

   use MNI::PathUtilities qw(:all);

   normalize_dirs ($dir1, $dir2, ...);

   ($dir, $base, $ext) = split_path ($path);

   ($dir, $base, $last_ext) = split_path ($path, 'last');

   ($dir, $base) = split_path ($path, 'none');

   @files = replace_dir ($newdir, @files);

   $file = replace_dir ($newdir, $file);

   @files = replace_ext ($newext, @files);

   $file = replace_ext ($newext, $file);

   @dirs = merge_paths (@dirs);

=head1 DESCRIPTION

C<MNI::PathUtilities> provides a collection of subroutines for doing
common string transformations and matches on Unix/POSIX filenames.  I
use "filenames" here in the generic sense of either a directory name, a
bare filename, or a complete path to a file.  It should be clear from
context what meaning you (or the code) should attach to a given string;
if it's not, that's a documentation bug, so please holler at me.

Throughout this module, directories are usually treated as something to
be directly concatenated onto a bare filename, i.e. they either end with
a slash or are empty.  (The exception is C<merge_paths>, which returns a
list of directories ready to be C<join>'d and stuffed into something
like C<$ENV{'PATH'}> -- for this, you want '.' for the current
directory, and no trailing slashes.)  You generally don't have to worry
about doing this for the benefit of the C<MNI::PathUtilities>
subroutines; they use C<normalize_dirs> to take care of it for you.
However, you might want to use C<normalize_dirs> in your own code to
spare yourself the trouble of converting empty strings to '.' and
sticking in slashes.

Error handling is not a worry in this module; the criterion for a
subroutine going in C<MNI::PathUtilities> (as opposed to
C<MNI::FileUtilities>) is that it not interact with the filesystem in any
way, so the only possible source of errors is if you pass in strings that
are wildly different from what is expected of Unix/POSIX filenames.  Since
Unix filenames can be pretty much anything until you actually plant them in
a real filesystem, this is not detected.

=head1 EXPORTS

By default, C<MNI::PathUtilities> exports no symbols.  You can import in
the usual one-name-at-a-time way like this:

   use MNI::PathUtilities qw(normalize_dirs split_path);

or you can import everything using the C<all> export tag:

   use MNI::PathUtilities qw(:all);

=head1 SUBROUTINES

=over 4

=item normalize_dirs (DIR, ...)

Each DIR (a simple list of strings -- no references here) is modified
in-place so that it can be concatenated directly to a filename to form a
complete path.  This just means that we append a slash to each string,
unless it already has a trailing slash or is empty.

For example, the following table shows how C<normalize_dirs> will modify
the contents of a passed-in variable:

   if input value is...           it will become...
   '.'                            './'
   ''                             ''
   '/foo/bar'                     '/foo/bar/'
   '/foo/bar/'                    '/foo/bar/'

If you try to pass a constant string to C<normalize_dirs>, Perl will die
with a "Modification of a read-only value attempted" error message.  So
don't do that.

=cut

# ------------------------------ MNI Header ----------------------------------
#@NAME       : normalize_dirs
#@INPUT      : list of directories 
#@OUTPUT     : (arguments modified in place)
#@RETURNS    : 
#@DESCRIPTION: Modifies a list of directory names in place so that they
#              all either end in a slash, or are empty.
#@METHOD     : 
#@GLOBALS    : 
#@CALLS      : 
#@CREATED    : 1997/05/26, GPW
#@MODIFIED   : 
#-----------------------------------------------------------------------------
sub normalize_dirs
{
   # add trailing slash, etc.  -- should replace ensure_trailing_slash
   # (better name, more general)

   foreach (@_)
   {
      $_ .= '/' unless $_ eq '' || substr ($_, -1, 1) eq '/';
   }
}


=item split_path (PATH [, EXT_OPT])

Splits a Unix/POSIX path into directory, base filename, and extension.
(The extension is chosen based on either the first or last dot in the
filename, depending on C<EXT_OPT>; by default, it splits on the first dot
in the filename.)

C<split_path> is normally called like this:

   ($dir,$base,$ext) = split_path ($path);

If there is no directory (i.e. C<$path> refers to a file in the current
directory), then C<$dir> will be the empty string.  Otherwise, C<$dir> will
be the head of C<$path> up to and including the last slash.  Usually, you
can count on C<split_path> to do the Right Thing; you should only have to
read the next couple of paragraphs if you're curious about the exact rules
it uses.

If EXT_OPT is supplied, it must be one of C<'first'>, C<'last'>, or
C<'none'>.  By default, it is C<'first'>, meaning that C<$ext> will be the
tail end of C<$path>, starting at the first period after the last slash.
If EXT_OPT is C<'last'>, then C<$ext> will start at the I<last> period
after the last slash.  If EXT_OPT is C<'none'>, then C<$ext> will be
undefined and any extensions in C<$path> will be rolled into C<$base>.
Finally, if there are no extensions at all in C<$path>, then C<$ext> will
be undefined whatever the value of EXT_OPT.

C<$base> is just whatever portion of C<$path> is left after pulling off
C<$dir> and C<$ext> -- i.e., from the last slash to the first period (if
C<EXT_OPT> is C<'first'>), or from the last slash to the last period (if
C<EXT_OPT> is C<'last'>).

For example, 

   split_path ($path)

will split the C<$path>s in the right-hand column into the lists shown on
the left:

   'foo.c'                      ('', 'foo', '.c')
   '/unix'                      ('/', 'unix', undef)
   '/bin/ls'                    ('/bin/', 'ls', undef)
   '/foo/bar/zap.mnc'           ('/foo/bar/', 'zap', '.mnc')
   '/foo/bar/zap.mnc.gz'        ('/foo/bar/', 'zap', '.mnc.gz')

However, if you called it with an EXT_OPT of C<'last'>:

   split_path ($path, 'last')

then the last example would be split differently, like this:

   '/foo/bar/zap.mnc.gz'        ('/foo/bar/', 'zap.mnc', '.gz')

And with EXT_OPT equal to C<'none'>, all of the filenames with extensions
would be split like this:

   'foo.c'                      ('', 'foo.c', undef)
   '/foo/bar/zap.mnc'           ('/foo/bar/', 'zap.mnc', undef)
   '/foo/bar/zap.mnc.gz'        ('/foo/bar/', 'zap.mnc.gz', undef)

Note that a "missing directory" becomes the empty string, whereas a
"missing extension" becomes C<undef>.  This is not a bug; my rationale is
that every path has a directory component that may be empty, but a missing
extension means there really is no extension.

See L<File::Basename> for an alternate solution to this problem.
C<File::Basename> is not specific to Unix paths, usually results in
nicer looking code (you don't have to do things like
C<(split_path($path))[1]> to get the basename), and is part of the
standard Perl library; however, it doesn't deal with file extensions in
quite so flexible and generic a way as C<split_path>.

=cut

# ------------------------------ MNI Header ----------------------------------
#@NAME       : &split_path
#@INPUT      : $path    - a Unix path specifiction (optional directory + file)
#              $ext_opt - specifies how to deal with file extensions:
#                         if "none", extension is ignored and returned as
#                           part of the base filename
#                         if "first", the *first* dot in a filename denotes
#                           the extension, eg ".mnc.gz" would be an extension
#                         if "last", the *last* dot denotes the extension,
#                           eg. just ".gz" would be the extension
#                         the default is "first"
#@OUTPUT     : 
#@RETURNS    : array: ($dir, $base, $ext)
#@DESCRIPTION: Splits a Unix path specification into directory, base file 
#              name, and extension.  (The extension is chosen based on
#              either the first or last dot in the filename, depending
#              on the $ext_opt argument; by default, it splits on the 
#              first dot in the filename.)
#@METHOD     : 
#@GLOBALS    : 
#@CALLS      : 
#@CREATED    : 1995/05/10, Greg Ward - taken from mritotal and modified
#@MODIFIED   : 1995/08/10, GW: added $ext_opt option to handle splitting off
#                              the extension in different ways
#              1997/02/26, GW: changed to preserve trailing slash and 
#                              empty directory string
#              1997/05/29, GW: added fallback so 'last' option works on a 
#                              path with no extension
#-----------------------------------------------------------------------------
sub split_path
{
   my ($path, $ext_opt) = @_;
   my ($dir, $base, $ext);
   
   $ext_opt = "first" unless defined $ext_opt;
   
   # If filename has no extension, don't try to act as though it does
   # (both "last" and "first" options assume there is an extension
   
   #    $ext_opt = "none" if $path !~ m+/?[^/]*\.+;
   
   if ($ext_opt eq "none")
   {
      ($dir, $base) = $path =~ m+^(.*/)?([^/]*)$+;
   } 
   elsif ($ext_opt eq "first")
   {
      ($dir, $base, $ext) = $path =~ m+^(.*/)?([^/\.]*)(\..*)?$+;
   }
   elsif ($ext_opt eq "last")
   {
      ($dir, $base, $ext) = $path =~ m+^(.*/)?([^/]*)(\.[^/.]*)$+
         or ($dir, $base) = $path =~ m+^(.*/)?([^/]*)$+
         }
   else
   {
      die "split_path: unknown extension option \"$ext_opt\"\n";
   }
   
   $dir = "" unless ($dir);
   
   ($dir, $base, $ext);
}


=item replace_dir (NEWDIR, FILE, ...)

Replaces the directory component of each FILE with NEWDIR.  You can supply
as many FILE arguments as you like; they are I<not> modified in place.
NEWDIR is first "normalized" so that it ends in a trailing slash (unless it
is empty), so you don't have to worry about doing this yourself.
(C<replace_dir> does not modify its NEWDIR parameter, though, so you might
want to normalize it yourself if you're going to use it for other
purposes.)

Returns the list of modified filenames; or, in a scalar context, returns
the first element of that list.  (That way you can say either 
C<@f = replace_dir ($dir, @f)> or C<$f = replace_dir ($dir, $f)> without
worrying too much about context.)

For example,

   @f = replace_dir ('/tmp', '/foo/bar/baz', 'blam', '../bong')

sets C<@f> to C<('/tmp/baz', '/tmp/blam', '/tmp/bong')>, and 

   $f = replace_dir ('/tmp', '/foo/bar/baz')

sets C<$f> to C<'/tmp/baz'>.

=cut

# ------------------------------ MNI Header ----------------------------------
#@NAME       : replace_dir
#@INPUT      : $newpath - directory to replace existing directories with
#              @files   - list of files to have directories replaced
#@OUTPUT     : 
#@RETURNS    : 
#@DESCRIPTION: Replaces the directory component of a list of pathnames.
#              Returns the list of files with substitutions performed.
#@METHOD     : 
#@GLOBALS    : 
#@CALLS      : 
#@CREATED    : 1995/05/04, Greg Ward
#@MODIFIED   : 1995/05/23, GW: renamed to &ReplaceDir
#-----------------------------------------------------------------------------
sub replace_dir
{
   my ($newpath, @files) = @_;

   normalize_dirs ($newpath);
   foreach (@files)
   {
      # Try to substitute an existing directory (ie. eat greedily up to
      # a slash) with the new directory.  If that fails, then there's no
      # slash in the filename, so just jam the new directory on the front.

      s|.*/|$newpath| 
         or $_ = $newpath . $_;
   }
   wantarray ? @files : $files[0];
}


=item replace_ext (NEWEXT, FILE, ...)

Replaces the final extension (whatever follows the last dot) of each FILE
with NEWEXT.  You can supply as many FILE arguments as you like; they are
I<not> modified in place.

Returns the list of modified filenames; or, in a scalar context, returns
the first element of that list.  (That way you can say either 
C<@f = replace_ext ($ext, @f)> or C<$f = replace_dir ($ext, $f)> without
worrying too much about context.

For example,

   replace_ext ('xfm', 'blow_joe_mri.mnc')

in a scalar context returns C<'blow_joe_mri.xfm'>; in an array context, it
would just return the one-element list C<('blow_joe_mri.xfm')>.

=cut

# ------------------------------ MNI Header ----------------------------------
#@NAME       : replace_ext
#@INPUT      : $newext  - extension to replace existing extensions with
#              @files   - list of files to have extensions replaced
#@OUTPUT     : 
#@RETURNS    : 
#@DESCRIPTION: Replaces the final extension (whatever follows the final dot)
#              of a list of pathnames.  Returns the list of files with
#              substitutions performed in array context, or the first filename
#              from the list in a scalar context.
#@METHOD     : 
#@GLOBALS    : 
#@CALLS      : 
#@CREATED    : 1995/05/23, Greg Ward (from &ReplaceDir)
#@MODIFIED   : 
#-----------------------------------------------------------------------------
sub replace_ext
{
   my ($newext, @files) = @_;

   foreach (@files)
   {
      s/\.[^\.]*$/\.$newext/;           # replace existing extension
   }
   wantarray ? @files : $files[0];
}


=item merge_paths (DIRS)

Goes through a list of directories, culling duplicates and converting
them to a form more amenable to stuffing in PATH variables and the like.
Basically, this means undoing the work of C<normalize_path>: trailing
slashes are stripped, and empty strings are replaced by '.'.

Returns the input list with duplicates removed (after those minor string
transformations).

=cut

# ------------------------------ MNI Header ----------------------------------
#@NAME       : &merge_paths
#@INPUT      : a list of directories (well, they could almost be any strings,
#              except we tweak 'em a bit with the assumption that they are
#              directories for a PATH-like list)
#@OUTPUT     : 
#@RETURNS    : the input list, but with duplicates removed, trailing slashes
#              stripped, and empty strings converted to '.'
#@DESCRIPTION: 
#@METHOD     : 
#@GLOBALS    : 
#@CALLS      : 
#@CREATED    : 1995/12/04 GPW
#@MODIFIED   : 
#-----------------------------------------------------------------------------
sub merge_paths
{
   my (@dirs) = @_;
   my (%seen, $dir, @path);

   foreach $dir (@dirs)
   {
      $dir =~ s|/$|| unless $dir eq '/'; # strip trailing slash
      $dir = '.' unless $dir;           # ensure no empty strings
      push (@path, $dir) unless $seen{$dir};
      $seen{$dir} = 1;
   }
   @path;
}

=back

=head1 AUTHOR

Greg Ward, <greg@bic.mni.mcgill.ca>.

=head1 COPYRIGHT

Copyright (c) 1997 by Gregory P. Ward, McConnell Brain Imaging Centre,
Montreal Neurological Institute, McGill University.

This file is part of the MNI Perl Library.  It is free software, and may be
distributed under the same terms as Perl itself.

=cut

1;
