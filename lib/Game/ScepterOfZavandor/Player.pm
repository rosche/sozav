# $Id: Player.pm,v 1.12 2008-08-01 13:50:49 roderick Exp $

use strict;

package Game::ScepterOfZavandor::Player;

use overload (
    '""' => "as_string",
    '<=>' => "spaceship",
);

use List::Util	qw(first sum);
use Game::Util  qw($Debug add_array_indices debug debug_var
		    make_ro_accessor make_rw_accessor);
use RS::Handy	qw(badinvo data_dump dstr xconfess);
use Scalar::Util qw(refaddr weaken);

use Game::ScepterOfZavandor::Item::Knowledge ();

use Game::ScepterOfZavandor::Constant qw(
    /^CHAR_/
    /^CUR_ENERGY_/
    /^DUST_DATA_/
    /^ENERGY_EST_/
    /^GEM_/
    /^KNOW_/
    $Base_gem_slots
    $Base_hand_limit
    @Character
    @Character_data
    $Concentrated_card_count
    $Concentrated_additional_dust
    @Current_energy
    @Dust_data
    @Energy_estimate
    @Gem
    @Gem_data
    @Knowledge
    @Knowledge_chip_cost
    @Knowledge_data
);

BEGIN {
    add_array_indices 'PLAYER', qw(
	GAME
	UI
	CHAR
	ITEM
	ENCHANTED_RUBY
	AUTO_ACTIVATE_GEMS
	SCORE_AT_TURN_START
	ADVANCED_KNOWLEDGE_THIS_TURN
    );
}

# - items are sub of item class which has default methods which do nothing
# - items are kept in lists by type
# - get_items method returns all items from all lists
# - when doing something iterate through items offering each of them the
#   opportunity to modify it
#     - need to know cost_mod on an item when bidding so you know how
#       high you can bid

sub new {
    @_ == 3 || badinvo;
    my ($class, $game, $ui) = @_;

    $ui or xconfess;

    my $self = bless [], $class;
    $self->[PLAYER_GAME] = $game;
    weaken $self->[PLAYER_GAME];
    $self->[PLAYER_UI  ] = $ui;
    $ui->a_player($self);
    $self->a_auto_activate_gems(1);

    return $self;
}

make_ro_accessor (
    a_game => PLAYER_GAME,
    a_ui   => PLAYER_UI,
);

make_rw_accessor (
    a_char                         => PLAYER_CHAR,
    a_enchanted_ruby               => PLAYER_ENCHANTED_RUBY,
    a_auto_activate_gems           => PLAYER_AUTO_ACTIVATE_GEMS,
    a_advanced_knowledge_this_turn => PLAYER_ADVANCED_KNOWLEDGE_THIS_TURN,
    a_score_at_turn_start          => PLAYER_SCORE_AT_TURN_START,
);

sub spaceship {
    @_ == 3 || badinvo;
    my ($a, $b) = @_;

    0
	or $a->a_char  <=> $b->a_char
    	or refaddr($a) <=> refaddr($b)
}

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

    my $k = Game::ScepterOfZavandor::Item::Knowledge->new($self, 0);
    $k->set_type($Character_data[$char][CHAR_DATA_KNOWLEDGE_TRACK]);
    $self->add_items($k);
    for (@Knowledge_chip_cost) {
	$self->add_items(Game::ScepterOfZavandor::Item::Knowledge->new($self, $_));
    }

    debug "$Character[$char] items ", join " ", $self->items;
}

sub as_string {
    @_ == 3 || badinvo;
    my $self = shift;
    return $self->name;
}

#------------------------------------------------------------------------------

# XXX standard list accessors?

sub add_items {
    @_ || badinvo;
    my ($self, @item) = @_;

    for (@item) {
    	$_ or xconfess;
	debug "$Character[$self->[PLAYER_CHAR]] add item $_";
	push @{ $self->[PLAYER_ITEM] }, $_;
    }
}

sub items {
    @_ == 1 || badinvo;

    return @{ $_[0]->[PLAYER_ITEM] };
}

sub remove_items {
    my $self = shift;
    my (@remove_item) = @_;

    debug "remove @remove_item";

    my @old = $self->items;
    my @new;
    for my $old (@old) {
	push @new, $old
	    unless grep { $old == $_ } @remove_item;
    }

    if (@new + @remove_item != @old) {
	xconfess "remove_items missing something",
	    "\n",
	    "(new=", 0+@new, " old=", 0+@old, ")\n",
	    "new: @new\n",
	    "old: @old\n";
    }

    for (@remove_item) {
	debug "$Character[$self->[PLAYER_CHAR]] remove item $_";
	$_->use_up;
    }

    $self->[PLAYER_ITEM] = \@new;
}

#------------------------------------------------------------------------------

sub active_gems {
    @_ == 1 || badinvo;
    my $self = shift;
    return grep { $_->is_active } $self->gems;
}

sub auctionables {
    @_ == 1 || badinvo;
    my $self = shift;
    return grep { $_->is_auctionable } $self->items;
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

sub gems {
    @_ == 1 || badinvo;
    my $self = shift;
    return grep { $_->is_gem } $self->items;
}

sub hand_limit {
    @_ == 1 || badinvo;
    my $self = shift;
    return sum $Base_hand_limit,
		map { $_->a_hand_limit_modifier } $self->items;
}

sub inactive_gems {
    @_ == 1 || badinvo;
    my $self = shift;
    return grep { !$_->is_active } $self->gems;
}

sub knowledge_chips {
    @_ == 1 || badinvo;
    my $self = shift;
    return grep { $_->is_knowledge } $self->items;
}

sub knowledge_chips_advancable {
    @_ == 1 || badinvo;
    my $self = shift;

    return grep { $_->is_advancable } $self->knowledge_chips;
}

sub knowledge_chips_unbought {
    @_ == 1 || badinvo;
    my $self = shift;

    return grep { $_->is_unbought } $self->knowledge_chips;
}

sub name {
    @_ == 1 || badinvo;
    return $Character[$_[0]->[PLAYER_CHAR]];
}

sub num_gem_slots {
    @_ == 1 || badinvo;
    my $self = shift;
    return sum $Base_gem_slots,
		map { $_->a_gem_slots } $self->items;
}

sub num_free_gem_slots {
    @_ == 1 || badinvo;
    my $self = shift;
    my $n = $self->num_gem_slots - $self->active_gems;
    $n >= 0 or xconfess;
    return $n;
}

sub score {
    @_ == 1 || badinvo;
    my $self = shift;
    return sum map { $_->vp } $self->items;
}

sub score_from_gems {
    @_ == 1 || badinvo;
    my $self = shift;
    return sum map { $_->vp } $self->gems;
}

sub turn_order_card {
    @_ == 1 || badinvo;
    my $self = shift;
    my @t = grep { $_->is_turnorder } $self->items;
    @t > 1 and xconfess;
    return $t[0];
}

sub user_turn_order {
    @_ == 1 || badinvo;
    my $self = shift;

    return $self->turn_order_card->name;
}

#------------------------------------------------------------------------------

sub advance_knowledge {
    @_ == 3 || badinvo;
    my $self  = shift;
    my $ktype = shift;
    my $free  = shift;	# true if from an artifact or at startup or such

    if (!$free && $self->a_advanced_knowledge_this_turn) {
	die "already advanced knowledge this turn\n";
    }

    my $cost = 0;
    my $k = first { $_->ktype_is($ktype) } $self->knowledge_chips;
    if (!$k) {
	$k = first { $_->is_bought && $_->is_unassigned } $self->knowledge_chips
	    or die "not on $Knowledge[$ktype] knowledge track and no unassigned chips\n";
	# XXX
	$cost = $Knowledge_data[$ktype][KNOW_DATA_LEVEL_COST][0];
    }
    else {
	$k->maxed_out
	    and die "$k already maxed out\n";
	$cost = $k->next_level_cost;
    }

    if ($free) {
	$cost = 0;
    }

    if ($cost > $self->current_energy_liquid) {
	die "not enough liquid energy (need $cost)\n";
    }

    $self->pay_energy($cost)
	if $cost;
    if ($k->is_unassigned) {
	$k->set_type($ktype);
    }
    else {
	$k->advance;
    }
    $self->a_advanced_knowledge_this_turn(1);
    $self->a_game->info($self->name, " advanced ", $k->name, " to level ", $k->user_level);
}

sub auctionable_cost_mod {
    @_ == 2 || badinvo;
    my $self        = shift;
    my $auc_or_type = shift;

    my $auc_type = ref $auc_or_type
			? $auc_or_type->a_auc_type
			: $auc_or_type;

    my $cost_mod = sum map { $_->cost_mod_on_auc_type($auc_type) } $self->items;
    #debug "$cost_mod cost_mod on $auc_or_type";
    return $cost_mod
}

sub auto_activate_gems {
    @_ == 1 || badinvo;
    my $self = shift;

    my $n_slots  = $self->num_gem_slots;
    my @gem      = sort { $b <=> $a } $self->gems;

    return unless @gem;

    my $first_active = $#gem - $n_slots + 1;
    $first_active = 0 if $first_active < 0;

    my $needed_change = 0;
    for my $i (0..$#gem) {
    	my $g = $gem[$i];
	if ($i >= $first_active) {
	    if (!$g->is_active) {
		$needed_change = 1;
		$g->activate
		    if $self->a_auto_activate_gems;
	    }
	}
	else {
	    if ($g->is_active) {
		$needed_change = 1;
		$g->deactivate
		    if $self->a_auto_activate_gems;
	    }
	}
    }

    if ($needed_change && !$self->a_auto_activate_gems) {
    	$self->a_ui->out("\n$self: ");
    	$self->a_ui->out_notice("You aren't using your best gems.\n");
    }
}

sub buy_auctionable {
    @_ == 3 || badinvo;
    my $self  = shift;
    my $auc   = shift;
    my $price = shift;

    if ($auc->own_only_one
	    && grep { $_->a_auc_type == $auc->a_auc_type }
		    $self->auctionables) {
    	die "you can only own one $auc\n";
    }

    if ($price < (my $cost = $auc->get_min_bid)) {
	xconfess "$price < $cost";
    }

    my $cost_mod = $self->auctionable_cost_mod($auc);
    my $net = $price + $cost_mod;
    my $cash = $self->current_energy_liquid;
    $cash >= $net
	or die "not enough liquid cash, $cash < $price + $cost_mod\n";
    # XXX using active gems

    $self->pay_energy($net);
    $self->a_game->auctionable_sold($auc);
    # XXX weaken
    $auc->a_player($self);
    $self->add_items($auc, $auc->free_items($self->a_game));
    $auc->bought;
    $self->a_game->info("$self bought $auc for $net energy");
    $self->auto_activate_gems;
}

sub buy_knowledge_chip {
    @_ == 3 || badinvo;
    my $self  = shift;
    my $kchip = shift;	# will auto-select if not given
    my $free  = shift;	# true if from an artifact or at startup or such

    if (!$kchip) {
	my @kc = sort { $a->a_cost <=> $b->a_cost}
		    $self->knowledge_chips_unbought
	    or die "no unbought knowledge chips\n";
	$kchip = $kc[$free ? -1 : 0];
    }

    my $cost = $free ? 0 : $kchip->a_cost;
    if ($cost > $self->current_energy_liquid) {
	die "not enough liquid energy (need $cost)\n";
    }

    $self->pay_energy($cost)
	if !$free;
    $self->a_game->info($self->name, " ",
	    $free ? "acquired" : "bought",
	    " knowledge chip ", $kchip->a_cost);
    $kchip->bought;
}

sub current_energy {
    @_ == 1 || badinvo;
    my $self = shift;

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

sub enchant_gem {
    @_ == 2 || badinvo;
    my $self = shift;
    my ($gtype) = @_;

    if (!$self->can_enchant_gem_type_right_now($gtype)) {
	# XXY ungrammatical
	die "not allowed to enchant $Gem[$gtype] right now\n";
    }

    my $cost = $self->gem_cost($gtype);
    my $cash = $self->current_energy_liquid;
    if ($cost > $cash) {
    	die "not enough liquid cash ($cost > $cash)\n";
    }

    $self->pay_energy($cost);

    my $g = Game::ScepterOfZavandor::Item::Gem->new($self, $gtype);
    $self->a_game->info("$self enchanted a $g"); # XXX grammar
    $self->add_items($g);

    if ($gtype == GEM_RUBY) {
	$self->a_enchanted_ruby(1);
    }

    return $g;
}

sub can_enchant_gem_type_right_now {
    @_ == 2 || badinvo;
    my $self = shift;
    my $gtype = shift;

    defined $Gem[$gtype] or xconfess dstr $gtype;

    if ($gtype == GEM_OPAL || $gtype == GEM_SAPPHIRE) {
	return 1;
    }

    if (my $limit = $Gem_data[$gtype][GEM_DATA_LIMIT]) {
    	debug "gtype $gtype limit $limit";
	my @g = grep { $_->a_gem_type == $gtype } $self->gems;
	if (@g > $limit) {
	    xconfess 0+@g, " > $limit";
	}
	if (@g == $limit) {
	    die "can't enchant another $Gem[$gtype], at limit\n";
	    return 0;
	}
    }

    if (first { $_->allows_player_to_enchant_gem_type($gtype) } $self->items) {
	return 1;
    }

    # Druids can enchant 1 ruby at knowledge of fire level 3.

    if ($gtype == GEM_RUBY
    	    && $self->a_char == CHAR_DRUID
    	    && grep { $_->ktype_is(KNOW_FIRE) && $_->a_level >= 2 }
		    $self->knowledge_chips) {
    	if ($self->a_enchanted_ruby) {
	    die "druid already enchanted special level 3 ruby\n";
	}
	return 1;
    }

    return 0;
}

sub destroy_active_gem {
    @_ == 1 || badinvo;
    my $self = shift;

    # XXX prompt user about which to destroy
    my @g = sort { $a <=> $b } $self->active_gems;

    if (!@g) {
    	$self->a_game->info($self->name, " doesn't have any active gems to destroy");
	return;
    }

    $self->a_game->info($self->name, " destroys $g[0]");
    $self->remove_items($g[0]);
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

    my $tot_discarded_energy = $self->spend(@rm);

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
    	    	    	$self, $dust_value);
    	    $new_hc += $dust->a_hand_count;
	    $self->add_items($dust);
	}
    }

    $new_hc == $hl or xconfess "$new_hc != $hl";

    if ($tot_discarded_energy) {
	$self->a_game->info($self->name, " lost $tot_discarded_energy energy to hand limit");
    }
}

sub energy_backend {
    @_ == 2 || badinvo;
    my $self   = shift;
    my $action = shift;

    my $is_produce  = ($action eq 'produce' );
    my $is_estimate = ($action eq 'estimate');
    $is_produce || $is_estimate
	or xconfess dstr $action;

    my @ee = (0) x @Energy_estimate;
    my $ee_add = sub {
	for (0..$#_) {
	    $ee[$_] += $_[$_];
	}
    };
    my $ee_add_constant = sub {
	my $n = shift;
	my @e = ();
	$e[ENERGY_EST_MIN] = $n;
	$e[ENERGY_EST_AVG] = $n;
	$e[ENERGY_EST_MAX] = $n;
	$ee_add->(@e);
    };

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
	    if ($is_produce) {
		$self->add_items($i->produce_energy);
	    }
	    else {
		$ee_add->($i->produce_energy_estimate);
	    }
	}
    }
    $active_gems <= $self->num_gem_slots or xconfess;

    # opals

    if (my $ro = delete $gem{+GEM_OPAL}) {
    	debug 0+@$ro, " opals" if $Debug > 1;
	my $e = Game::ScepterOfZavandor::Item::Energy::Dust
    	    	    ->opal_count_to_energy_value(scalar @$ro);
    	if ($is_produce) {
	    $self->add_items(
		Game::ScepterOfZavandor::Item::Energy::Dust->make_dust($self, $e));
    	}
	else {
	    $ee_add_constant->($e);
	}
    }

    # other gems

    for my $gtype (keys %gem) {
	my @g = @{ $gem{$gtype} };
	while (@g >= $Concentrated_card_count) {
	    splice @g, 0, $Concentrated_card_count;
	    if ($is_produce) {
		$self->add_items(
		    Game::ScepterOfZavandor::Item::Energy::Concentrated->new(
			$self, $gtype),
		    Game::ScepterOfZavandor::Item::Energy::Dust->make_dust(
			$self, $Concentrated_additional_dust));
    	    }
	    else {
		$ee_add_constant->($Gem_data[$gtype][GEM_DATA_CONCENTRATED]);
		$ee_add_constant->($Concentrated_additional_dust);
	    }
    	}
	for (@g) {
	    if ($is_produce) {
		$self->add_items($_->produce_energy);
	    }
	    else {
		$ee_add->($_->produce_energy_estimate);
	    }
	}
    }

    if ($is_estimate) {
	return @ee;
    }
}

sub income_estimate {
    @_ == 1 || badinvo;
    my $self = shift;

    return $self->energy_backend('estimate');
}

sub gain_energy {
    @_ == 1 || badinvo;
    my $self = shift;

    return $self->energy_backend('produce');
}

sub gem_cost {
    my $self = shift;
    my $gtype = shift;

    my $cost = my $orig_cost = $Gem_data[$gtype][GEM_DATA_COST];
    for ($self->knowledge_chips) {
	$cost = $_->modify_gem_cost($cost);
    }
    if ($cost != $orig_cost) {
	debug "gem cost modified $orig_cost -> $cost"
	    if $Debug > 2;
    }
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

    $tot > 0 or xconfess;

    # XXX proper algorithm for choosing what to pay with, 0-1 knapsack
    # problem?

    my @cash = ();
    # sorting by ratio would do this effectively, as inactive gems have
    # infinite ratio
    push @cash, sort { $a <=> $b } grep { $_->is_energy } $self->items;
    push @cash, sort { $b <=> $a } $self->inactive_gems;

    my @to_use;
    for my $i (@cash) {
	my $v = $i->energy;
	push @to_use, $i;
	$tot -= $v;
	last if $tot <= 0;
    }

    if ($tot > 0) {
    	xconfess "short by $tot energy";
    }

    # XXX removing an inactive gem causes it to add the dust back in,
    # but I'm spending that energy, I don't want it back, need an arg or
    # another function to deal with this

    $self->spend(@to_use);
    $self->add_items(
	    Game::ScepterOfZavandor::Item::Energy::Dust->make_dust($self, 0 - $tot))
	if $tot < 0;

    # consolidate dust so your hand count is accurate

    # XXX inefficient

    if (my @dust = grep { $_->is_energy_dust } $self->items) {
	my $e = sum map { $_->energy } @dust;
	$self->remove_items(@dust);
	$self->add_items(
	    Game::ScepterOfZavandor::Item::Energy::Dust->make_dust($self, $e));
    }
}

# Take some things out of your inventory.  Return the amount of energy
# which was in them.

sub spend {
    @_ > 1 || badinvo;
    my $self = shift;
    my @i = @_;

    my $tot_energy = sum map { $_->energy } @i;
    $self->remove_items(@i);
    return $tot_energy;
}

#------------------------------------------------------------------------------

sub actions {
    @_ == 1 || badinvo;
    my $self = shift;

    $self->a_advanced_knowledge_this_turn(0);
    $self->a_ui->start_actions;
    while ($self->a_ui->one_action) {
	;
    }
}

1

__END__

- method ->can_produce_card for 9 sages
