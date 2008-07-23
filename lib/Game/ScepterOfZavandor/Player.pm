# $Id: Player.pm,v 1.3 2008-07-23 12:05:24 roderick Exp $

use strict;

package Game::ScepterOfZavandor::Player;

use List::Util	qw(sum);
use Game::Util  qw($Debug add_array_indices debug debug_var
		    make_ro_accessor make_rw_accessor);
use RS::Handy	qw(badinvo data_dump dstr xcroak);
use Scalar::Util qw(refaddr);

use Game::ScepterOfZavandor::Constant qw(
    /^CHAR_/
    /^CUR_ENERGY_/
    /^GEM_/
    /^DUST_DATA_/
    $Base_gem_slots
    $Base_hand_limit
    @Character
    @Character_data
    $Concentrated_card_count
    $Concentrated_additional_dust
    @Current_energy
    @Dust_data
    @Gem
    @Gem_data
);

BEGIN {
    add_array_indices 'PLAYER', qw(GAME UI CHAR ITEM);
}

# - items are sub of item class which has default methods which do nothing
# - items are kept in lists by type
# - get_items method returns all items from all lists
# - when doing something iterate through items offering each of them the
#   opportunity to modify it
#     - need to know discount on an item when bidding so you know how
#       high you can bid

sub new {
    @_ == 3 || badinvo;
    my ($class, $game, $ui) = @_;

    $ui or die;

    my $self = bless [], $class;
    $self->[PLAYER_GAME] = $game;
    $self->[PLAYER_UI  ] = $ui;
    $ui->a_player($self); # XXX circular reference

    return $self;
}

make_ro_accessor (
    a_game => PLAYER_GAME,
    a_ui   => PLAYER_UI,
);

make_rw_accessor (
    a_char => PLAYER_CHAR,
);

sub init {
    @_ == 2 || badinvo;
    my ($self, $char) = @_;

    $self->a_char($char);
    $self->[PLAYER_ITEM] = [];

    $self->add_items(
    	$Character_data[$char][CHAR_DATA_START_ITEMS]->($self));
    for ($self->gems) {
	$_->activate;
    }

    debug "$Character[$char] items ", join " ", $self->items;
}

#------------------------------------------------------------------------------

# XXX standard list accessors?

sub add_items {
    @_ || badinvo;
    my ($self, @item) = @_;

    for (@item) {
    	$_ or die;
	debug "$Character[$self->[PLAYER_CHAR]] add item $_";
	push @{ $self->[PLAYER_ITEM] }, $_;
    }
}

sub items {
    @_ == 1 || badinvo;

    return @{ $_[0]->[PLAYER_ITEM] };
}

# This returns items which it adds as a result of the discards -- if you
# discard gems you get dust.

sub remove_items {
    @_ || badinvo;
    my ($self, @remove_item) = @_;

    debug "remove @remove_item";

    my @old = $self->items;
    my @new;
    for my $old ($self->items) {
	push @new, $old
	    unless grep { refaddr($old) == refaddr($_) } @remove_item;
    }

    if (@new + @remove_item != @old) {
	die "remove_items missing something",
	    "\n",
	    "(new=", 0+@new, " old=", 0+@old, ")\n",
	    "new: @new\n",
	    "old: @old\n";
    }

    my @xxx;
    for (@remove_item) {
	debug "$Character[$self->[PLAYER_CHAR]] remove item $_";
	# XXX dust added here is lost because \@new will be replaced
	push @xxx, $_->use_up;
    }

    $self->[PLAYER_ITEM] = \@new;
    return @xxx;
}

#------------------------------------------------------------------------------

sub active_gems {
    @_ == 1 || badinvo;
    my $self = shift;
    return grep { $_->is_active } $self->gems;
}

sub name {
    @_ == 1 || badinvo;

    return $Character[$_->[PLAYER_CHAR]];
}

sub gems {
    @_ == 1 || badinvo;
    my $self = shift;
    return grep { $_->is_gem } $self->items;
}

sub current_energy {
    @_ == 1 || badinvo;
    my $self = shift;

    # unused gems

    my @e = (0) x @Current_energy;

    for my $i ($self->items) {
	my $this_e = $i->energy;
	next unless $this_e;

    	$e[CUR_ENERGY_TOTAL] += $this_e;
	if ($i->is_gem && $i->is_active) {
	    $e[CUR_ENERGY_ACTIVE_GEMS] += $this_e;
	}
	else {
	    $e[CUR_ENERGY_LIQUID] += $this_e;
	    if ($i->is_gem) {
		$e[CUR_ENERGY_INACTIVE_GEMS] += $this_e;
	    }
	    else {
		$e[CUR_ENERGY_CARDS_DUST] += $this_e;
	    }
	}
    }

    return @e;
}

sub current_energy_liquid {
    @_ == 1 || badinvo;
    my $self = shift;
    return ($self->current_energy)[CUR_ENERGY_LIQUID];
}

sub current_hand_count {
    @_ == 1 || badinvo;
    my $self = shift;
    return sum map { $_->a_hand_count } $self->items;
}

sub hand_limit {
    @_ == 1 || badinvo;
    my $self = shift;
    return sum $Base_hand_limit,
		map { $_->a_hand_limit_modifier } $self->items;
}

sub num_gem_slots {
    @_ == 1 || badinvo;
    my $self = shift;
    return sum $Base_gem_slots,
		map { $_->a_gem_slots } $self->items;
}

#------------------------------------------------------------------------------

sub auto_activate_gems {
    @_ == 1 || badinvo;
    my $self = shift;

    my $n_slots  = $self->num_gem_slots;
    my @gem      = sort { $a <=> $b } $self->gems;

    return unless @gem;

    my $first_active = $#gem - $n_slots + 1;
    $first_active = 0 if $first_active < 0;

    for my $i (0..$#gem) {
    	my $g = $gem[$i];
	if ($i >= $first_active) {
	    $g->activate;
	}
	else {
	    $g->deactivate;
	}
    }
}

sub enchant_gem {
    @_ == 2 || badinvo;
    my $self = shift;
    my ($gtype) = @_;

    if (!$self->can_enchant_gem_type($gtype)) {
	# XXX ungrammatical
	die "not allowed to enchant $Gem[$gtype]";
    }

    my $cost = $self->gem_cost($gtype);
    my $cash = $self->current_energy_liquid;
    if ($cost > $cash) {
    	die "not enough liquid cash";
    }

    my $g = Game::ScepterOfZavandor::Item::Gem->new($gtype, $self);
    $self->pay_energy($cost);
    $self->add_items($g);

    return $g;
}

sub can_enchant_gem_type {
    @_ == 2 || badinvo;
    my $self = shift;
    my $gtype = shift;

    # XXX ask the items if the player can make a gem type?  could have a
    # standard item which gives you opal + sapphire, or retain hardcoding
    # here

    if ($gtype == GEM_OPAL || $gtype == GEM_SAPPHIRE) {
	return 1;
    }

    # XXX emerald
    # XXX diamond
    # XXX level 3 druid ruby
    # XXX ruby

    return 0;
}

sub enforce_hand_limit {
    @_ == 1 || badinvo;
    my $self = shift;

    my $hc = $self->current_hand_count;
    my $hl = $self->hand_limit;
    return if $hc <= $hl;

    # XXX This sorts poor ratio items back first, but that isn't correct.
    # This is another knapsack problem.
    #
    # XXX greedy approximation
    #
    # XXX one way this fails:  You can trade 5 2-dust chits (hand limit
    # 5) for 1 10-dust chit (hand limit 3), but this doesn't do that.

    my @rm;
    my $new_hc = 0;
    for my $i (sort { $b <=> $a } grep { $_->a_hand_count > 0 } $self->items) {
	my $this_hc = $i->a_hand_count;
	if ($new_hc + $this_hc <= $hl) {
	    $new_hc += $this_hc;
	}
	else {
	    push @rm, $i;
	}
    }

    my $tot_discarded_energy = sum map { $_->a_value } @rm;
    $self->remove_items(@rm);

    # Add in as much dust as possible, starting with most efficient forms.

    for my $di (0..$#Dust_data) {
    	my $dust_value      = $Dust_data[$di][DUST_DATA_VALUE];
    	my $dust_hand_count = $Dust_data[$di][DUST_DATA_HAND_COUNT];
	if ($Debug > 3) {
	    debug "trying to re-add dust";
	    debug_var (
		new_hc          => $new_hc,
		tot_discarded   => $tot_discarded_energy,
		dust_value      => $dust_value,
		dust_hand_count => $dust_hand_count,
	    );
	}
	while ($tot_discarded_energy >= $dust_value
    	    	&& $new_hc + $dust_hand_count <= $hl) {
	    $tot_discarded_energy -= $dust_value;
	    my $dust = Game::ScepterOfZavandor::Item::Energy::Dust->new(
    	    	    	$dust_value);
    	    $new_hc += $dust->a_hand_count;
	    $self->add_items($dust);
	}
    }

    $new_hc == $hl or die "$new_hc != $hl";

    # XXX info output
}

sub gain_energy {
    @_ == 1 || badinvo;
    my $self = shift;

    # gain energy from non-gems, save gems to process below

    my $active_gems = 0;
    my %gem;
    for my $i ($self->items) {
    	if ($i->is_gem) {
	    if ($i->is_active) {
		push @{ $gem{$i->a_gem_type} }, $i;
		$active_gems++;
	    }
	}
	else {
	    $self->add_items($i->produce_energy);
	}
    }
    $active_gems <= $self->num_gem_slots or die;

    # opals

    if (my $ro = delete $gem{+GEM_OPAL}) {
    	debug 0+@$ro, " opals" if $Debug > 1;
	$self->add_items(
	    Game::ScepterOfZavandor::Item::Energy::Dust->make_dust_from_opals(
	    	scalar @$ro));
    }

    # other gems

    for my $gtype (keys %gem) {
	my @g = @{ $gem{$gtype} };
	while (@g >= $Concentrated_card_count) {
	    splice @g, 0, $Concentrated_card_count;
	    $self->add_items(
		Game::ScepterOfZavandor::Item::Energy::Concentrated->new(
    	    	    $gtype),
		Game::ScepterOfZavandor::Item::Energy::Dust->make_dust(
    	    	    $Concentrated_additional_dust));
    	}
	$self->add_items(map { $_->produce_energy } @g);
    }
}

sub gem_cost {
    my $self = shift;
    my $gtype = shift;

    my $cost = $Gem_data[$gtype][GEM_DATA_COST];
    # XXX knowledge of gems
    return $cost;
}

sub gem_value {
    @_ == 2 || badinvo;
    my $self = shift;
    my $gtype_or_ref = shift;

    my $gtype = ref $gtype_or_ref
		    ? $gtype_or_ref->a_gem_type
		    : $gtype_or_ref;
    my $cost = $self->gem_cost($gtype);
    return int($cost / 2);
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


#sub fill_hand_limit {
#    @_ == 3 || badinvo;
#    my $self = shift;
#    my ($max_i, $max_hand_limit) = @_;
#
#    if ($max_i == 0 || $max_hand_limit == 0) {
#	return xxx;
#    }

sub pay_energy {
    @_ == 2 || badinvo;
    my $self = shift;
    my $tot  = shift;

    # XXX allow UI to say what to pay with, on general pricinple and
    # more realistically because you might want to sell gems early
    # knowing you'll be going up the gem track

    $tot > 0 or die;

    # XXX proper algorithm for choosing what to pay with, 0-1 knapsack
    # problem?

    my @cash = ();
    # sorting by ratio would do this effectively, as inactive gems have
    # infinite ratio
    push @cash, sort { $a <=> $b } grep {  $_->is_energy } $self->items;
    push @cash, sort { $a <=> $b } grep { !$_->is_active } $self->gems;

    my @to_use;
    for my $i (@cash) {
	my $v = $i->energy;
	push @to_use, $i;
print "value $v from $i\n";
	$tot -= $v;
	last if $tot <= 0;
    }

    if ($tot > 0) {
    	die "short by $tot energy";
    }

    # XXX removing an inactive gem causes it to add the dust back in,
    # but I'm spending that energy, I don't want it back, need an arg or
    # another function to deal with this

    $self->remove_items(@to_use);
    $self->add_items(
	    Game::ScepterOfZavandor::Item::Energy::Dust->make_dust(0 - $tot))
	if $tot < 0;
}

# This is called automatically from $gem->use_up, which is called by
# ->remove_items.  You don't want to call it by hand.

sub sell_gem {
    @_ == 2 || badinvo;
    my $self = shift;
    my $gem  = shift;

    my $value = $self->gem_value($gem);
    $value > 0 or die $value;

    my @dust = Game::ScepterOfZavandor::Item::Energy::Dust->make_dust($value);
    $self->add_items(@dust);
    return @dust;
}

#------------------------------------------------------------------------------

sub actions {
    @_ == 1 || badinvo;
    my $self = shift;

    while ($self->a_ui->one_action) {
	;
    }
}

1

__END__

- method ->can_produce_card for 9 sages
