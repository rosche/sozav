# $Id: TurnOrder.pm,v 1.2 2008-07-29 18:38:37 roderick Exp $

use strict;

package Game::ScepterOfZavandor::Item::TurnOrder;

use base qw(Game::ScepterOfZavandor::Item);

use Game::Util	qw($Debug add_array_index debug make_ro_accessor make_rw_accessor);
use RS::Handy	qw(badinvo data_dump dstr xconfess);
use Scalar::Util qw(looks_like_number weaken);

use Game::ScepterOfZavandor::Constant qw(
    /^ITEM_/
    /^TURN_/
    @Turn_order_data
);

sub new {
    @_ == 3 || badinvo;
    my ($class, $player, $i) = @_;

    my $self = $class->SUPER::new(ITEM_TYPE_TURN_ORDER,
				    $player,
				    $Turn_order_data[$i]);
    return $self;
}

sub as_string_fields {
    @_ || badinvo;
    my $self = shift;

    my @r = ($self->name);
    for ([arti => TURN_DATA_ARTIFACT_COST_DISCOUNT],
	    [sent => TURN_DATA_SENTINEL_COST_DISCOUNT]) {
    	my ($desc, $ix) = @$_;
	my $n = $self->data($ix)
	    or next;
	push @r, sprintf "%s=%+d", $desc, $n;
    }

    return @r;
}

sub is_active {
    @_ == 1 || badinvo;
    my $self = shift;

    my $my_vp_ge = $self->data(TURN_DATA_ACTIVE_IF_MY_VP_GE);
    if ($my_vp_ge && $self->a_player->a_score_at_turn_start >= $my_vp_ge) {
	return 1;
    }

    my $any_vp_ge = $self->data(TURN_DATA_ACTIVE_IF_ANY_VP_GE);
    if ($any_vp_ge && grep { $_->a_score_at_turn_start >= $any_vp_ge }
			$self->a_player->a_game->players) {
	return 1;
    }

    return 0;
}

sub name {
    @_ == 1 || badinvo;
    my $self = shift;

    return $self->data(TURN_DATA_NAME);
}

sub discount_on_auc_type {
    @_ == 2 || badinvo;
    my $self     = shift;
    my $auc_type = shift;

    if (!$self->is_active) {
	return 0;
    }

    if (Game::ScepterOfZavandor::Item::Auctionable::auc_type_is_artifact $auc_type) {
    	return $self->data(TURN_DATA_ARTIFACT_COST_DISCOUNT);
    }

    if (Game::ScepterOfZavandor::Item::Auctionable::auc_type_is_sentinel $auc_type) {
	return $self->data(TURN_DATA_SENTINEL_COST_DISCOUNT);
    }

    return 0;
}

sub use_up {
    @_ == 1 || badinvo;
    my $self = shift;
    # nothing to do
}

1
