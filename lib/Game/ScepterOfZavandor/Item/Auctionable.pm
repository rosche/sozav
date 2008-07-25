# $Id: Auctionable.pm,v 1.3 2008-07-25 17:41:18 roderick Exp $

use strict;

package Game::ScepterOfZavandor::Item::Auctionable;

use base qw(Exporter Game::ScepterOfZavandor::Item);

use Carp	qw(confess);
use Game::Util	qw(add_array_index debug make_ro_accessor make_rw_accessor);
use RS::Handy	qw(badinvo data_dump dstr xconfess);

use Game::ScepterOfZavandor::Constant qw(
    /^ITEM_/
    /^AUC_/
    @Auctionable_data_field
);

use vars qw($VERSION @EXPORT @EXPORT_OK);
BEGIN {
    $VERSION = q$Revision: 1.3 $ =~ /(\d\S+)/ ? $1 : '?';
    @EXPORT_OK = qw(
	auc_type_is_artifact
	auc_type_is_sentinel
    );
}
use subs grep { /^[a-z]/    } @EXPORT, @EXPORT_OK;
use vars grep { /^[\$\@\%]/ } @EXPORT, @EXPORT_OK;

BEGIN {
    add_array_index 'ITEM', $_ for map { "AUC_$_" } qw(TYPE PLAYER DATA);
}

#sub auc_type_is_artifact {
#    @_ == 1 || badinvo;
#    my ($auc_type) = @_;
#    return !auc_type_is_sentinel $auc_type;
#}

#sub auc_type_is_sentinel {
#    @_ == 1 || badinvo;
#    my ($auc_type) = @_;
#    defined $auc_type or xconfess;
#    return $Auctionable_data[$auc_type][AUC_DATA_DECK_LETTER] eq 'S';
#}

sub new {
    @_ == 4 || badinvo;
    my ($class, $itype, $auc_type, $rauc_data) = @_;

    $rauc_data->[$auc_type]
	or xconfess $auc_type;

    my $self = $class->SUPER::new($itype);
    $self->[ITEM_AUC_TYPE] = $auc_type;
    $self->[ITEM_AUC_DATA] = $rauc_data->[$auc_type];
    $self->a_vp($self->data(AUC_DATA_VP));

    return $self;
}

make_ro_accessor (
    a_auc_type => ITEM_AUC_TYPE,
);

make_rw_accessor (
    a_player => ITEM_AUC_PLAYER,
);

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
    push @r,
	$self->data(AUC_DATA_NAME),
	sprintf("min=%3d", $self->get_min_bid);
    return @r;
}

sub data {
    @_ >= 2 || badinvo;
    my $self = shift;
    my @ix   = @_;

    my $rd = $self->[ITEM_AUC_DATA];
    my @r;
    for my $ix (@ix) {
	$ix >= 0 && $ix <= $#{ $rd } || xconfess dstr $ix;
	push @r, $rd->[$ix];
    }

    return @r == 1 ? $r[0] : @r;
}


sub free_items {
}

sub own_only_one {
    return 0;
}

1
