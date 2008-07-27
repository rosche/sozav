# $Id: Artifact.pm,v 1.4 2008-07-27 13:16:08 roderick Exp $

use strict;

package Game::ScepterOfZavandor::Item::Artifact;

use base qw(Game::ScepterOfZavandor::Item::Auctionable);

use Game::Util	qw(add_array_index debug make_ro_accessor);
use RS::Handy	qw(badinvo data_dump dstr shuffle xcroak);

use Game::ScepterOfZavandor::Constant qw(
    /^ARTI_/
    /^ITEM_/
    @Artifact
    @Artifact_data
);

sub new {
    @_ == 2 || badinvo;
    my ($class, $arti_type) = @_;

    my $self = $class->SUPER::new(ITEM_TYPE_ARTIFACT,
				    $arti_type, \@Artifact_data);

    $self->a_gem_slots($self->data(ARTI_DATA_GEM_SLOTS));
    $self->a_hand_limit_modifier($self->data(ARTI_DATA_HAND_LIMIT));

    return $self;
}

sub as_string_fields {
    @_ || badinvo;
    my $self = shift;
    my @r = $self->SUPER::as_string_fields(@_);
    unshift @r,
	$self->data(ARTI_DATA_DECK_LETTER);
    return @r;
}

sub new_deck {
    @_ == 2 || badinvo;
    my $self   = shift;
    my $copies = shift;

    $copies > 0 or xcroak $copies;

    my %by_letter;
    for my $i (0..$#Artifact) {
	for (1..$copies) {
	    my $arti = __PACKAGE__->new($i);
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


sub allows_player_to_enchant_gem_type {
    @_ == 2 || badinvo;
    my $self = shift;
    my $want_gtype = shift;

    my $got_gtype = $self->data(ARTI_DATA_CAN_BUY_GEM);
    return defined $got_gtype && $got_gtype == $want_gtype;
}

# cost modifiers
#     - knowledge of artifacts
#     - turn order
#     - other artifacts

sub discount_on_auc_type {
    @_ == 2 || badinvo;
    my $self     = shift;
    my $auc_type = shift;

    if (Game::ScepterOfZavandor::Item::Auctionable::auc_type_is_artifact $auc_type) {
	my $discount_auc_type = $self->data(ARTI_DATA_DISCOUNT_ARTIFACT);
	return (!defined $discount_auc_type || $discount_auc_type != $auc_type)
	    ? 0
	    : $self->data(ARTI_DATA_DISCOUNT_ARTIFACT_AMOUNT);
    }

    if (Game::ScepterOfZavandor::Item::Auctionable::auc_type_is_sentinel $auc_type) {
	return $self->data(ARTI_DATA_DISCOUNT_SENTINELS);
    }

    return 0;
}

sub free_items {
    @_ == 1 || badinvo;
    my $self = shift;

    my $gtype = $self->data(ARTI_DATA_FREE_GEM);
    return unless defined $gtype;
    return Game::ScepterOfZavandor::Item::Gem->new($gtype, $self->a_player);
}

sub own_only_one {
    @_ == 1 || badinvo;
    my $self = shift;

    return $self->data(ARTI_DATA_OWN_ONLY_ONE);
}

sub produce_energy {
    @_ == 1 || badinvo;
    my $self = shift;

    my $gtype = $self->data(ARTI_DATA_GEM_ENERGY_PRODUCTION);
    defined $gtype
	or return;

    return $self->a_player->a_game->a_gem_decks->[$gtype]->draw;
}

1
