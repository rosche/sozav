package Game::Util;

use strict;

use base qw(Exporter);

use RS::Handy	qw(badinvo data_dump dstr fileline xconfess);
use Scalar::Util qw(looks_like_number refaddr);

use vars qw($VERSION @EXPORT @EXPORT_OK);

$VERSION = 'XXX';

BEGIN {
    @EXPORT = qw(
	$Debug
	add_array_index_type
	add_array_index
	add_array_indices
	debug
	debug_maybe
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

sub debug_maybe {
    @_ || badinvo;
    my $require_level = shift;
    return unless $Debug >= $require_level;
    # XXX attach debug flag to game object +/- other objects
    print @_, "\n";
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
#	my $this_part = shift @iname;
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
#     object Foo,          fields f1 = 0, f2 = 1
#     object Bar @ISA Foo, fields b1 = 2, b2 = 3
#     object Baz @ISA Foo, fields z1 = 2, z2 = 3
#
# but now we have
#
#     object Foo,          fields f1 = 0, f2 = 1
#     object Bar @ISA Foo, fields b1 = 2, b2 = 3
#     object Baz @ISA Foo, fields z1 = 4, z2 = 5

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
#	  = knapsack_0_1
#	      $ref_to_list_of_items,
#	      $code_ref_returning_cost_and_value_of_given_item,
#	      $max_cost;

use constant KNAPSACK_DEBUG => 0;

sub knap_item_to_str {
    @_ == 2 || badinvo;
    my ($item, $cb) = @_;
    return join ":", $cb->($item);
}

# XXX not sure I like the argument order

sub knapsack_0_1 {
    @_ == 3 || badinvo;
    my ($ritem, $cb_cost_value, $max_cost) = @_;

    if (KNAPSACK_DEBUG) {
	print  "=== top level\n";
	printf "  input max_cost=%4.1f  ritem=%s\n",
		$max_cost,
		join " ", map { knap_item_to_str $_, $cb_cost_value }
			    @{ $ritem };
	print data_dump \@_
	    if 0;
    }

    if ($max_cost <= 0) {
        return 0, 0;
    }

    # make arrays 1-based so 0 index can be used for leaf case
    my @cost  = (undef);
    my @value = (undef);
    for (@$ritem) {
        my @i = $cb_cost_value->($_);
        push @cost,  $i[0];
        push @value, $i[1];
    }

    # @m holds best answer:
    #   $m[$max_index][$max_cost] = [$cost, $value, list of indices];
    my @m;

    for my $wlim (0..$max_cost) {
        $m[0][$wlim] = [0, 0];
    }
    for my $i (0..$#cost) {
        $m[$i][0] = [0, 0];
    }
    print data_dump \@m
        if KNAPSACK_DEBUG && 0;

    for my $i (1..$#cost) {
        for my $wlim (1..$max_cost) {
            my $remaining_cost = $wlim - $cost[$i];
            printf "\$i=%3s \$wlim=%3s \$this_cost=%3s \$remaining=%3s prev cost=%3s ",
                    $i, $wlim, $cost[$i], $remaining_cost, $m[$i-1][$wlim][1]
                if KNAPSACK_DEBUG;

            if ($remaining_cost < 0) {
                print "too costly $cost[$i] > $wlim"
                    if KNAPSACK_DEBUG;
                $m[$i][$wlim] = [@{ $m[$i-1][$wlim] }];
                next;
            }

            my $new_cost  = $m[$i-1][$remaining_cost][0] + $cost[$i];
            my $new_value = $m[$i-1][$remaining_cost][1] + $value[$i];

            if ($m[$i-1][$wlim][1] >= $new_value) {
                print "not better $m[$i-1][$wlim][1] >= $new_value"
                    if KNAPSACK_DEBUG;
                $m[$i][$wlim] = [@{ $m[$i-1][$wlim] }];
                next;
            }

            print "take $m[$i-1][$wlim][1] < $new_value"
                if KNAPSACK_DEBUG;
            # add $i to index list
            $m[$i][$wlim] = [@{ $m[$i-1][$remaining_cost] }, $i];
            # set cost/value
            $m[$i][$wlim][0] = $new_cost;
            $m[$i][$wlim][1] = $new_value;
        }
        continue {
            print " m=@{ $m[$i][$wlim] }\n"
                if KNAPSACK_DEBUG;
        }
    }

    my ($total_cost, $total_value, @item_index) = @{ $m[-1][-1] };
    my @ret_item = map { $ritem->[$_-1] } @item_index;

    if (KNAPSACK_DEBUG) {
	#print "result @r\n";
	print "result cost=$total_cost/$max_cost value=$total_value/",
	    join(" ", map {
		 knap_item_to_str($_, $cb_cost_value) } @ret_item),
	    "\n";
    }

    return $total_cost, $total_value, @ret_item;
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
