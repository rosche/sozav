# $Id: Auctionable.pm,v 1.11 2012-04-28 20:02:27 roderick Exp $

use strict;

package Game::ScepterOfZavandor::Item::Auctionable;

use base qw(Game::ScepterOfZavandor::Item);

use overload (
    '""'  => "as_string_as_is",
);

use Carp	qw(confess);
use Game::Util	qw(add_array_indices debug
		    make_ro_accessor make_ro_accessor_multi make_rw_accessor);
use RS::Handy	qw(badinvo data_dump dstr xconfess);

use Game::ScepterOfZavandor::Constant qw(
    /^ITEM_/
    /^AUC_/
    @Auctionable
    @Auctionable_data_field
    @Sentinel
);

BEGIN {
    add_array_indices 'ITEM', map { "AUC_$_" } qw(TYPE);
}

# function
# XXX class method?

sub auc_type_is_artifact {
    @_ == 1 || badinvo;
    my ($auc_type) = @_;
    return !auc_type_is_sentinel($auc_type);
}

# function
# XXX class method?

sub auc_type_is_sentinel {
    @_ == 1 || badinvo;
    my ($auc_type) = @_;

    defined $auc_type && $auc_type <= $#Auctionable
	or xconfess;
    return defined $Sentinel[$auc_type];
}

sub new {
    @_ == 5 || badinvo;
    my ($class, $game, $itype, $rauc_data, $auc_type) = @_;

    # XXX validate with sub
    $rauc_data->[$auc_type]
	or xconfess $auc_type;

    my $self = $class->SUPER::new($game, $itype, $rauc_data->[$auc_type]);
    $self->[ITEM_AUC_TYPE] = $auc_type;
    $self->a_static_vp($self->data(AUC_DATA_VP));

    return $self;
}

make_ro_accessor (
    a_auc_type	=> ITEM_AUC_TYPE,
);

make_ro_accessor_multi [Game::ScepterOfZavandor::Item->data_ix], (
    a_data_name		=> AUC_DATA_NAME,
    a_data_min_bid	=> AUC_DATA_MIN_BID,
);

# XXX shouldn't these use make_ro_accessor
# XXX do this generically, use these instead of ->data
#for my $i (0..$#Auctionable_data_field) {
#    no strict 'refs';
#    *{ "get_" . lc $Auctionable_data_field[$i] } = sub {
#	@_ == 1 || badinvo;
#	return $_[0]->data($i);
#    }
#}

sub as_string_fields {
    @_ || badinvo;
    my $self = shift;
    my @r = $self->SUPER::as_string_fields(@_);

    # XXX shorter field for sentinels to keep it under 80 cols?
    unshift @r,
	sprintf "%-21s", $self->a_data_name;

    if (!$self->a_player) {
	push @r,
	    "min=" . $self->a_data_min_bid;
	for my $p ($self->a_game->players_in_table_order) {
	    if (my $cost_mod = $p->auctionable_cost_mod($self)) {
		push @r, "$p:$cost_mod";
	    }
	}
    }

    return @r;
}

sub bought {
}

sub free_items {
}

sub own_only_one {
    return 0;
}

1
