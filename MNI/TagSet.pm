package MNI::TagSet;

=head1 NAME

MNI::TagSet - module for accessing MNI tag files

=head1 SYNOPSIS

  use MNI::TagSet;

  $in = MNI::TagSet->open( "existing.tag" );
  $out = MNI::TagSet->new( filename => "new.tag" );

=head1 DESCRIPTION

=head1 METHODS

=over 4

=cut


use strict;
use Carp;
use File::Basename;
use File::Path;
use Text::ParseWords;
use MNI::TagPoint;
use MNI::MiscUtilities;


my $TAG_FILE_HEADER = "MNI Tag Point File";
my $VOLUMES_STRING = "Volumes";
my $TAG_POINTS_STRING = "Points";


=item MNI::TagSet::open( filename [, comments] )

Constructor that reads an existing tag file.  The tag file suffix
(.tag) is appended to the filename if necessary.  Croaks if the file
does not exist, or is not a recognizable tag file.

If the second optional parameter I<comments> appears, it is
appended to any existing comments in the file.  I<comments> may
be a string or a reference to an array of strings.

=cut

sub open {
    my( $this, $filename, $comments ) = @_;
    my $class = ref($this) || $this;

    $filename .= ".tag" unless ( $filename =~ /\.tag$/ );

    my $self = 
      { filename => $filename,
        num_volumes => undef,
	set => [],
      };

    bless( $self, $class );
    $self->load();
    $self->add_comment($comments)  if $comments;
    return $self;
}


=item MNI::TagSet::copy( filename [, comments] )

Copy constructor; must be invoked using a valid MNI::TagSet reference.
Must give a new filename for the copy.

If the second optional parameter I<comments> appears, it is
appended to any existing comments in the file.  I<comments> may
be a string or a reference to an array of strings.

=cut

sub copy {
    my( $that, $filename, $comments ) = @_;
    my $class = ref($that);

    croak "The copy constructor must be invoked on a valid reference"
      unless $class;

    my $self = { %$that };
    bless( $self, $class );

    if ( $filename ) {
	$filename .= ".tag" unless ( $filename =~ /\.tag$/ );
    }
    $self->{filename} = $filename;
    $self->add_comment($comments)  if $comments;
    $self->{_dirty} = 1;

    return $self;
}


=item MNI::TagSet::new( option => value ... )

Construct a new tag file.  Possible options: filename, num_volumes,
comment.

=cut

sub new {
    my $this = shift;
    my $class = ref($this) || $this;

    my $self = 
      { @_,
	set => [],
	_dirty => 1,
      };

    if ( $self->{filename} ) {
	$self->{filename} .= ".tag" 
	  unless ( $self->{filename} =~ /\.tag$/ );
    }
    $self->{num_volumes} = 1
      unless defined($self->{num_volumes});

    if (defined($self->{comment})) {
	$self->{comment} = [ $self->{comment} ]
	  unless ref $self->{comment};
    }

    return bless( $self, $class );
}


# Don't think we want to expose this to users.
#
#=item close
#
#  Close the tag file, saving any pending changes.
#  This is called automatically by the destructor.
#
#=cut

sub close { $_[0]->save(); }

sub DESTROY { $_[0]->close(); }


=item numberOfVolumes

Returns the number of volumes.

=cut

sub numberOfVolumes { return $_[0]->{num_volumes}; }


=item numberOfTags

Returns the number of tags.

=cut

sub numberOfTags { return scalar( @{$_[0]->{set}} ); }


=item add_comment( comment [, comment] )

Add comment(s) to the tag set.  Each comment appears on a line
by itself in the tag file.  

=cut

sub add_comment {
    my $self = shift;

    $self->{comment} = [] unless defined($self->{comment});
    push( @{$self->{comment}}, @_ );
    $self->{_dirty} = 1;
}



# Return the TagPoint referred to by the parameter
# (either an integer index or a textual label)
#
sub get_point {
    my( $self, $label ) = @_;

    if ( $label =~ /^\d+$/ ) {
	return $self->{set}->[$label];
    } else {
	local $_;
	my @ret = grep {$_->label eq $label} @{$self->{set}};
	carp "tag label `$label' not defined"
	  if @ret == 0;
	carp "tag label `$label' multiply defined"
	  if @ret > 1;
	return $ret[0];
    }
}


=item get_points()

Returns array of C<TagPoint> references.

=cut

sub get_points {
    my $self = shift;
    return @{$self->{set}};
}


=item add_points( point [, point ...] )

Add one or more C<TagPoint>s to the C<TagSet>.
The new points are appended to the set.

=cut

sub add_points {
    my $self = shift;
    push( @{$self->{set}}, @_ );
    $self->{_dirty} = 1;
}

# [CC, 2001/06/24]
#
# given a volume1 position (as a ref to an array of coordinates),
# it returns the index of the first tag point at that location,
# or undef if not found.
#
# BUGS: it may not work properly on non-int tag coordinates!
# CAVEATS: it is very slow!
#
sub find_tag {
    my( $self, $position ) = @_;
    my $index = 0;
    foreach my $tag (@{$self->{set}}) {
	return $index 
	    if MNI::MiscUtilities::nlist_equal( $tag->volume1, $position); 
	++$index;
    }
    return undef;
}

# [CC, 2001/06/24]
#
# given a volume1 position (as a ref to an array of coordinates),
# it returns the index of the first tag point at that location,
# or undef if not found.
#
# CAVEATs: 
#   - coordinates different by less than 0.01mm are considered equal
#   - if several tags have equal coordinates, the last one of 'em is returned
#   - only works fast if the tagset was read from disk and never modified
#     (i.e. if ! _dirty )
#
sub fast_find_tag {
    my( $self, $position ) = @_;

    return $self->find_tag($position)
	if $self->{_dirty};
    
    my @position;
    # create the search hash first time when we're called
    unless( $self->{_search} ) {
	my $index = 0;
	foreach my $tag (@{$self->{set}}) {
	    @position= map { 100*$_ } @{$tag->volume1};
	    $self->{_search}->{$position[0]}{$position[1]}{$position[2]} = 
		$index ++;
	}
    }
    @position= map { 100*$_ } @$position;
    return $self->{_search}->{$position[0]}{$position[1]}{$position[2]};
}

# Convert to TagPoint index.
#
sub get_index {
    my( $self, $label ) = @_;

    return $label 
      if ( $label =~ /^\d+$/ );

    my $index = 0;
    foreach my $tag (@{$self->{set}}) {
	return $index if $tag->label eq $label;	  
	++$index;
    }

    carp "tag label `$label' not defined";
    return undef;
}


=item volume1

=item volume2

Returns all tag points in volume.

=item volume1( N [, val ] )

=item volume2( N [, val ] )

Returns the Nth tag point of the volume.  Index starts at zero.

If ref to array of three coordinates is given as optional second
argument, the coordinates will be updated.

=item volume1( label [, val ] )

=item volume2( label [, val ] )

Get or set the tag point specified by tag label, otherwise identical
to second usage.

=cut

sub volume1 {
    my $self = shift;
    my( $label, $new_value ) = @_;

    if ( !defined($label) ) {
	local $_;
	return map {$_->volume1} @{$self->{set}};
    }

    my $index = $self->get_index( $label );

    if ($new_value) {
	croak "cannot set unknown tag"
	  unless defined($index);
	$self->{set}->[$index] 
	  = new MNI::TagPoint( %{$self->{set}->[$index]},
			       volume1 => $new_value );
        $self->{_dirty} = 1;
    }

    return $self->{set}->[$index]->volume1;
}


sub volume2 {
    my $self = shift;
    croak "Accessing volume2 of single-volume tag set\n"
      if ( $self->{num_volumes} < 2 );

    my( $label, $new_value ) = @_;

    if ( !defined($label) ) {
	local $_;
	return map {$_->volume2} @{$self->{set}};
    }

    my $index = $self->get_index( $label );

    if ($new_value) {
	croak "cannot set unknown tag"
	  unless defined($index);
	$self->{set}->[$index] 
	  = new MNI::TagPoint( %{$self->{set}->[$index]},
			       volume2 => $new_value );
        $self->{_dirty} = 1;
    }

    return $self->{set}->[$index]->volume2;
}


=item label( N )

Get the label associated with Nth tag point.  Index starts at zero.

=cut

sub label {
    my($self, $i) = @_;

    return $self->{set}->[$i]->label;
}


=item all_labels()

Return array of all labels in Tag file.

=cut

sub all_labels {
    my $self = shift;
    local $_;
    return map { $_->label || () } @{$self->{set}};
}


# Write tag file data.
#
sub save {
    my( $self, $filename ) = @_;
    local $_;

    $filename = $self->{filename} unless $filename;

    # Do nothing if tag has no corresponding file or has not been modified.
    return unless ($filename and $self->{_dirty});

    CORE::open( OUT, ">$filename" )
      or croak "$filename : $!\n";

    my $comment_lines = '';
    if (defined($self->{comment})) {
	$comment_lines 
	  = join( "\n", 
		  map { /^%/ ? $_ : "% $_" } @{$self->{comment}} );
	$comment_lines .= "\n";
    }

    printf OUT "%s\n", $TAG_FILE_HEADER;
    printf OUT "%s = %d;\n", $VOLUMES_STRING, $self->numberOfVolumes();
    print OUT $comment_lines . "\n";
    printf OUT "%s =", $TAG_POINTS_STRING;

    foreach my $tag (@{$self->{set}}) {
	print OUT "\n ", $tag->to_string;
    }

    print OUT ";\n";
    CORE::close( OUT ) 
      or croak "$filename: $!\n";

    $self->{_dirty} = 0;
}



# Read tag file data.
#
# Each "tag" has 1 or 2 sets of coordinates,
# and auxiliary data (weight, structure ID, patient ID, label).
#
# Read the coordinates into an array and store reference to it
# in _volume1 or _volume2.  If we also have a label, store 
# key "_label_${label}" in the hash, with value of the index of the
# point.
#
sub load {
    my( $self, $filename ) = @_;
    local $_;

    $filename = $self->{filename} unless $filename;

    CORE::open( IN, $filename ) 
      or croak "$filename cannot be read ($!)";

    <IN> =~ /MNI Tag Point File/ 
      or croak "$filename is not a tag point file.\n";

    <IN> =~ /Volumes = (\d+)/ 
      or croak "$filename has no \"volumes\" line.\n";

    $self->{num_volumes} = $1;

    my @comments;
    do { 
	$_ = <IN>;
	push(@comments, $1) if /^%\s*(.*)/;
     } until /Points =/;
    $self->{comment} = \@comments;

    $self->{set} = [];
    while( defined($_ = <IN>) ) {
	my $val;
	my @args;

	chomp; 	s/;$//;

	($_,$val) = _read_point( $_ );
	push(@args, 'volume1' => $val);

	if ($self->{num_volumes} > 1) {
	    ($_,$val) = _read_point( $_ );
	    push(@args, 'volume2' => $val);
	}
	
	# MNI tag files can have either of: 0, 1, 3, or 4 additional 
	# strings of info, white-space separated.
	#
	# these (optional) additional strings are: weight (float), 
	# structure_id (integer), patient_id (int), label (string --
	# can be optionally double-quoted to allow white-space in it).
	# -- see code below for details...

	# this silly thing called Text::ParseWords::quotewords doesn't
	# properly handle leading and trailing delimiters (white-space): 
	# if there is any, the first and last elements of @words will 
	# be empty !!?
	s/^\s*//;  s/\s*$//; # strip leading/trailing white-space
	my @words= Text::ParseWords::quotewords( '\s+', 0, $_ );
	#foreach (@words) { print "\'${_}\' "; }	print "\n";

	if( 4 == @words ) {
	    # TODO: check if we have indeed a (float, int, int, string)
	    my %tmphash;
	    @tmphash{ (qw/ weight structure_id patient_id label /) }= @words;
	    push(@args, %tmphash);
	}
	if( 3 == @words ) {
	    # TODO: check if we have indeed a (float, int, int)
	    my %tmphash;
	    @tmphash{ (qw/ weight structure_id patient_id label /) }= 
		( @words, undef);
	    push(@args, %tmphash);
	}
	elsif( 1 == @words ) {
	    push(@args, 'label' => $words[0]);
	}
	elsif( 0 != @words ) {
	    croak "$filename : invalid format (" . scalar(@words) . ": unexpected number of additional strings)\n";
	}

	push( @{$self->{set}}, new MNI::TagPoint( @args ) );

    }
    CORE::close( IN );
}

sub _read_point {
    $_[0] =~ /([+-]?[\d\.]+)\s+([+-]?[\d\.]+)\s+([+-]?[\d\.]+)/;
    if ( !defined($3) ) {
	croak "failed to read a point";
    }
    return ($', [ $1, $2, $3 ] );
}

#  sub _read_int {
#      $_[0] =~ /([+-]?[\d]+)/;
#      if ( !defined($1) ) {
#  	return ( $_[0], undef );
#      }
#      return ( $', $1 );
#  }

#  sub _read_label {
#      $_[0] =~ /\"(.*)\"/;
#      return ($',$1);
#  }



package MNI::Tag;
use vars ('@ISA');
@ISA = ('MNI::TagSet');


1;
