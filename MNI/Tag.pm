package MNI::Tag;

=head1 NAME

MNI::Tag - module for accessing MNI tag files

=head1 SYNOPSIS

  use MNI::Tag;

  $in = MNI::Tag->open( "existing.tag" );
  $out = MNI::Tag->new( filename => "new.tag" );

=head1 DESCRIPTION

=head1 METHODS

=over 4

=cut


use strict;
use Carp;
use File::Basename;
use File::Path;


my $TAG_FILE_HEADER = "MNI Tag Point File";
my $VOLUMES_STRING = "Volumes";
my $TAG_POINTS_STRING = "Points";


=item MNI::Tag::open( filename )

Constructor that reads an existing tag file.  The tag file suffix
(.tag) is appended to the filename if necessary.  Croaks if the file
does not exist, or is not a recognizable tag file.

=cut

sub open {
    my( $this, $filename ) = @_;
    my $class = ref($this) || $this;

    $filename .= ".tag" unless ( $filename =~ /\.tag$/ );

    my $self = 
      { filename => $filename,
        num_volumes => undef,
        _volume1 => undef,
        _volume2 => undef,
      };

    bless( $self, $class );
    $self->load();
    return $self;
}


=item MNI::Tag::copy( filename )

Copy constructor; must be invoked using a valid MNI::Tag reference.
Must give a new filename for the copy.

=cut

sub copy {
    my( $that, $filename ) = @_;
    my $class = ref($that);

    croak "The copy constructor must be invoked on a valid reference"
      unless $class;

    my $self = { %$that };

    if ( $filename ) {
	$filename .= ".tag" unless ( $filename =~ /\.tag$/ );
    }
    $self->{filename} = $filename;
    $self->{_volume1} = [ $that->volume1() ];
    $self->{_volume2} = [ $that->volume2() ]
      if $that->{num_volumes} > 1;
    $self->{_dirty} = 1;

    return bless( $self, $class );
}


=item MNI::Tag::new( option => value ... )

Construct a new tag file.  Possible options: filename, num_volumes.

=cut

sub new {
    my $this = shift;
    my $class = ref($this) || $this;

    my $self = 
      { @_,
	_comments => '',
        _volume1 => [],
        _volume2 => [],
      };

    if ( $self->{filename} ) {
	$self->{filename} .= ".tag" 
	  unless ( $self->{filename} =~ /\.tag$/ );
    }
    $self->{num_volumes} = 1
      unless defined($self->{num_volumes});

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

sub numberOfTags { return scalar( @{$_[0]->{_volume1}} ); }


# Returns one or all the points for a volume.
#
# Parameters:
#   v     - either _volume1 or _volume2
#   label - one of: undef, integer, word
#   value - array ref containing new value
#
sub _volume {
    my( $self, $v, $label, $new_value ) = @_;

    if ( !defined($label) ) {
	return @{$self->{$v}};
    }

    my $index;
    if ( $label =~ /^\d+$/ ) {
	$index = $label;
	if (defined($new_value)) {
	} elsif ( $index < 0 or $index >= $self->numberOfTags() ) {
	    carp "tag index `$index' out of range";
	    return;
	}
    } else {
	$index = $self->{"_label_$label"};
	if (defined($new_value) and !defined($index)) {
	    $index = scalar(@{$self->{$v}});
	    $self->{"_label_$label"} = $index;
	} elsif ( !defined($index) ) {
	    carp "tag label `$label' not defined";
	    return;
	}
    }

    if ($new_value) {
	@{$self->{$v}}[$index] = $new_value;
        $self->{_dirty} = 1;
    }
    
    return @{$self->{$v}}[$index];
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
    return $self->_volume( "_volume1", @_ );
}

sub volume2 {
    my $self = shift;
    croak "Accessing volume2 of single-volume tag set\n"
      if ( $self->{num_volumes} < 2 );
    return $self->_volume( "_volume2", @_ );
}


=item label( N )

Get the label associated with Nth tag point.  Index starts at zero.

=cut

sub label {
    my($self, $i) = @_;

    my( $key, $val );
    keys %$self; # to reset the iterator for "each"
    while (($key, $val) = each %$self) {
	next unless $key =~ /^_label_/;
	if ($val == $i) {
	    $key =~ s/^_label_//;
	    return $key;
	}
    }
    return undef;
}


=item all_labels()

Return array of all labels in Tag file.

=cut

sub all_labels {
    my $self = shift;
    return map { /^_label_(.*)/ ? $1 : (); } keys %$self;
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

    my $comments = '';
    $comments = $self->{_comments} if defined($self->{_comments});

    printf OUT "%s\n", $TAG_FILE_HEADER;
    printf OUT "%s = %d;\n", $VOLUMES_STRING, $self->numberOfVolumes();
    print OUT $comments . "\n";
    printf OUT "%s =", $TAG_POINTS_STRING;

    my $i = 0;
    my @v1 = $self->volume1();
    my @v2 = $self->numberOfVolumes() == 1 ? () : $self->volume2();

    while (@v1) {
	my $p = shift @v1;
	print OUT "\n ", join(' ', @$p);

	if ( $self->numberOfVolumes() > 1 ) {
	    $p = shift @v2 
	      || croak "tag is missing second volume.";
	    print OUT join(' ', @$p);
	}

	# FIXME
	# Ignoring auxiliary data

	my $label = $self->label( $i );
	print OUT " \"$label\"" if $label;

	++$i;
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

    # Skip comment lines
    do { $_ = <IN> } until /Points =/;

    $self->{_volume1} = [];
    if ( $self->{num_volumes} > 1 ) {
	$self->{_volume2} = [];
    }

    while( defined($_ = <IN>) ) {
	my( $p1, $p2, $label );

	($_,$p1) = _read_point( $_ );
	($_,$p2) = _read_point( $_ );
	($_,$label) = _read_label( $_ );

	push( @{$self->{_volume1}}, $p1 );
	if ( $self->{num_volumes} > 1 and defined($p2) ) {
	    push( @{$self->{_volume2}}, $p2 );
	}
	if ( defined($label) ) {
	    $self->{"_label_${label}"} = scalar(@{$self->{_volume1}}) - 1;
	}
    }
    CORE::close( IN );
}

sub _read_point {
    $_[0] =~ /([+-]?[\d\.]+)\s+([+-]?[\d\.]+)\s+([+-]?[\d\.]+)/;
    if ( !defined($3) ) {
	return ($_[0], undef );
    }
    return ($', [ $1, $2, $3 ] );
}

sub _read_label {
    $_[0] =~ /\"(.*)\"/;
    return ($',$1);
}

1;
