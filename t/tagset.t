# test program for MNI::Tag -*- Perl -*-

use strict;
use MNI::TagSet;

print "1..10\n";

my $i = 0;
sub test { printf "%s %d\n", ($_[0] ? "ok" : "not ok"), ++$i; }

sub eq_point {
    my( $p, $q ) = @_;
    return ref($p) eq 'ARRAY'
      && ref($q) eq 'ARRAY'
	&& scalar(@$p) == 3
	  && scalar(@$q) == 3
	    && $p->[0] == $q->[0]
	      && $p->[1] == $q->[1]
		&& $p->[2] == $q->[2];
}

sub test_point { test(eq_point(@_)); }

sub eq_tagset {
    my( $s, $t ) = @_;
    my $res = $s->numberOfVolumes() == $t->numberOfVolumes()
      && $s->numberOfTags() == $t->numberOfTags();
    my $i = 0;

    while ( $res and $i < $s->numberOfTags() ) {
	$res &&= eq_point( $s->volume1($i),
			   $t->volume1($i) );
	$res &&= eq_point( $s->volume2($i),
			   $t->volume2($i) )
	  if ( $s->numberOfVolumes > 1 ); 
	$res &&= $s->label($i) eq $t->label($i);
	++$i;
    }
    $res;
}

sub test_tagset { test(eq_tagset(@_)); }

sub is_member {
    my( $elem, $lr ) = @_;
    return grep { /$elem/ } @$lr;
}

sub eq_list {
    my( $l1, $l2 ) = @_;
    scalar(@$l1) == scalar(@$l2)
      and !grep { !is_member($_, $l2); } @$l1;
}

sub test_list { test(eq_list(@_)); }
    


my $tag =  MNI::TagSet->open( "t/example1.tag" );

test( $tag->numberOfVolumes() == 1 );
test( $tag->numberOfTags() == 3 );
test_point( $tag->volume1(0), [(1,2,3)] );
test_point( $tag->volume1("second tag"), [(2,4,6)] );
test_list( [$tag->all_labels()], 
	   [("first point", "second tag", "third point")] );

my $copytag = $tag->copy( ".tag$$-1" );
test_tagset( $tag, $copytag );
$copytag->close();

$copytag = MNI::TagSet->open( ".tag$$-1" );
test_tagset( $tag, $copytag );
$copytag->volume1(0,[1,1,1]);
test( !eq_tagset($tag, $copytag));
$copytag->close();

my $ntag = MNI::TagSet->new( filename => ".tag$$-2", 
			  num_volumes => 1 );
$ntag->volume1(0,[4,3,2]);
test_point( $ntag->volume1(0), [4,3,2]);
$ntag->volume1(1,[4,3,21]);
test_point( $ntag->volume1(1), [4,3,21]);

# This test will emit a bunch of warnings.
# I don't know how to suppress them for test purposes, so
# I leave this commented out.
#my @pointlist = map {$_->volume1('first point')} ($ntag, $ntag, $tag, $ntag);
#test( @pointlist == 1 );

$ntag->close();


