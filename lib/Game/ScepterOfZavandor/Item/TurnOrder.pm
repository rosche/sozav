use strict;

package Game::ScepterOfZavandor::Item::TurnOrder;

use base qw(Game::ScepterOfZavandor::Item);

use Game::Util	qw($Debug add_array_indices debug make_ro_accessor make_rw_accessor);
use RS::Handy	qw(badinvo data_dump dstr xconfess);
use Scalar::Util qw(looks_like_number weaken);

use Game::ScepterOfZavandor::Constant qw(
    /^ITEM_/
    /^TURN_/
    @Turn_order_data
);

sub new {
    @_ == 3 || badinvo;
    my ($class, $game, $i) = @_;

    my $self = $class->SUPER::new($game, ITEM_TYPE_TURN_ORDER,
				    $Turn_order_data[$i]);
    return $self;
}

sub as_string_fields {
    @_ || badinvo;
    my $self = shift;

    my @r = ($self->name);
    for ([arti => TURN_DATA_ARTIFACT_COST_MOD],
	    [sent => TURN_DATA_SENTINEL_COST_MOD]) {
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
			$self->a_game->players_in_table_order) {
	return 1;
    }

    return 0;
}

sub name {
    @_ == 1 || badinvo;
    my $self = shift;

    return $self->data(TURN_DATA_NAME);
}

sub cost_mod_on_auc_type {
    @_ == 2 || badinvo;
    my $self     = shift;
    my $auc_type = shift;

    if (!$self->is_active) {
	return 0;
    }

    if (Game::ScepterOfZavandor::Item::Auctionable::auc_type_is_artifact $auc_type) {
    	return $self->data(TURN_DATA_ARTIFACT_COST_MOD);
    }

    if (Game::ScepterOfZavandor::Item::Auctionable::auc_type_is_sentinel $auc_type) {
	return $self->data(TURN_DATA_SENTINEL_COST_MOD);
    }

    return 0;
}

sub use_up {
    @_ == 1 || badinvo;
    my $self = shift;

    $self->a_player(undef);
}

1
