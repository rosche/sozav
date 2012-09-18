# $Id: Util.pm,v 1.13 2012-09-18 13:51:27 roderick Exp $

package Game::Util;

use strict;

use base qw(Exporter);

use RS::Handy	qw(badinvo data_dump dstr fileline xconfess);
use Scalar::Util qw(looks_like_number refaddr);

use vars qw($VERSION @EXPORT @EXPORT_OK);

$VERSION = q$Revision: 1.13 $ =~ /(\d\S+)/ ? $1 : '?';

BEGIN {
    @EXPORT = qw(
	$Debug
	add_array_index_type
	add_array_index
	add_array_indices
	debug
	debug_var
	eval_block
	knapsack_0_1
	make_ro_accessor
	make_ro_accessor_multi
	make_rw_accessor
	make_accessor_pkg
	same_referent
	valid_ix
	valid_ix_plus_1
    );
    @EXPORT_OK = qw(
    	%Index
    );
}

use subs grep { /^[a-z]/    } @EXPORT, @EXPORT_OK;
use vars grep { /^[\$\@\%]/ } @EXPORT, @EXPORT_OK;

BEGIN {
    $Debug //= 0;
}

sub debug {
    # XXX attach debug flag to game object +/- other objects
    print @_, "\n" if $Debug;
}

sub debug_var {
    return unless $Debug;
    while (@_) {
    	my ($key, $val) = splice @_, 0, 2;
	debug sprintf "%-20s %s", $key, dstr $val;
    }
}

# XXX beef this up
#
#{
#
#my %used_index_name;
#
## $Index{GAME}{''} = 1; # next index
## $Index{GAME}{NUM_PLAYERS} = 0;
#
#sub _index_backend {
#    my ($pkg, $is_leaf, @iname) = @_;
#
#    @iname = map { uc } @iname;
#    my $full_name = join '_', @iname;
#
#    if ($used_index_name{$full_name}++) {
#	xconfess "index name $full_name has already been used\n";
#    }
#
#    my $r = \%Index;
#    while (@iname) {
#    	my $this_part = shift @iname;
#	if ($this_part !~ /^\w+\z/) {
#	    xconfess "invalid index name part ", dstr $this_part;
#	}
#
#	my $next_r = $r->{$this_part};
#
#	if (defined $next_r) {
#	    kkkkkkkk
#	    if (@iname) {
#
#
#	if (@iname) {
#	    # there's more, this isn't a leaf
#
#
#	    #
#
#	if (!defined $next_r) {
#
#
#
#	if (@iname || !$is_leaf) {
#
#
#}

# XXX sub-types handling:  when adding a field to an object, it's
# important not to clash with fields of your ancestors, but it doesn't
# matter if you clash with your siblings.  Right now all are disjoint,
# which wastes array space.  Eg it'd be nice to have:
#
#     object Foo,          fields fa = 0, fb = 1
#     object Bar @ISA Foo, fields bc = 2, bc = 3
#     object Baz @ISA Foo, fields zd = 2, ze = 3
#
# but now we have
#
#     object Foo,          fields fa = 0, fb = 1
#     object Bar @ISA Foo, fields bc = 2, bc = 3
#     object Baz @ISA Foo, fields zd = 4, ze = 5

sub add_array_index_type {
    @_ == 1 || badinvo;
    my ($itype) = map { uc } @_;

    if ($Index{$itype}) {
	xconfess "index type $itype already exists";
    }
    $Index{$itype} = [];
}

sub add_array_index {
    @_ == 2 || @_ == 3 || badinvo;
    my $itype = uc shift;
    my $iname = uc shift;
    my $pkg = shift || caller;

    my $r = $Index{$itype};

    $iname =~ tr/ +-/_/;

    if (!$r) {
	xconfess "invalid index type ", dstr $itype;
    }

    if (grep { $_ eq $iname } @$r) {
	xconfess "key $iname already exists in index for $itype";
    }

    push @$r, $iname;
    my $ix = $#$r;

    # XXX need exported name for index type, combine these subs somehow

    my $sub = "${itype}_${iname}";
    no strict 'refs';
    debug "create ${pkg}::${sub} -> $ix" if $Debug > 2;
    *{ "${pkg}::${sub}" } = sub () { $ix };
    push @{ "${pkg}::EXPORT_OK" }, $sub;
}

# This allows the $itype to already have been defined.

sub add_array_indices {
    @_ >= 2 || badinvo;
    my ($itype, @iname) = @_;

    add_array_index_type $itype
    	if !$Index{$itype};
    add_array_index $itype, $_, scalar caller for @iname;
}

sub eval_block (&) {
    return eval {
	local $SIG{__DIE__};
	$_[0]->()
    };
}

# http://en.wikipedia.org/wiki/Knapsack_problem
#
# A similar dynamic programming solution for the 0-1 knapsack problem also
# runs in pseudo-polynomial time. As above, let the costs be c1, ..., cn
# and the corresponding values v1, ..., vn. We wish to maximize total
# value subject to the constraint that total cost is less than C. Define a
# recursive function, A(i, j) to be the maximum value that can be attained
# with cost less than or equal to j using items up to i.
#
# We can define A(i,j) recursively as follows:
#
#     * A(0, j) = 0
#     * A(i, 0) = 0
#     * A(i, j) = A(i - 1, j) if ci > j
#     * A(i, j) = max(A(i - 1, j), vi + A(i - 1, j - ci)) if ci \u2264 j.
#
# The solution can then be found by calculating A(n, C). To do this
# efficiently we can use a table to store previous computations. This
# solution will therefore run in O(nC) time and O(nC) space, though with
# some slight modifications we can reduce the space complexity to O(C).

# External interface is:
#     ($total_cost, $total_value, @item)
#     	  = knapsack_0_1
#     	      $ref_to_list_of_items,
#     	      $code_ref_returning_cost_and_value_of_given_item,
#     	      $max_cost;
#
# When called recursively there are 2 additional args:
#
#     	      $max_item_list_index
#    	      $ref_to_cache

# XXX not sure I like the argument order

use constant KNAPSACK_DEBUG => 0;

sub knap_item_to_str {
    @_ == 2 || badinvo;
    my ($item, $cb) = @_;
    return join ":", $cb->($item);
}

sub knapsack_0_1_backend {
    @_ == 7 || badinvo;
    my ($ritem, $cb_item_to_cost_value, $max_cost, $cb_too_much, $tot_value,
    	    $max_i, $rcache) = @_;

    my $recurse = sub {
    	@_ == 3 || badinvo;
	return knapsack_0_1_backend(
		$ritem, $cb_item_to_cost_value, $_[0], $cb_too_much,
		$_[1], $_[2], $rcache);
    };

    my $debug_s =
	    sprintf "max_cost=%4.1f  max_i=%-3d  ritem=%s\n-> ",
		$max_cost,
		$max_i,
		join " ", map { knap_item_to_str $_, $cb_item_to_cost_value }
			    @{ $ritem }[0..$max_i]
	if KNAPSACK_DEBUG;
    print "on entry: $debug_s< from ", fileline(2), "\n" if KNAPSACK_DEBUG;

# XXX cb_too_much could rely on anything, not just these 2
#    if (my $r = $rcache->{$max_i}{$max_cost}) {
#    	print $debug_s, "memoized max_i=$max_i max_cost=$max_cost @$r\n"
#	    if KNAPSACK_DEBUG;
#	return @$r;
#    }

    $max_i    >= -1	or xconfess $max_i;
    # XXX no longer true since $cb_too_much might not test this
    #$max_cost >=  0	or xconfess $max_cost;

    if ($max_i == -1 || $max_cost <= 0) {
	print $debug_s, "zero\n"
	    if KNAPSACK_DEBUG;
    	return 0, 0;
    }

    my @r;
    my $this_item = $ritem->[$max_i];
    my ($this_cost, $this_value) = $cb_item_to_cost_value->($this_item);

    # XXX add $this_item at end?
    my $too_much = $cb_too_much->($this_cost, $max_cost, $this_value, $tot_value);
    if (KNAPSACK_DEBUG) {
	printf "too_much(this_cost=%4.1f, max_cost=%4.1f, this_value=%4.1f, tot_value=%4.1f) -> %d\n",
	    $this_cost, $max_cost, $this_value, $tot_value, $too_much;
    }

    if ($too_much) {
	# can't include this item, it costs too much
	print $debug_s, "too big\n"
	    if KNAPSACK_DEBUG;
	@r = $recurse->($max_cost, $tot_value, $max_i - 1);
    }
    else {
    	my $next_max_i = $max_i - 1;
    	print "recursing for index $next_max_i\n"
	    if KNAPSACK_DEBUG;
	my @without_this = $recurse->($max_cost,              $tot_value, $next_max_i);
	# XXX bug is here, $max_cost = 0, $this_cost = 2
	my @with_this    = $recurse->($max_cost - $this_cost, $tot_value + $this_value, $next_max_i);
	$with_this[0]   += $this_cost;
	$with_this[1]   += $this_value;
	my $keep         = ($with_this[1] >= $without_this[1]);
	push @with_this, $this_item;

	printf "%skeep=%1d this=%-8s val_without=%4.1f val_with=%4.1f\n",
	    	$debug_s,
		$keep,
    	    	knap_item_to_str($this_item, $cb_item_to_cost_value),
		$without_this[1],
		$with_this[1]
	    if KNAPSACK_DEBUG;
	@r = $keep ? @with_this : @without_this;
    }

    $rcache->{$max_i}{$max_cost} = \@r;
    return @r;
}

sub knapsack_0_1 {
    @_ == 3 || @_ == 4 || badinvo;
    my ($ritem, $cb_item_to_cost_value, $max_cost, $cb_too_much) = @_;

    if (KNAPSACK_DEBUG) {
	print  "=== top level\n";
	printf "  input max_cost=%4.1f  ritem=%s\n",
		$max_cost,
		join " ", map { knap_item_to_str $_, $cb_item_to_cost_value }
			    @{ $ritem };
	print data_dump \@_
	    if 0;
    }

    $cb_too_much ||= sub { $_[0] > $_[1] };
    my @r = knapsack_0_1_backend
		$ritem,
		$cb_item_to_cost_value,
		$max_cost,
		$cb_too_much,
		0,
		$#{ $ritem },
		{};

    if (KNAPSACK_DEBUG) {
	#print "result @r\n";
	print "result cost=$r[0] value=$r[1] ",
	     join(" ", map {
		 knap_item_to_str($_, $cb_item_to_cost_value) } @r[2..$#r]),
	    "\n";
    }

    return @r;
}

sub make_accessor_pkg {
    @_ >= 4 || badinvo;
    my $pkg  = shift;
    my $rw   = shift;
    my $rpi  = shift;	# access $self->[$rpi->[0]][$rpi->[1]]...[$index]
    @_ % 2 && badinvo;

    my @pi = $rpi ? @$rpi : ();
    while (@_) {
	my ($name, $index) = splice @_, 0, 2;
	my $sub = $rw
	    ? sub {
		@_ == 1 || @_ == 2 || badinvo;
		my $r = shift;
		$r = $r->[$_] for @pi;
		my $old = $r->[$index];
		$r->[$index] = shift if @_;
		return $old;
	    }
	    : sub {
	    	@_ == 1 || badinvo 1, "$name property is read-only";
		my $r = shift;
		$r = $r->[$_] for @pi;
		return $r->[$index];
	    };
	no strict 'refs';
	*{ "${pkg}::${name}" } = $sub;
    }
}

sub make_ro_accessor {
    return make_accessor_pkg scalar caller, 0, [], @_;
}

sub make_ro_accessor_multi {
    return make_accessor_pkg scalar caller, 0, @_;
}

sub make_rw_accessor {
    return make_accessor_pkg scalar caller, 1, [], @_;
}

sub same_referent {
    # 3-args used by overload.pm
    @_ == 2 || @_ == 3 || badinvo;

    return ref($_[0]) && ref($_[1]) && refaddr($_[0]) == refaddr($_[1]);
}

sub valid_ix {
    @_ == 2 || badinvo;
    my ($ix, $r) = @_;

    return @$r
	&& defined $ix
	&& looks_like_number($ix)
	&& $ix >= 0
    	&& $ix <= $#{ $r };
}

sub valid_ix_plus_1 {
    @_ == 2 || badinvo;
    my ($ix, $r) = @_;

    return looks_like_number($ix) ? valid_ix($ix + 1, $r) : 0;
}

1
