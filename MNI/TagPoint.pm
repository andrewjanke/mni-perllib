package MNI::TagPoint;

=head1 NAME

MNI::TagPoint - one point of a tag set

=head1 SYNOPSIS


=head1 DESCRIPTION

=head1 METHODS

=over 4

=cut


use strict;
use Carp;
use File::Basename;
use File::Path;


=item MNI::TagPoint::new( option => value ... )

Construct a new tag point.  You can supply values for 
any of the following: volume1, volume2, weight, structure_id,
patient_id, or label.  At a minimum, volume1 must be specified.

=cut

sub new {
    my $this = shift;
    my $class = ref($this) || $this;

    my $self = 
      { volume1 => undef,
	volume2 => undef,
	weight => undef,
	structure_id => undef,
	patient_id => undef,
	label => undef,
	@_,     # allow caller to override any of the above
      };

    croak "no coordinates defined for volume1"
      unless defined($self->{volume1});

    return bless( $self, $class );
}


sub volume1      { return $_[0]->{volume1} }
sub volume2      { return $_[0]->{volume2} }
sub weight       { return $_[0]->{weight} }
sub structure_id { return $_[0]->{structure_id} }
sub patient_id   { return $_[0]->{patient_id} }
sub label        { return $_[0]->{label} }



# Export to string
#
sub to_string {
    my $self = shift;

    my $str = sprintf( "%.15g %.15g %.15g", @{$self->volume1} );
    $str .= sprintf( " %.15g %.15g %.15g", @{$self->volume2} )
      if defined($self->volume2);

    # weight, structure_id, and patient_id are optional (but either 
    # all of them have to be defined, or none of them should!)

    $str .= sprintf( " %d %d %d", 
		     $self->weight,
		     $self->structure_id,
		     $self->patient_id )
	if defined($self->weight) && 
	    defined($self->structure_id) && 
		defined($self->patient_id);

    $str .= ' "' . $self->label . '"'
      if defined($self->label);

    return $str;
}


# # Import from string
# # ** TODO **
# sub _parse_tagline {
#     local $_ = shift;

#     ($_,$p1) = _read_point( $_ );
#     ($_,$p2) = _read_point( $_ );
#     ($_,$label) = _read_label( $_ );
# }



# sub _parse_point {
#     $_[0] =~ /\s*([+-]?[\d\.]+)\s+([+-]?[\d\.]+)\s+([+-]?[\d\.]+)/;
#     if ( !defined($3) ) {
# 	return ($_[0], undef );
#     }
#     return ($', [ $1, $2, $3 ] );
# }

# sub _parse_label {
#     $_[0] =~ /\"(.*)\"/;
#     return ($',$1);
# }

1;
