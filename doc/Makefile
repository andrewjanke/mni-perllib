# 
# Makefile for the printed documentation to the MNI Perl Library
#
# by Greg Ward 1997/08/27
#

TOPDIR = ..
LIBDIR = $(TOPDIR)/blib/lib
MARKER = $(TOPDIR)/MNI.pm

SHELL  = /bin/sh
PERL   = /usr/local/bin/perl5
PERLLIB= $(LIBDIR)

SOURCE = MNI/Startup.pm\
	 MNI/Spawn.pod\
	 MNI/FileUtilities.pm\
	 MNI/PathUtilities.pm\
	 MNI/MiscUtilities.pm\
	 MNI/NumericUtilities.pm\
	 MNI/MincUtilities.pm\
	 MNI/DataDir.pm\
	 Getopt/Tabular.pod
TMPDIRS= MNI Getopt

POD    = $(SOURCE:.pm=.pod)
TEX    = $(POD:.pod=.tex)

REFTITLE = title.tex
INPUTS = inputs.tex

REFDOC = mni_perllib
REFSRC = $(REFDOC).tex
REFAUX = $(REFDOC).aux
REFTOC = $(REFDOC).toc
REFDVI = $(REFDOC).dvi
REFPS  = $(REFDOC).ps

ps : $(REFPS)                # eventually will add perltips.ps here

$(REFPS) : blib $(REFDVI)
	dvips $(REFDVI) -o $(REFPS)

$(REFDVI) : $(REFAUX) $(REFTOC)
	latex $(REFDOC)

# Two latex runs are needed to generate the (correct) .toc file; the
# first merely generates a toc of the right size (which may be inaccurate),
# the second pass includes the first guess at the .toc file, which can
# push the rest of the document down a bit -- meaning that this time we will
# get the toc right.  The third pass, down to generate $(REFDVI) above,
# will actually include the right toc in the document.
$(REFAUX) $(REFTOC) : $(REFTITLE) $(INPUTS) $(TEX) $(REFSRC)
	latex $(REFDOC)
	latex $(REFDOC)
	rm -f $(REFDVI)

$(REFTITLE) $(INPUTS) $(TEX) :
	PERL5LIB=$(PERLLIB) $(PERL) make_latex $(MARKER) $(LIBDIR) $(SOURCE)

blib : 
	cd .. ; make


clean : 
	rm -f $(REFAUX) $(REFTOC) $(REFDVI) $(REFPS) $(REFDOC).log \
              $(REFTITLE) $(INPUTS)
	rm -rf $(TMPDIRS)
