## Manipulate a BIC .tag file
#

package MNI::Tag;

use strict;
use Carp;
use File::Basename;
use File::Path;


# Constructor takes a filename
#
sub new {
    my( $this, $filename ) = @_;
    my $class = ref($this) || $this;

    $filename .= ".tag" unless ( $filename =~ /\.tag$/ );

    my $self = 
      { _filename => $filename,
	_num_volumes => undef,
	_volume1 => undef,
	_volume2 => undef,
      };
    return bless( $self, $class );
}


# Returns the number of volumes
#
sub numberOfVolumes {
    my $self = shift;
    $self->_read();
    return $self->{_num_volumes};
}


# Returns the number of tags
#
sub numberOfTags {
    my $self = shift;
    $self->_read();
    return scalar( @{$self->{_volume1}} );
}


# Returns one or all the points for a volume.
#
# Parameters:
#   v     - either _volume1 or _volume2
#   label - one of: undef, integer, word
#
sub _volume {
    my( $self, $v, $label ) = @_;
    $self->_read();

    if ( !defined($label) ) {
	return @{$self->{$v}};
    }

    my $index;
    if ( $label =~ /^\d+$/ ) {
	$index = $label;
	if ( $index < 0 or $index > $self->numberOfTags() ) {
	    carp "tag index out of range: $index \n";
	    return;
	}
    } else {
	$index = $self->{"_label_$label"};
	if ( !defined($index) ) {
	    carp "tag label not defined: $label\n";
	    return;
	}
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
      if ( $self->{_num_volumes} < 2 );
    return $self->_volume( "_volume2", @_ );
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
sub _read {
    my $self = shift;
    local $_;

    # Do nothing if we have already read the file.
    return if ( defined($self->{_num_volumes}) ) ;

    open( IN, $self->{_filename} ) 
      or croak "$self->{_filename} cannot be read";

    <IN> =~ /MNI Tag Point File/ 
      or croak "$self->{_filename} is not a tag point file.\n";

    <IN> =~ /Volumes = (\d+)/ 
      or croak "$self->{_filename} has no \"volumes\" line.\n";

    $self->{_num_volumes} = $1;

    # Skip comment lines
    do { $_ = <IN> } until /Points =/;

    $self->{_volume1} = [];
    if ( $self->{_num_volumes} > 1 ) {
	$self->{_volume2} = [];
    }
    $self->{_labels} = [];

    while( defined($_ = <IN>) ) {
	my( $p1, $p2, $label );

	($_,$p1) = _read_point( $_ );
	($_,$p2) = _read_point( $_ );
	($_,$label) = _read_label( $_ );

	push( @{$self->{_volume1}}, $p1 );
	if ( $self->{_num_volumes} > 1 and defined($p2) ) {
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
