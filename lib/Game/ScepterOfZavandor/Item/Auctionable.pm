# $Id: Auctionable.pm,v 1.10 2008-08-11 23:53:46 roderick Exp $

use strict;

package Game::ScepterOfZavandor::Item::Auctionable;

use base qw(Game::ScepterOfZavandor::Item);

use overload (
    '""'  => "as_string_as_is",
);

use Carp	qw(confess);
use Game::Util	qw(add_array_index debug make_ro_accessor make_rw_accessor);
use RS::Handy	qw(badinvo data_dump dstr xconfess);

use Game::ScepterOfZavandor::Constant qw(
    /^ITEM_/
    /^AUC_/
    @Auctionable
    @Auctionable_data_field
    @Sentinel
);

BEGIN {
    add_array_index 'ITEM', $_ for map { "AUC_$_" } qw(TYPE);
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
    a_auc_type => ITEM_AUC_TYPE,
);

# XXX do this generically, use these instead of ->data
for my $i (0..$#Auctionable_data_field) {
    no strict 'refs';
    *{ "get_" . lc $Auctionable_data_field[$i] } = sub {
	@_ == 1 || badinvo;
	return $_[0]->data($i);
    }
}

sub as_string_fields {
    @_ || badinvo;
    my $self = shift;
    my @r = $self->SUPER::as_string_fields(@_);
    # XXX shorter field for sentinels to keep it under 80 cols?
    unshift @r,
	sprintf "%-21s", $self->data(AUC_DATA_NAME);
    push @r,
	"min=" . $self->get_min_bid;
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
