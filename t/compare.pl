sub fequal { $_[0] - $_[1] < 0.000001 }

sub list_equal
{
   my ($eq, $a, $b) = @_;

   die "lequal: \$a and \$b not lists" 
      unless ref $a eq 'ARRAY' && ref $b eq 'ARRAY';

   return 0 unless @$a == @$b;          # compare lengths
   my @eq = map { &$eq ($a->[$_], $b->[$_]) } (0 .. $#$a);
   return 0 unless (grep ($_ == 1, @eq)) == @eq;
}

sub slist_equal
{
   my ($a, $b) = @_;
   list_equal (sub { $_[0] eq $_[1] }, $a, $b);
}

sub nlist_equal
{
   my ($a, $b) = @_;
   list_equal (sub { $_[0] == $_[1] }, $a, $b);
}

sub flist_equal
{
   my ($a, $b) = @_;
   list_equal (\&fequal, $a, $b);
}


1;
