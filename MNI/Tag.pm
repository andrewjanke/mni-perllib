# ------------------------------ MNI Header ----------------------------------
#@NAME       : MNI::Tag.pm
#@DESCRIPTION: Perl interface to the BIC tag files.
#              This is PRE-Alpha CODE!  Use at your own risk!!
#@CREATED    : 13 August 1999, Steve M. Robbins
#-----------------------------------------------------------------------------


package MNI::Tag;

use strict;
use Carp;
use File::Basename;
use File::Path;


my $TAG_FILE_HEADER = "MNI Tag Point File";
my $VOLUMES_STRING = "Volumes";
my $TAG_POINTS_STRING = "Points";


# Constructor that reads an existing tag file
# Parameter: filename
#
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


# Copy constructor
# Parameter: new filename
#
sub copy {
    my( $that, $filename ) = @_;
    my $class = ref($that) || $that;

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


# Construct a new tag file. 
# Parameters are a set of key => value pairs.
#
# Possible keys:
#   filename
#   num_volumes
#
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


sub close { $_[0]->save(); }

sub DESTROY { $_[0]->close(); }


# Returns the number of volumes
#
sub numberOfVolumes { return $_[0]->{num_volumes}; }


# Returns the number of tags
#
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
	    carp "tag index out of range: $index \n";
	    return;
	}
    } else {
	$index = $self->{"_label_$label"};
	if (defined($new_value) and !defined($index)) {
	    $index = scalar(@{$self->{$v}});
	    $self->{"_label_$label"} = $index;
	} elsif ( !defined($index) ) {
	    carp "tag label not defined: $label\n";
	    return;
	}
    }

    if ($new_value) {
	@{$self->{$v}}[$index] = $new_value;
        $self->{_dirty} = 1;
    }
    
    return @{$self->{$v}}[$index];
}

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

# Get the label associated with point number `i'
#
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

# Get list of all labels
#
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

    open( OUT, ">$filename" )
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
    close( OUT ) 
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

    open( IN, $filename ) 
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
    close( IN );
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
