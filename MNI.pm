# ------------------------------ MNI Header ----------------------------------
#@NAME       : MNI
#@DESCRIPTION: Dummy module used to give the whole MNI Perl Library a 
#              version number.
#@EXPORT     : 
#@EXPORT_OK  : 
#@EXPORT_TAGS: 
#@USES       : 
#@REQUIRES   : 
#@CREATED    : 1997/05/13, Greg Ward
#@MODIFIED   : 
#@VERSION    : $Id: MNI.pm,v 1.3 2000-01-16 20:38:37 stever Exp $
#@COPYRIGHT  : Copyright (c) 1997 by Gregory P. Ward, McConnell Brain Imaging
#              Centre, Montreal Neurological Institute, McGill University.
#
#              This file is part of the MNI Perl Library.  It is free 
#              software, and may be distributed under the same terms
#              as Perl itself.
#-----------------------------------------------------------------------------

package MNI;

use strict;
require 5.002;
require Exporter;

@MNI::ISA = ('Exporter');
$MNI::VERSION = '0.06';
