=item uncompress (TMPDIR, FILES)

Uncompresses a list of files to a specified temporary directory (i.e., the
original files are left untouched, and uncompressed copies are made).  The
list of files is specified just as a list, so don't be passing in array
references or any of that stuff.

Note that the files in FILES don't have to be compressed; if they don't
have a .Z, .gz, or .z extension, they are left untouched and in their
original directory.  C<uncompress> returns a list of filenames with
formerly compressed filenames replaced by the names of their new,
uncompressed copies and uncompressed filenames left alone.

All uncompressing is done with C<gunzip>, and it must be on your PATH
environment variable.  

An example: say you have some filenames, set up as follows:

   $f1 = 'foo';
   $f2 = 'bar/zap.gz';
   $f3 = 'bong.gz';

You could then ensure that they are all available in uncompressed form
as follows:

   ($f1, $f2, $f3) = uncompress ('/tmp', $f1, $f2, $f3);

This has the effect of executing the following shell commands:

   gunzip -c bar/zap.gz > /tmp/zap
   gunzip -c bong.gz > /tmp/bong

and returns the list C<('foo','/tmp/zap','/tmp/bong')>.

Dies if C<gunzip> fails for any reason; no other errors are checked for.   

=cut

# ------------------------------ MNI Header ----------------------------------
#@NAME       : &uncompress
#@INPUT      : $tmp_dir - directory to uncompress files to
#              @originals - list of files to consider for uncompression
#@OUTPUT     : 
#@RETURNS    : array context: @originals, changed so that the names
#                of any files that were compressed are now decompressed
#                and in $tmp_dir
#              scalar context: first element of @originals, possibly changed
#                to decompressed version
#@DESCRIPTION: Uncompresses (if applicable) compressed files to $tmp_dir.
#@METHOD     : 
#@GLOBALS    : 
#@CALLS      : 
#@CREATED    : 1995/07/31, Greg Ward
#@MODIFIED   : 
#-----------------------------------------------------------------------------
sub uncompress
{
   my ($tmp_dir, @originals) = @_;
   my ($uncompressed, @uncompressed, $orig);

   foreach $orig (@originals)
   {
      if (($uncompressed = $orig) =~ s/\.(Z|gz|z)$//)
      {
#	 ($uncompressed = replace_dir ($tmp_dir, $orig)) =~ s/\.(Z|gz|z)$//;
         $uncompressed = s|.*/([^/]*)|${tmp_dir}$1|;
         unless (-e $uncompressed)
         {
            system ("gunzip -c $orig > $uncompressed");
            die "gunzip $orig failed\n" if ($?);
         }
         $orig = $uncompressed;
#	 push (@uncompressed, $uncompressed);
      }
#      else
#      {
#         push (@uncompressed, $orig);
#      }
   }
   return wantarray ? @originals : $originals[0];
}


=item compress (FILES)

=cut

# ------------------------------ MNI Header ----------------------------------
#@NAME       : &compress
#@INPUT      : $files - ref to list of files to compress
#@OUTPUT     : 
#@RETURNS    : 
#@DESCRIPTION: Compresses (with gzip) each of a list of files.
#@METHOD     : 
#@GLOBALS    : 
#@CALLS      : 
#@CREATED    : 1997/01/15, GPW
#@MODIFIED   : 
#-----------------------------------------------------------------------------
sub compress
{
   my ($files) = @_;
   my $file;

   foreach $file (@$files)
   {
      unless ($file =~ /\.(Z|gz|z)$/)
      {
         system "gzip", $file;
         die "gzip $file failed\n" if ($?);
      }
   }
}


