# $Id: Artifact.pm,v 1.14 2012-09-18 13:51:27 roderick Exp $

use strict;

package Game::ScepterOfZavandor::Item::Artifact;

use base qw(Game::ScepterOfZavandor::Item::Auctionable);

use Game::Util	qw($Debug add_array_indices debug make_ro_accessor
		    same_referent);
use RS::Handy	qw(badinvo data_dump dstr shuffle xcroak);

use Game::ScepterOfZavandor::Constant qw(
    /^ARTI_/
    /^ITEM_/
    /^NOTE_/
    /^OPT_/
    @Artifact
    @Artifact_data
    @Gem
);

sub new {
    @_ == 3 || badinvo;
    my ($class, $game, $arti_type) = @_;

    my $self = $class->SUPER::new($game, ITEM_TYPE_ARTIFACT,
				    \@Artifact_data, $arti_type);

    $self->a_gem_slots($self->data(ARTI_DATA_GEM_SLOTS));
    $self->a_hand_limit_modifier($self->data(ARTI_DATA_HAND_LIMIT));

    return $self;
}

sub as_string_fields {
    @_ || badinvo;
    my $self = shift;
    my @r = $self->SUPER::as_string_fields(@_);

    if (!$self->a_game->option(OPT_VERBOSE)) {
	return @r;
    }

    push @r,
	    "deck=" . $self->data(ARTI_DATA_DECK_LETTER)
	if $Debug;

    my $add = sub {
	my $s = "@_";
	$s =~ tr/ /-/;
    	push @r, $s;
    };

    my $add_x = sub {
    	my $ix = shift;
	my $n = $self->data($ix);
	return unless $n;
	my $s = "@_=+$n";
	$add->($s);
    };


    if ($self->data(ARTI_DATA_OWN_ONLY_ONE)) {
	$add->("just 1");
    }

    $add_x->(ARTI_DATA_KNOWLEDGE_CHIP,    "knowledge chip");
    $add_x->(ARTI_DATA_ADVANCE_KNOWLEDGE, "knowledge");
    $add_x->(ARTI_DATA_DESTROY_GEM,       "destroy gem");
    $add_x->(ARTI_DATA_GEM_SLOTS,         "gem slot");
    $add_x->(ARTI_DATA_HAND_LIMIT,        "hand limit");

    if (defined(my $n = $self->data(ARTI_DATA_CAN_BUY_GEM))) {
    	$add->("buy=$Gem[$n]");
    }

    if (defined(my $n = $self->data(ARTI_DATA_FREE_GEM))) {
	$add->("free=$Gem[$n]");
    }

    if (defined(my $n = $self->data(ARTI_DATA_GEM_ENERGY_PRODUCTION))) {
	$add->("produce=$Gem[$n]");
    }

    if (my $auc_type = $self->data(ARTI_DATA_COST_MOD_ARTIFACT)) {
    	my $n = $self->data(ARTI_DATA_COST_MOD_ARTIFACT_AMOUNT);
	$add->("$Artifact[$auc_type]=$n");
    }

    if (my $n = $self->data(ARTI_DATA_COST_MOD_SENTINELS)) {
	$add->("sentinels=$n");
    }

    return @r;
}

sub new_deck {
    @_ == 3 || badinvo;
    my $self   = shift;
    my $game   = shift;
    my $copies = shift;

    $copies > 0 or xcroak $copies;

    my %by_letter;
    for my $i (0..$#Artifact) {
	for (1..$copies) {
	    my $arti = __PACKAGE__->new($game, $i);
	    push @{ $by_letter{$arti->data(ARTI_DATA_DECK_LETTER)} }, $arti;
    	}
    }

    my $deck = Game::Util::Deck->new;
    $deck->a_auto_reshuffle(0);
    for (sort keys %by_letter) {
	$deck->push(shuffle @{ $by_letter{$_} });
    }

    return $deck;
}

#------------------------------------------------------------------------------

sub allows_player_to_buy_gem_type {
    @_ == 2 || badinvo;
    my $self = shift;
    my $want_gtype = shift;

    my $got_gtype = $self->data(ARTI_DATA_CAN_BUY_GEM);
    return defined $got_gtype && $got_gtype == $want_gtype;
}

sub destroys_active_gems {
    @_ == 1 || badinvo;
    my $self = shift;

    return $self->data(ARTI_DATA_DESTROY_GEM);
}

sub bought {
    @_ == 1 || badinvo;
    my $self = shift;

    for (1..$self->data(ARTI_DATA_DESTROY_GEM)) {
    	for my $p ($self->a_game->players_in_table_order) {
	    if (!same_referent $p, $self->a_player) {
		$p->destroy_active_gem;
	    }
	}
    }

    for (1..$self->data(ARTI_DATA_KNOWLEDGE_CHIP)) {
	$self->a_player->knowledge_chips_unbought_by_cost
	    or last;
	$self->a_player->buy_knowledge_chip(undef, 1);
    }

    for (1..$self->data(ARTI_DATA_ADVANCE_KNOWLEDGE)) {
    	# XXX let user not advance if desired?
    	my $ktype = $self->a_player->a_ui->choose_knowledge_type_to_advance;
	if (!defined $ktype) {
	    $self->a_game->note_to_players(NOTE_INFO,
			    $self->a_player,
			    " lost knowledge advance, no track to advance\n");
	}
	else {
	    $self->a_player->advance_knowledge($ktype, 1);
	}
    }
}

# cost modifiers
#     - knowledge of artifacts
#     - turn order
#     - other artifacts

sub cost_mod_on_auc_type {
    @_ == 2 || badinvo;
    my $self     = shift;
    my $auc_type = shift;

    if (Game::ScepterOfZavandor::Item::Auctionable::auc_type_is_artifact $auc_type) {
	my $want_auc_type = $self->data(ARTI_DATA_COST_MOD_ARTIFACT);
	return (!defined $want_auc_type || $want_auc_type != $auc_type)
	    ? 0
	    : $self->data(ARTI_DATA_COST_MOD_ARTIFACT_AMOUNT);
    }

    if (Game::ScepterOfZavandor::Item::Auctionable::auc_type_is_sentinel $auc_type) {
	return $self->data(ARTI_DATA_COST_MOD_SENTINELS);
    }

    return 0;
}

sub free_items {
    @_ == 2 || badinvo;
    my $self = shift;
    my $game = shift;

    my $gtype = $self->data(ARTI_DATA_FREE_GEM);
    return unless defined $gtype;
    return Game::ScepterOfZavandor::Item::Gem->new($self->a_player, $gtype);
}

sub own_only_one {
    @_ == 1 || badinvo;
    my $self = shift;

    return $self->data(ARTI_DATA_OWN_ONLY_ONE);
}

sub gem_deck_method {
    @_ >= 2 || badinvo;
    my $self = shift;
    my $meth = shift;

    my $gtype = $self->data(ARTI_DATA_GEM_ENERGY_PRODUCTION);
    defined $gtype
	or return;

    return $self->a_game->gem_deck($gtype)->$meth(@_);
}

sub produce_energy {
    @_ == 1 || badinvo;
    my $self = shift;

    return $self->gem_deck_method("draw");
}

sub produce_energy_estimate {
    @_ == 1 || badinvo;
    my $self = shift;

    return $self->gem_deck_method("energy_estimate");
}

sub produces_energy_of_gem_type {
    @_ == 2 || badinvo;
    my $self = shift;
    my $query_gtype = shift;

    my $arti_gtype = $self->data(ARTI_DATA_GEM_ENERGY_PRODUCTION);
    return defined $arti_gtype && $arti_gtype == $query_gtype;
}

1
