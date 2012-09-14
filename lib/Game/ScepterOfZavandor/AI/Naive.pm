# $Id: Naive.pm,v 1.1 2012-09-14 01:16:54 roderick Exp $

use strict;

package Game::ScepterOfZavandor::AI::Naive;

use base qw(Game::ScepterOfZavandor::AI);

#use Game::Util 	qw(add_array_indices debug
#		    make_ro_accessor make_rw_accessor);
use RS::Handy	qw(badinvo data_dump dstr process_arg_pairs shuffle xconfess);
use List::Util	qw(max);
#use Scalar::Util qw(weaken);

use Game::ScepterOfZavandor::Constant	qw(
    /^ARTI_/
    /^GEM_/
    /^KNOW_/
    @Gem
);
#    /^NOTE_/
#    @Character
#    @Gem_data
#    @Knowledge_data
#    @Note
#    @Option

# Abstract methods:
#    in
#    out
#    out_error
#    out_notice

# game-specific methods -----------------------------------------------------

sub choose_knowledge_type_to_advance {
    @_ == 1 || badinvo;
    my $self = shift;

    my @k = $self->advancable_knowledge_chips_by_cost;
    return @k ? $k[-1]->a_type : ();
}

sub solicit_bid {
    @_ == 4 || badinvo;
    my ($self, $auc, $cur_bid, $cur_winner) = @_;

    my $p = $self->a_player;

    if (!$self->want_auctionable($auc)) {
    	return 0;
    }

    my $mod = $p->auctionable_cost_mod($auc);
    if ($p->current_energy_liquid <= $cur_bid + $mod) {
	return 0;
    }

    my $min = $auc->a_data_min_bid;
    if ($cur_bid > $min * 1.05) {
    	return 0;
    }

    return $cur_bid + 1;
}

#------------------------------------------------------------------------------

sub next_knowledge_track_to_start {
    @_ == 1 || badinvo;
    my $self = shift;

    for my $ktype (KNOW_ARTIFACTS, KNOW_ACCUM, KNOW_9SAGES) {
	if (!$self->a_player->knowledge_chip_for_track($ktype)) {
	    return $ktype;
	}
    }
    return undef;
}

sub want_auctionable {
    @_ == 2 || badinvo;
    my $self = shift;
    my $auc  = shift;

    my $p = $self->a_player;
    my $auc_type = $auc->a_auc_type;

    # don't buy 2 spellbooks or elixir if you have a spellbook
    #
    # XXX both can be useful for VP

# XXX this lets you buy elixir anyway
#    my $buy_gtype = $auc->is_artifact && $auc->data(ARTI_DATA_CAN_BUY_GEM);
#    if (defined $buy_gtype
#    	    && $p->have_ability_to_buy_gem_type($buy_gtype)
#	    && defined !$auc->data(ARTI_DATA_FREE_GEM)) {
#	return 0;
#    }

    if ($auc_type == ARTI_SPELLBOOK
	    && grep { $_->a_auc_type == $auc_type } $p->auctionables) {
	return 0;
    }
    if ($auc_type == ARTI_ELIXIR
	    && grep { $_->a_auc_type == ARTI_SPELLBOOK } $p->auctionables) {
	return 0;
    }

    # don't buy sentinel worth no bonus VP

    if ($auc->is_sentinel && !$auc->vp_extra_for_player($p)) {
    	return 0;
    }

    # don't buy artifact with free knowledge if you have nothing to advance

    if ($auc->is_artifact
	    && $auc->data(ARTI_DATA_ADVANCE_KNOWLEDGE)
	    && !$p->knowledge_chips_advancable) {
	return 0;
    }

    return 1;
}

#------------------------------------------------------------------------------

sub maybe_advance_knowledge {
    @_ == 3 || badinvo;
    my ($self, $p, $liquid) = @_;

    if ($p->a_advanced_knowledge_this_turn) {
	return 0;
    }

    if (my @k = $self->advancable_knowledge_chips_by_cost) {
	my $k = shift @k;
	if ($liquid < $k->next_level_cost) {
	    return 0;
	}
	$p->advance_knowledge($k->a_type, 0);
	return 1;
    }

    if ($p->knowledge_chips_unassigned) {
    	my $ktype = $self->next_knowledge_track_to_start;
	if (defined $ktype) {
	    if ($liquid >= $p->knowledge_track_next_level_cost($ktype)) {
		$p->advance_knowledge($ktype, 0);
		return 1;
	    }
	    else {
		# have chip but can't afford it
		return 0;
	    }
	}
    }

    return 0;
}

sub maybe_buy_auctionable {
    @_ == 3 || badinvo;
    my ($self, $p, $liquid) = @_;

    for my $auc ($self->a_game->auctionable_artifacts) {
    	if (!$p->allowed_to_own_auctionable($auc)) {
	    next;
	}
	if (!$self->want_auctionable($auc)) {
	    next;
	}
	my $min = $auc->a_data_min_bid;
	if ($liquid < $min + $p->auctionable_cost_mod($auc)) {
	    next;
	}
	$self->a_game->auction_item($p, $auc, $min);
	return 1;
    }

    return 0;
}

sub maybe_buy_gem {
    @_ == 3 || badinvo;
    my ($self, $p, $liquid) = @_;

    my $best_gtype = $self->best_buyable_gem_type;
    my $gem_to_buy;

    if ($p->num_free_gem_slots) {
    	$gem_to_buy = $best_gtype;
    }
    else {
	for (grep { $_->is_active } $p->gems_by_cost) {
	    # can't use != due to ruby limit, else you'd try to buy a
	    # gem to replace a ruby
	    if ($_->a_gem_type < $best_gtype) {
	    	$gem_to_buy = $best_gtype;
		last;
	    }
	}
    }

    if (!$gem_to_buy) {
	return 0;
    }

    if ($liquid < $p->gem_cost($best_gtype)) {
    	return undef; # wanted to buy but couldn't afford
    }

    $p->buy_gem($best_gtype);
    return 1;
}

sub maybe_buy_knowledge_chip {
    @_ == 3 || badinvo;
    my ($self, $p, $liquid) = @_;

    if ($p->knowledge_chips_advancable) {
	return 0;
    }

    # don't bother if it can't advance right away

    if ($p->a_advanced_knowledge_this_turn) {
    	return 0;
    }

    my $ktype = $self->next_knowledge_track_to_start;
    if (!defined $ktype) {
	return 0;
    }

    my @k = $p->knowledge_chips_unbought_by_cost;
    if (@k && $liquid >= $k[0]->a_cost
			    + $p->knowledge_track_next_level_cost($ktype)) {
    	$p->buy_knowledge_chip($k[0], 0);
	return 1;
    }

    return 0;
}

sub maybe_buy_sentinel {
    @_ == 3 || badinvo;
    my ($self, $p, $liquid) = @_;

    my @s = $self->a_game->auctionable_sentinels
    	or return 0; # can't happen

    if ($p->current_energy_liquid < $s[0]->a_data_min_bid
					+ $p->auctionable_cost_mod($s[0])) {
    	return 0;
    }

    my $max_vp = -1;
    my @best;
    for my $s (@s) {
	if (!$self->want_auctionable($s)) {
	    next;
	}
    	my $this_vp = $s->vp_extra_for_player($p);
	if ($this_vp > $max_vp) {
	    $max_vp = $this_vp;
	    @best = ($s);
	}
	elsif ($this_vp == $max_vp) {
	    push @best, $s;
	}
    }

    if (!@best) {
    	return 0; # bad news
    }

    my $s = (shuffle @best)[0];
    $p->a_game->auction_item($p, $s, $s->a_data_min_bid);
    return 1;
}

sub bank_extra_cash {
    @_ == 2 || badinvo;
    my ($self, $p) = @_;

    while ($p->am_over_hand_limit) {
	my $cash = $p->current_energy_cards_dust;
	if ($cash < $p->gem_cost(GEM_OPAL)) {
	    last;
	}
	$p->buy_gem(GEM_OPAL);
    }
}

sub one_action {
    @_ == 1 || badinvo;
    my $self = shift;

    my $p      = $self->a_player;
    my $liquid = $p->current_energy_liquid;

    if ($self->maybe_buy_sentinel($p, $liquid)) {
	return 1;
    }

    my $bought_gem = $self->maybe_buy_gem($p, $liquid);
    if ($bought_gem) {
	return 1;
    }

    if ($self->maybe_advance_knowledge($p, $liquid)) {
	return 1;
    }

    if (!defined $bought_gem) {
	# If I wanted to buy a gem but couldn't afford it don't
	# try the lower-priority actions.
    }
    else {
	if ($self->maybe_buy_auctionable($p, $liquid)) {
	    return 1;
	}

	if ($self->maybe_buy_knowledge_chip($p, $liquid)) {
	    return 1;
	}
    }

    $self->bank_extra_cash($p);
    return 0;
}

#------------------------------------------------------------------------------

1
