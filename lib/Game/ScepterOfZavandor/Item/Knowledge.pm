# $Id: Knowledge.pm,v 1.7 2008-08-04 13:03:02 roderick Exp $

use strict;

package Game::ScepterOfZavandor::Item::Knowledge;

use base qw(Game::ScepterOfZavandor::Item);

use Game::Util	qw($Debug add_array_index debug make_ro_accessor make_rw_accessor);
use RS::Handy	qw(badinvo data_dump dstr xconfess);
use Scalar::Util qw(looks_like_number weaken);

use Game::ScepterOfZavandor::Constant qw(
    /^ENERGY_EST_/
    /^GEM_/
    /^ITEM_/
    /^KNOW_/
    @Knowledge
    @Knowledge_data
    $Knowledge_9sages_card_count
    $Knowledge_top_vp
);

BEGIN {
    add_array_index 'ITEM', $_ for map { "KNOW_$_" } (
	'COST',		# > 0 -> unbought, = 0 -> bought, possibly unallocated
	'TYPE',		# undef -> unassigned
	'LEVEL',	# 0-3
	#'BOUGHT_RUBY',	# true after buying a ruby, for druid at level 3
    	'9SAGES_CARDS',	# cards drawn for 9 sages for next turn
    );
}

sub new {
    @_ == 3 || badinvo;
    my ($class, $player, $cost) = @_;

    defined $cost && looks_like_number($cost) && $cost >= 0
	or xconfess;

    my $self = $class->SUPER::new($player, ITEM_TYPE_KNOWLEDGE);
    $self->a_cost($cost);
    $self->[ITEM_KNOW_9SAGES_CARDS] = [];
    return $self;
}

sub set_type {
    @_ == 2 || badinvo;
    my $self   = shift;
    my $ktype  = shift;

    # XXX sub to do this validation, passed in max index number, use in
    # a lot of places
    defined $ktype && looks_like_number($ktype)
	    && $ktype >= 0 && $ktype <= $#Knowledge
    	or xconfess dstr $ktype;

    !defined $self->a_type
    	or xconfess dstr $self->a_type, " -> $ktype";

    for ($self->a_player->knowledge_chips) {
	if ($_->ktype_is($ktype)) {
	    die "player already has $_";
	}
    }

    $self->a_data($Knowledge_data[$ktype]);
    $self->[ITEM_KNOW_TYPE]  = $ktype;
    $self->a_hand_limit_modifier($self->data(KNOW_DATA_HAND_LIMIT));
    $self->[ITEM_KNOW_LEVEL] = -1;
    $self->advance;
}

make_ro_accessor (
    a_type  => ITEM_KNOW_TYPE,
);

make_rw_accessor (
    a_cost  => ITEM_KNOW_COST,
    a_level => ITEM_KNOW_LEVEL,
);

sub as_string_fields {
    @_ || badinvo;
    my $self = shift;

    my @r = $self->SUPER::as_string_fields(@_);

    my $cost  = $self->a_cost;
    my $level = $self->user_level;
    my $type  = $self->a_type;

    if ($cost > 0) {
    	push @r, "cost=$cost"
    }
    elsif (!defined $type) {
	push @r, "unassigned";
    }
    else {
    	my $title = $Knowledge[$type];
	$title =~ s/($Knowledge_data[$type][KNOW_DATA_ALIAS])/[$1]/ or die;
	push @r,
	    $title,
	    "l=$level",
    	    $self->maxed_out ? () : "next_cost=" . $self->next_level_cost;
    }
    return @r;
}

sub advance {
    @_ == 1 || badinvo;
    my $self = shift;

    my $max_level = $#{ $self->data(KNOW_DATA_LEVEL_COST) };

    !$self->maxed_out
    	or die "already advanced to the top for $self";

    my $new_level = $self->a_level + 1;
    debug "$self advance to level raw $new_level";
    $self->a_level($new_level);

    # cost is handled externally

    if ($self->ktype_is(KNOW_9SAGES)) {
	push @{ $self->[ITEM_KNOW_9SAGES_CARDS] },
	    $self->a_player->a_game->draw_from_deck($self->detail,
					    $Knowledge_9sages_card_count);
    }

    if ($self->ktype_is(KNOW_ACCUM)) {
	$self->a_gem_slots($self->detail);
    }
}

sub allows_player_to_enchant_gem_type {
    @_ == 2 || badinvo;
    my $self  = shift;
    my $gtype = shift;

    if ($gtype == GEM_RUBY && $self->ktype_is(KNOW_FIRE)) {
    	debug "testing kfire detail=", $self->detail;
    	return $self->detail;
    }

    return 0;
}

sub bought {
    @_ == 1 || badinvo;
    my $self  = shift;

    debug "bought $self";
    $self->a_cost(0);
}

sub detail {
    @_ == 1 || badinvo;
    my $self = shift;

    return defined($self->a_type)
	    ? $self->data(KNOW_DATA_DETAIL)->[$self->a_level]
	    : undef;
}

sub cost_mod_on_auc_type {
    @_ == 2 || badinvo;
    my $self     = shift;
    my $auc_type = shift;

    if (!$self->ktype_is(KNOW_ARTIFACTS)) {
	return 0;
    }

    my $cost_mod = $self->detail;
    $cost_mod *= 2
	if Game::ScepterOfZavandor::Item::Auctionable::auc_type_is_sentinel $auc_type;

    debug "knowledge of artifacts cost_mod $cost_mod" if $Debug > 2;
    return $cost_mod;
}

sub ktype_is {
    @_ == 2 || badinvo;
    my $self      = shift;
    my $want_type = shift;

    return defined $self->a_type && $self->a_type == $want_type;
}

sub is_advancable {
    @_ == 1 || badinvo;
    my $self = shift;

    return defined $self->a_type && !$self->maxed_out;
}

sub is_assigned {
    @_ == 1 || badinvo;
    my $self = shift;

    return defined $self->a_type;
}

sub is_bought {
    @_ == 1 || badinvo;
    my $self = shift;

    return $self->a_cost == 0;
}

sub is_unbought {
    @_ == 1 || badinvo;
    my $self = shift;

    return !$self->is_bought;
}

sub is_unassigned {
    @_ == 1 || badinvo;
    my $self = shift;

    return !$self->is_assigned;
}

sub maxed_out {
    @_ || badinvo;
    my $self = shift;

    return $self->is_assigned &&
	    $self->a_level == $#{ $self->data(KNOW_DATA_LEVEL_COST) };
}

sub modify_gem_cost {
    @_ == 2 || badinvo;
    my $self = shift;
    my $cost = shift;

    if ($self->ktype_is(KNOW_GEMS)) {
	my $mult = $self->detail;
	$cost = int($cost * $mult);
    }
    return $cost;
}

sub name {
    @_ == 1 || badinvo;
    my $self = shift;

    return $self->data(KNOW_DATA_NAME);
}

sub next_level_cost {
    @_ || badinvo;
    my $self = shift;

    !$self->maxed_out
    	or die "already advanced to the top for $self";

    return $self->data(KNOW_DATA_LEVEL_COST)->[1+$self->a_level];
}

sub produce_energy {
    @_ == 1 || badinvo;
    my $self = shift;

    if ($self->ktype_is(KNOW_EFLOW) && (my $dust = $self->detail)) {
	return Game::ScepterOfZavandor::Item::Energy::Dust->make_dust($self->a_player, $dust);
    }

    if (my @card = @{ $self->[ITEM_KNOW_9SAGES_CARDS] }) {
	@{ $self->[ITEM_KNOW_9SAGES_CARDS] } = ();
	my @item;
	for (@card) {
	    # XXX turn to dust if you can't produce it
	    push @item, $_;
	}
	return @item;
    }

    return;
}

sub produce_energy_estimate {
    @_ == 1 || badinvo;
    my $self = shift;

    if ($self->ktype_is(KNOW_EFLOW) && (my $dust = $self->detail)) {
    	my @ee;
	$ee[ENERGY_EST_MIN] = $dust;
	$ee[ENERGY_EST_AVG] = $dust;
	$ee[ENERGY_EST_MAX] = $dust;
	return @ee;
    }

    return;
}

sub user_level {
    @_ == 1 || badinvo;
    my $self = shift;
    return defined $self->a_level ? 1 + $self->a_level : undef;
}

sub vp_extra {
    @_ == 1 || badinvo;
    my $self = shift;

    return $self->maxed_out ? $Knowledge_top_vp : 0;
}
1
