#
# Makefile.PL
# 
# Uses MakeMaker to generate the Makefile for the MNI Perl Library.
# Not entirely trivial.
#
# Greg Ward, summer 1997
#
# $Id: Makefile.PL,v 1.6 1999-05-12 22:29:58 stever Exp $
#

use strict;
use ExtUtils::MakeMaker;

my %subs = 
   (DEFAULT_DATA_DIR      => '/usr/local/mni/data');

# $ExtUtils::MakeMaker::Verbose = 1;


sub query_subs
{
   print <<MSG;
I need to know the default directory for static, per-package data (eg.,
models).  This is used so that packages distributed from the MNI have a
consistent, uniform way of searching for such data.  Whatever directory
you specify, you can change your mind later by redoing the
configure/build/install cycle for the MNI Perl Library; or, you can just
put symbolic links in the directory you specify here, pointing to the
real location of the data for whatever MNI packages you use at your
site.  And users can always override this default directory using the
MNI_DATAPATH environment variable.

MSG
   my $dir;

   while (! defined $dir)
   {
      printf "Default directory for model data [%s]? ",
             $subs{'DEFAULT_DATA_DIR'};
      $dir = <STDIN>;
      chop $dir;
      if ($dir =~ /[\x00-\x20]/)
      {
         warn "whitespace or control characters not allowed in dir name\n";
         undef $dir;
      }
   }

   $dir = $subs{'DEFAULT_DATA_DIR'} unless $dir;

   warn <<WARN if ! -d $dir;
warning: $dir doesn't exist; you'll have to create it before
         you can install any MNI software packages
WARN
   $subs{'DEFAULT_DATA_DIR'} = $dir;
}  # &query_subs


# ----------------------------------------------------------------------
# Overrides for standard MakeMaker methods

sub MY::libscan
{
   my ($self, $path) = @_;

   return '' if $path =~ m:\b(RCS|CVS|SCCS)\b:;
   return '' if $path =~ /\.in$/;       # to exclude DataDir.pm.in
   return '' if $path =~ /Compress/;    # to exclude Compress.pm (not ready!)
   $path;
}  # &MY::libscan


sub MY::post_initialize
{
   my $self = shift;

   if ($ExtUtils::MakeMaker::Verbose > 2)
   {
      print "MY::post_initialize:\n";
      print "keys (self) = \n  ";
      print join ("\n  ", sort keys %$self) . "\n\n";

      print "before: MAN3PODS = \n";
      print join ("\n", map
                  (sprintf ("%-30s %s", $_, $self->{MAN3PODS}{$_}), 
                   sort keys %{$self->{MAN3PODS}}));
      print "\n";
   }

   $self->{MAN3PODS}{'MNI/DataDir.pm'} =
      '$(INST_MAN3DIR)/MNI::DataDir.$(MAN3EXT)';
   $self->{PM}{'MNI/DataDir.pm'} =
      '$(INST_LIBDIR)/MNI/DataDir.pm';

   if ($ExtUtils::MakeMaker::Verbose > 1)
   {
      print "MY::post_initialize: now MAN3PODS =\n";
      print join ("\n", map
                  (sprintf ("%-30s %s", $_, $self->{MAN3PODS}{$_}), 
                   sort keys %{$self->{MAN3PODS}}));
      print "\n";

      print "MY::post_initialize: now PM =\n";
      print join ("\n", map
                  (sprintf ("%-30s %s", $_, $self->{PM}{$_}), 
                   sort keys %{$self->{MAN3PODS}}));
      print "\n";
   }

   '';                                  # don't actually want to put anything
                                        # in the makefile!
}  # &MY::post_initialize


sub MY::dist
{
   my $self = shift;

   my $text = $self->MM::dist;
   $text =~ s/ci -u/ci -u -d/m 
      or warn "dist: couldn't tweak 'ci -u'";
   $text =~ s/-Nv/-sRel -N\$(NAME_SYM)_v/m 
      or warn "dist: couldn't tweak 'rcs -N'";
   $text;
}


sub MY::macro
{
   my $self = shift;
   my ($text, $token, $value);

   $text = $self->MM::macro;
   for $token (sort keys %subs)
   {
      $value = $subs{$token};
      $text .= "$token = $value";
   }
   $text;
}  # &MY::macro


sub MY::manifypods
{
   my $self = shift;
   my ($release, $center);

   local $_ = $self->MM::manifypods;
   if (/system\(\"\$\$\^X/)             # looks like this with MakeMaker 5.21
   {                                    # (Perl 5.002)
      $release = q[\"version $(VERSION)\"];
      $center = q[\"MNI Perl Library\"];
   }
   elsif (/system\(qq\[\$\$\^X/)        # but like this starting with
   {                                    # MakeMaker 5.34 (Perl 5.003)
      $release = q["version $(VERSION)"];
      $center = q["MNI Perl Library"];
   }
   else
   {
      warn "Makefile.PL: I don't grok the manifypods section, so can't tweak the pod2man args";
      return $_;
   }

   s/^(POD2MAN_EXE.*pod2man)$/$1 --section=3 --release=$release --center=$center/m
      or warn "couldn't tweak pod2man command\n";
   $_;
}  # &MY::manifypods


sub MY::test
{
   my $self = shift;
   my $text;

   $text = $self->MM::test;
   $text =~ s|^(test \s* ::) \s*|$1 t/datadir.t t/toy_ls |mx
      or warn "warning: couldn't fiddle `test' section " .
              "to add t/datadir.t dependency";
   $text;
}


sub MY::postamble
{
   my $self = shift;
   my $text;

   $text = $self->MM::postamble;
   $text .= <<'TEXT';
MNI/DataDir.pm : MNI/DataDir.pm.in Makefile
	rm -f $@
	sed 's|@DEFAULT_DATA_DIR@|$(DEFAULT_DATA_DIR)|' MNI/DataDir.pm.in > $@
	chmod 444 $@

t/datadir.t : t/datadir.t.in Makefile
	rm -f $@
	sed 's|@DEFAULT_DATA_DIR@|$(DEFAULT_DATA_DIR)|' t/datadir.t.in > $@
	chmod 444 $@

t/toy_ls : t/toy_ls.in Makefile
	rm -f $@
	sed 's|@PERL@|\#!$(FULLPERL)|' t/toy_ls.in > $@
	chmod 555 $@

TEXT

   print "MY::postamble: now text = \n" . $text . "\n"
      if $ExtUtils::MakeMaker::Verbose > 1;

   $text;
}  # &MY::postamble


query_subs;

my $f;
WriteMakefile 
   (
    NAME          => 'mni_perllib',
    VERSION_FROM  => 'MNI.pm',
    PMLIBDIRS     => ['MNI'],
    dist          => { COMPRESS=>"gzip", SUFFIX=>"gz" },
    clean         => { FILES => 'MNI/DataDir.pm t/datadir.t t/toy_ls' },
   );
