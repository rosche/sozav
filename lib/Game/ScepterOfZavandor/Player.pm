# $Id: Player.pm,v 1.18 2012-04-28 20:02:27 roderick Exp $

use strict;

package Game::ScepterOfZavandor::Player;

use overload (
    '""' => "as_string",
    '<=>' => "spaceship",
);

use List::Util		qw(first sum);
use Game::Util  	qw($Debug debug_var add_array_indices debug debug_var
			    knapsack_0_1 make_ro_accessor make_rw_accessor);
use RS::Handy		qw(badinvo data_dump dstr xconfess);
use Scalar::Util	qw(refaddr weaken);
use Set::Scalar	 	  ();

use Game::ScepterOfZavandor::Item::Knowledge ();

use Game::ScepterOfZavandor::Constant qw(
    /^CHAR_/
    /^CUR_ENERGY_/
    /^DUST_DATA_/
    /^ENERGY_EST_/
    /^GEM_/
    /^KNOW_/
    /^NOTE_/
    /^OPT_/
    $Base_gem_slots
    $Base_hand_limit
    @Character
    @Character_data
    $Concentrated_card_count
    $Concentrated_additional_dust
    @Current_energy
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
	BOUGHT_RUBY
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
    a_bought_ruby                  => PLAYER_BOUGHT_RUBY,
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
}

sub init_items {
    @_ == 1 || badinvo;
    my ($self) = @_;

    my $char = $self->a_char;
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
	# XXX $self->a_game->note_to_players
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

    # XXX include bought but uncommitted chips?
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

    my $cle = $self->current_energy_liquid;
    if ($cost > $cle) {
	die "not enough liquid energy (need $cost, have $cle)\n";
    }

    $self->pay_energy($cost)
	if $cost;
    if ($k->is_unassigned) {
	$k->set_type($ktype);
    }
    else {
	$k->advance;
    }
    $self->a_advanced_knowledge_this_turn(1)
	if !$free;
    $self->a_game->note_to_players(NOTE_KNOWLEDGE_ADVANCE, $self, $k, $cost);
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

    my (@activate, @deactivate);
    for my $i (0..$#gem) {
    	my $g = $gem[$i];
	if ($i >= $first_active) {
	    if (!$g->is_active) {
	    	push @activate, $g;
	    }
	}
	else {
	    if ($g->is_active) {
	    	push @deactivate, $g;
	    }
	}
    }


    if (!@activate && !@deactivate) {
	return;
    }

    if (!$self->a_auto_activate_gems) {
    	$self->a_ui->ui_note(NOTE_NOT_USING_BEST_GEMS,
				\@activate, \@deactivate);
    }
    else {
    	$_->deactivate for @deactivate;
	$_->activate   for @activate;
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

    if ($price < (my $cost = $auc->a_data_min_bid)) {
    	die "bid too low (minimum $cost, bid $price)\n";
    }

    my $cost_mod = $self->auctionable_cost_mod($auc);
    my $net = $price + $cost_mod;
    my $cash = $self->current_energy_liquid;
    # XXX need to be able to sell gems here
    # XXX implement the Curse of the 9 Sages
    $cash >= $net
	or die "not enough liquid cash, need $price + $cost_mod, have $cash\n";

    $self->pay_energy($net);
    $self->a_game->auctionable_sold($auc);
    $auc->a_player($self);
    $self->add_items($auc, $auc->free_items($self->a_game));
    $auc->bought;
    $self->a_game->note_to_players(NOTE_ITEM_GOT, $self, $auc, $net);
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
    my $cle = $self->current_energy_liquid;
    if ($cost > $cle) {
	die "not enough liquid energy (need $cost, have $cle)\n";
    }

    $self->pay_energy($cost)
	if $cost;
    $self->a_game->note_to_players(NOTE_ITEM_GOT, $self, $kchip, $cost);
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

sub buy_gem {
    @_ == 2 || badinvo;
    my $self = shift;
    my ($gtype) = @_;

    if (!$self->can_buy_gem_type_right_now($gtype)) {
	# XXY ungrammatical
	# XXX not informative -- much nicer to explain why
	die "not allowed to buy $Gem[$gtype] right now\n";
    }

    my $cost = $self->gem_cost($gtype);
    my $cash = $self->current_energy_liquid;
    if ($cost > $cash) {
    	die "not enough liquid cash (need $cost, have $cash)\n";
    }

    $self->pay_energy($cost);

    my $g = Game::ScepterOfZavandor::Item::Gem->new($self, $gtype);
    $self->a_game->note_to_players(NOTE_ITEM_GOT, $self, $g, $cost);
    $self->add_items($g);

    if ($gtype == GEM_RUBY) {
	$self->a_bought_ruby(1);
    }

    return $g;
}

sub can_buy_gem_backend {
    @_ == 3 || badinvo;
    my $self      = shift;
    my $gtype     = shift;
    my $right_now = shift;

    defined $Gem[$gtype] or xconfess dstr $gtype;

    if ($gtype == GEM_OPAL || $gtype == GEM_SAPPHIRE) {
	return 1;
    }

    if ($right_now && (my $limit = $Gem_data[$gtype][GEM_DATA_LIMIT])) {
    	debug "gtype $gtype limit $limit";
	my @g = grep { $_->a_gem_type == $gtype } $self->gems;
	if (@g > $limit) {
	    xconfess 0+@g, " > $limit";
	}
	if (@g == $limit) {
	    # XXX message for user
	    #die "can't buy another $Gem[$gtype], at limit\n";
	    return 0;
	}
    }

    if (first { $_->allows_player_to_buy_gem_type($gtype) } $self->items) {
	return 1;
    }

    # Druids can buy 1 ruby at knowledge of fire level 3.

    my $allow_level_3_ruby
	= $self->a_game->option(OPT_ANYBODY_LEVEL_3_RUBY)
	    || ($self->a_game->option(OPT_DRUID_LEVEL_3_RUBY)
		    && $self->a_char == CHAR_DRUID);
    if ($gtype == GEM_RUBY
    	    && $allow_level_3_ruby
    	    && grep { $_->ktype_is(KNOW_FIRE) && $_->a_level >= 2 }
		    $self->knowledge_chips) {
    	if ($right_now && $self->a_bought_ruby) {
	    # XXX message for user
	    #die "already bought special fire level 3 ruby\n";
	    return 0;
	}
	return 1;
    }

    # XXX you don't have to turn a ruby card received from 9 sages to dust
    # if you have a chalice of fire, or similarly for emerald/spellbook
    #     http://www.boardgamegeek.com/article/3523554#3523554

    return 0;
}

sub can_buy_gem_type_right_now {
    @_ == 2 || badinvo;
    my $self = shift;
    my $gtype = shift;

    return $self->can_buy_gem_backend($gtype, 1);
}

# XXX do I have these rules correct for 9 sages?
# - isn't having a crystale/chalice enough for emerald/ruby card?
# - what if you could enchant a gem of that type but haven't yet?

sub could_buy_gem_type_at_some_point {
    @_ == 2 || badinvo;
    my $self = shift;
    my $gtype = shift;

    return $self->can_buy_gem_backend($gtype, 0);
}

sub consolidate_dust {
    @_ == 1 || badinvo;
    my $self = shift;

    my $big_dust = $self->a_game->a_dust_data->[0][DUST_DATA_VALUE];

    # @old_dust is kept in descending order of energy
    my @old_dust = sort { $b->energy <=> $a->energy }
		    grep { $_->is_energy_dust
			    # no need to consolidate the 10s
			    # XXX test
			    && $_->energy < $big_dust
			} $self->items
	or return;

    # XXX got to be a better way to deal with the odd dust situation

    # XXX with no 1 dust this consolidates 2 2 2 -> 5 and loses a dust
    my ($old_tot, @new_dust, $new_tot);
    while (1) {
	$old_tot  = sum map { $_->energy } @old_dust;
	@new_dust = Game::ScepterOfZavandor::Item::Energy::Dust->make_dust($self, $old_tot);
	$new_tot  = sum map { $_->energy } @new_dust;
	if ($old_tot == $new_tot) {
	    last;
	}
	# Oops, I couldn't make that amount.  Eg, 2 2 2 -> 5.  Drop a
	# small one and try again.
	if (!@old_dust) {
	    return;
	}
	debug "consolidate dust:  ignoring $old_dust[-1]";
	pop @old_dust;
    }

    if ($old_tot - 1 == $new_tot) {
    	# oops, lost a dust
	die "XXX";
    }

    my $before = join " ", map { $_->energy } @old_dust;
    my $after  = join " ", map { $_->energy } @new_dust;
    debug "consolidate dust $before -> $after";

    # I could just remove all the @old_dust and add the @new_dust, but
    # when debugging this makes it harder to see what's really changing.
    # Consequently I go to some trouble to make the minimal number of
    # changes.

    # XXX this task comes into other places too, such as hand limit discard

    # XXX cleaner to implement with a hash?

    # 5 -> 2 -> 1
    # XXX @old_dust already sorted
    #@old_dust = sort { $b->energy <=> $a->energy } @old_dust;
    @new_dust = sort { $b->energy <=> $a->energy } @new_dust;
    my @new_dust_tmp = @new_dust;
    my (@keep_dust, @rm_dust, @add_dust);
    for (@old_dust) {
	while (@new_dust_tmp && $new_dust_tmp[0]->energy > $_->energy) {
	    push @add_dust, shift @new_dust_tmp;
	}
	if (!@new_dust_tmp) {
	    push @rm_dust, $_;
	    next;
	}
	if ($_->energy == $new_dust_tmp[0]->energy) {
	    push @keep_dust, $_;
	    shift @new_dust_tmp;
	    next;
	}
	if ($_->energy > $new_dust_tmp[0]->energy) {
	    push @rm_dust, $_;
	    next;
	}
	xconfess $_->energy, " @new_dust_tmp";
    }
    push @add_dust, splice @new_dust_tmp, 0;

    my $add_tot  = sum 0, map { $_->energy } @add_dust;
    my $rm_tot   = sum 0, map { $_->energy } @rm_dust;
    my $keep_tot = sum 0, map { $_->energy } @keep_dust;
    if (!!@add_dust ^ !!@rm_dust
    	    or $add_tot != $rm_tot
	    or $add_tot + $keep_tot != $old_tot
	    or $old_tot != $new_tot) {
	xconfess map { "$_\n" }
	    "internal dust error:",
	    "  add=[@add_dust]",
	    "  rm=[@rm_dust]",
	    "  keep=[@keep_dust]",
	    "  old=[@old_dust]",
	    "  new=[@new_dust]";
    }

    if (!@add_dust && !@rm_dust) {
	return;
    }

    debug "consolidate @rm_dust -> @add_dust";

    $self->remove_items(@rm_dust);
    $self->add_items(@add_dust);
}

sub destroy_active_gem {
    @_ == 1 || badinvo;
    my $self = shift;

    my %seen;
    my @g = grep { !$seen{$_->a_gem_type}++ } $self->active_gems;

    my $g;
    if (!@g) {
    	$self->a_game->note_to_players(NOTE_INFO, $self->name, " doesn't have any active gems to destroy");
	return;
    }
    elsif (@g == 1) {
	$g = $g[0];
    }
    else {
	$g = $self->a_ui->choose_active_gem_to_destroy;
	# XXX validate
    }

    $self->remove_items($g);
    $self->a_game->note_to_players(NOTE_ITEM_GONE, $self, $g, 0);
}

# This sub enforces your hand limit.  It tries to let you keep as much
# energy as possible.

sub enforce_hand_limit {
    @_ == 1 || badinvo;
    my $self = shift;
    #local $Game::Util::Debug = 1;

    my $hc = $self->current_hand_count;
    my $hl = $self->hand_limit;
    return if $hc <= $hl;

    # There's 1 case where dust has a better hand limit ratio than
    # non-dust (10 dust ratio = 3.33, 3 energy saphire card ratio = 3),
    # but I'm ignoring it.

    my (@dust, @non_dust);
    for (grep { $_->a_hand_count > 0 } $self->items) {
	push @{ $_->is_energy_dust ? \@dust : \@non_dust }, $_;
    }
    debug_var
	non_dust => "@non_dust",
	dust	 => "@dust";

    my @rm;
    my $new_hc = 0;

    if (@non_dust) {
	# XXX why can't this just choose the ones with the best ratio?
	#my ($e, @want_non_dust) = xxx({}, \@non_dust, $#non_dust, $hl);
	my ($hc, $e, @want_non_dust)
	    = knapsack_0_1 \@non_dust,
			    sub { $_[0]->a_hand_count, $_[0]->energy },
			    $hl;
	debug "non-dust-items to keep: @want_non_dust";
	# XXX better way to do this bookkeeping
	for my $i (@non_dust) {
	    if (grep { $_ == $i } @want_non_dust) {
		# keep
		$new_hc += $i->a_hand_count;
	    }
	    else {
		push @rm, $i;
	    }
	}
    }

    # 2. sum the value of the rest and all your dust, remove these items

    # XXX do this without extraneous dust remove/add to make it easier
    # to see what's changing when debugging.  ->consolidate_dust has
    # code to do this which should be shared.

    my $tot_discarded_energy = $self->spend(@dust, @rm);
    debug_var
	tot_discarded_energy => $tot_discarded_energy,
    	hand_count_remaining => $hl - $new_hc;

    # 3. make dust from this total as best you can

    if ($new_hc < $hl) {
	my @new_dust
	    = Game::ScepterOfZavandor::Item::Energy::Dust
    	    	->make_dust_with_hand_limit(
		    $self, $tot_discarded_energy, $hl - $new_hc);
	my $new_dust_energy = sum map { $_->energy } @new_dust;
	debug_var new_dust_energy => $new_dust_energy;
	$tot_discarded_energy -= $new_dust_energy;
	$new_hc += sum map { $_->a_hand_count } @new_dust;
	$self->add_items(@new_dust);
    }

    $new_hc == $hl or xconfess "$new_hc != $hl";

    if ($tot_discarded_energy) {
	# XXX doing this with note_to_players is problematic because it
	# currently destroys/creates dust redundantly, and the extra messages
	# would be ugly
	# XXX might want a special note for this which would show all
	# the items being lost at once?
	$self->a_game->note_to_players(NOTE_INFO, $self->name, " lost $tot_discarded_energy energy to hand limit\n");
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
    else {
	$self->consolidate_dust;
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

# Return an array listing the costs to advance the knowledge levels.
# undef means it can't be advanced right now.

sub knowledge_advancement_costs {
    @_ == 1 || badinvo;
    my $self = shift;

    my @k              = (-1) x @Knowledge;
    my $any_unassigned = 0;

    for ($self->knowledge_chips) {
    	if ($_->is_unbought) {
    	    # do nothing
    	}
    	elsif (!$_->is_assigned) {
	    $any_unassigned = 1;
	}
	elsif ($_->maxed_out) {
	    $k[$_->a_type] = undef;
	}
	else {
	    $k[$_->a_type] = $_->next_level_cost;
	}
    }

    for (0..$#k) {
	if (defined $k[$_] && $k[$_] == -1) {
	    $k[$_] = $any_unassigned
    	    	    	? $Knowledge_data[$_][KNOW_DATA_LEVEL_COST][0]
			: undef;
	}
    }

    return @k;
}

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

    $self->consolidate_dust;
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
