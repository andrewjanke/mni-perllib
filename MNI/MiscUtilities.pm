# ------------------------------ MNI Header ----------------------------------
#@NAME       : MNI::MiscUtilities
#@DESCRIPTION: Miscellaneous and unclassifiable (but otherwise useful!)
#              utility routines
#@EXPORT     : timestamp 
#              userstamp 
#              lcompare
#              nlist_equal
#              make_banner
#              shellquote
#@EXPORT_OK  : 
#@EXPORT_TAGS:
#@USES       : POSIX, Sys::Hostname, Cwd
#@REQUIRES   : Exporter
#@CREATED    : 1997/04/24, Greg Ward (from misc_utilities.pl)
#@MODIFIED   : 
#@VERSION    : $Id: MiscUtilities.pm,v 1.1 1997-04-25 19:10:13 greg Exp $
#@COPYRIGHT  : Copyright (c) 1997 by Gregory P. Ward, McConnell Brain Imaging
#              Centre, Montreal Neurological Institute, McGill University.
#
#              This file is part of the MNI Perl Library.  It is free 
#              software, and may be distributed under the same terms
#              as Perl itself.
#-----------------------------------------------------------------------------

package MNI::MiscUtilities;

use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

require 5.002;
require Exporter;

use POSIX qw(strftime);
use Sys::Hostname;
use Cwd;

@ISA = qw(Exporter);
@EXPORT = qw(timestamp userstamp lcompare nlist_equal make_banner shellquote);

#
# IDEA: should timestamp and userstamp be moved to a new module, say
# MNI::Footprint (should only be needed by Spawn, Backgroundify, and 
# MINC history stuff)
#

# ------------------------------ MNI Header ----------------------------------
#@NAME       : timestamp
#@INPUT      : $tm - [optional] time to use, as seconds since 
#                    1970-01-01 00:00:00 UTC (eg from `time'); 
#                    defaults to the current time
#@OUTPUT     : 
#@RETURNS    : 
#@DESCRIPTION: Generates and returns a timestamp of the form 
#              "1995-05-16 22:30:14".
#@METHOD     : 
#@GLOBALS    : 
#@CALLS      : 
#@CREATED    : 1995/05/16, GW (from &doit)
#@MODIFIED   : 1996/05/22, GW: added seconds to time
#              1996/06/17, GW: changed to use strftime from POSIX
#              1997/04/24, GW: copied from misc_utilities.pl, removed brackets
#-----------------------------------------------------------------------------
sub timestamp (;$)
{
   my ($tm) = @_;

   $tm = time unless defined $tm;
   strftime ('%Y-%m-%d %H:%M:%S', localtime ($tm));
}


# ------------------------------ MNI Header ----------------------------------
#@NAME       : userstamp
#@INPUT      : $user - [optional] username; defaults to looking up 
#                      login name of $< (real uid) in password file
#              $host - [optional]; defaults to hostname from Sys::Hostname
#              $dir  - [optional]; defaults to current directory, from 
#                      Cwd::getcwd
#@OUTPUT     : 
#@RETURNS    : 
#@DESCRIPTION: Generates and returns a "userstamp" of the form 
#              "greg@bottom:/data/scratch1/greg".
#@METHOD     : 
#@GLOBALS    : 
#@CALLS      : 
#@CREATED    : 1995/05/16, GW
#@MODIFIED   : 1996/05/29, GW: added directory
#              1997/04/24, GW: copied from misc_utilities.pl, removed brackets
#-----------------------------------------------------------------------------
sub userstamp (;$$$)
{
   my ($user, $host, $dir) = @_;

   $user = getpwuid ($<) unless defined $user;
   $host = hostname() unless defined $host;
   $dir = getcwd unless defined $dir;
   sprintf ("%s@%s:%s", $user, $host, $dir);
}




# Had an interesting time trying to make my `lcompare' act like
# builtin `sort', eg. so you could do any of these:
#
#    lcompare { $_[0] <=> $_[1] } @a, @b
#    $ncomp = sub { $_[0] <=> $_[1] }
#    lcompare (sub { $_[0] <=> $_[1] }, @a, @b)
#    lcompare ($ncomp, @a, @b)
#
# but it turns out that prototypes just plain aren't that flexible
# -- at least, I couldn't figure out.  Perhaps there's a reason
# that table of prototypes you could use to replace builtins doesn't
# include mysort!
#
# So I'm doing it the obvious, non-prototyped way -- caller must
# pass in explicit references (one code ref, to array refs).


# Here's some things I found out while playing around with the
# prototype version of lcompare:
#
# CODE                                     compiles ok?  result ok?
# compare (sub { $_[0] == $_[1] }, @a, @b)      yes         yes
# compare { $_[0] == $_[1] }, @a, @b            yes          no
# compare { $_[0] == $_[1] } @a, @b             yes         yes
# compare ({ $_[0] == $_[1] } @a, @b)            no
# compare ({ $_[0] == $_[1] }, @a, @b)           no

# ------------------------------ MNI Header ----------------------------------
#@NAME       : lcompare
#@INPUT      : $cmp   - [code ref] comparison function, takes 2 args
#                       and returns -1, 0, or 1, depending on whether first
#                       is less than, equal to, or greater than second
#              $alist - [array ref] first array
#              $blist - [array ref] second array
#@OUTPUT     : 
#@RETURNS    : 0 if the two arrays are equal
#              -1 if @$alist is smaller than @$blist
#              1 if @$alist is greater than @$blist
#@DESCRIPTION: Compares two arrays, element by element, and returns
#              an integer telling which is `larger'.
#@CREATED    : 1997/04/24, Greg Ward
#-----------------------------------------------------------------------------
sub lcompare # (&\@\@)
{
   my ($cmp, $alist, $blist) = @_;
   my ($i, $result);

   # goal: lcompare { $a cmp $b } [split ("", $s1)], [split ("", $s2)]
   # should be same as $s1 cmp $s2

   $result = 0;
   for $i (0 .. $#$alist)
   {
      my ($a, $b) = ($alist->[$i], $blist->[$i]);
      return 1 if !defined $b;         # a longer
      $result = &$cmp ($a, $b);
      return $result if $result != 0;
   }

   return -1 if $#$blist > $#$alist;	# equal up to end of a, but b longer
   return 0;                            # they're equal
}


# ------------------------------ MNI Header ----------------------------------
#@NAME       : nlist_equal
#@INPUT      : $alist, $blist - [array refs] the two lists to compare
#@OUTPUT     : 
#@RETURNS    : true if the two lists are numerically identical, false otherwise
#@DESCRIPTION: Compares two lists numerically.  
#@CALLS      : lcompare
#@CREATED    : 1997/04/25, GPW
#@MODIFIED   : 
#-----------------------------------------------------------------------------
sub nlist_equal
{
   my ($alist, $blist) = @_;

   (lcompare (sub { $_[0] <=> $_[1] }, $alist, $blist)) == 0;
}


# ------------------------------ MNI Header ----------------------------------
#@NAME       : make_banner
#@INPUT      : $msg    - the string to print
#              $char   - the character to use when making the "banner"
#                        (optional; defaults to "-")
#              $width  - the width of field to pad to (optional; defaults
#                        to 80, but should default to width of terminal)
#@OUTPUT     : 
#@RETURNS    : 
#@DESCRIPTION: Creates and returns a string of the form 
#              "-- Hello! ----------" (assuming $msg="Hello!", $char="-", 
#              and $width=20)
#@METHOD     : 
#@GLOBALS    : 
#@CALLS      : 
#@CREATED    : 1996/05/22, Greg Ward - adapted from do_mritopet
#@MODIFIED   : 
#-----------------------------------------------------------------------------
sub make_banner
{
   my ($msg, $char, $width) = @_;

   $width = 80 unless $width;           # should this use Term::Cap?!?
   $char = "-" unless $char;

   my $banner = $char x 2 . " " . $msg . " ";
   $banner .= $char x ($width - length ($banner)) . "\n"
}


# ------------------------------ MNI Header ----------------------------------
#@NAME       : &shellquote
#@INPUT      : @words - list of words to possibly quote or escape
#@OUTPUT     : 
#@RETURNS    : concatenation of @words with necessary quotes and backslashes
#@DESCRIPTION: The inverse of shellwords -- takes a list of arguments 
#              (like @ARGV, or a list passed to system or exec) and 
#              escapes meta-characters or encases in quotes as appropriate
#              to allow later processing by the shell.  (/bin/sh, in 
#              particular -- the list of metacharacters was taken from
#              the Perl source that does an exec().)
#@METHOD     : If a word contains no metacharacters, it is untouched.  
#              If it contains both single and double quotes, all meta-
#              characters are escaped with a backslash, and no quotes 
#              are added.  If it contains just single quotes, it is encased
#              in double quotes.  Otherwise, it is encased in single quotes.
#@GLOBALS    : 
#@CALLS      : 
#@CREATED    : 1996/11/13, Greg Ward
#@MODIFIED   : 
#-----------------------------------------------------------------------------
sub shellquote
{
   my (@words) = @_;
   
   local $_;
   for (@words)
   {
      # This list of shell metacharacters was taken from the Perl source
      # (do_exec(), in doio.c).  It is, in slightly more readable form:
      # 
      #    $ & * ( ) { } [ ] ' " ; \ | ? < > ~ ` \n
      #
      # (plus whitespace).  This totally screws up cperl-mode's idea of
      # the syntax, unfortunately, so don't expect indenting to work
      # at all in the rest of this function.

      if ($_ eq "" || /[\s\$\&\*\(\)\{\}\[\]\'\";\\\|\?<>~`\n]/)
      {
         # If the word has both " and ' in it, then just backslash all 
         #   metacharacters;
         # if it has just ' then encase it in "";
         # otherwise encase it in ''

         SUBST:
         {
            (s/([\s\$\&\*\(\)\{\}\[\]\'\";\\\|\?<>~`\n])/\\$1/g, last SUBST)
               if (/\"/) && (/\'/);
            ($_ = qq/"$_"/, last SUBST) if (/\'/);
            $_ = qq/'$_'/;
         }
      }
   }

   join (" ", @words);
}


1;
