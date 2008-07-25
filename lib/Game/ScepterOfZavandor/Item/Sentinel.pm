# $Id: Sentinel.pm,v 1.1 2008-07-25 16:33:12 roderick Exp $

use strict;

package Game::ScepterOfZavandor::Item::Sentinel;

use base qw(Game::ScepterOfZavandor::Item::Auctionable);

use Game::Util	qw(add_array_index debug make_ro_accessor);
use RS::Handy	qw(badinvo data_dump dstr shuffle xcroak);

use Game::ScepterOfZavandor::Constant qw(
    /^ARTI_/
    /^ITEM_/
    @Sentinel
    @Sentinel_data
);

#BEGIN {
#    add_array_index 'ITEM_AUC', $_ for map { "ARTI_$_" } qw(TYPE);
#}

sub new {
    @_ == 2 || badinvo;
    my ($class, $auc_type) = @_;

    #XXX
    #defined $Sentinel[$auc_type] or xcroak;;

    my $self = $class->SUPER::new(ITEM_TYPE_SENTINEL, $auc_type, \@Sentinel_data);

    $self->a_vp($self->data(ARTI_DATA_VP));
    $self->a_gem_slots($self->data(ARTI_DATA_GEM_SLOTS));
    $self->a_hand_limit_modifier($self->data(ARTI_DATA_HAND_LIMIT));

    return $self;
}

sub as_string_fields {
    @_ || badinvo;
    my $self = shift;
    my @r = $self->SUPER::as_string_fields(@_);
    push @r,
	$self->data(ARTI_DATA_DECK_LETTER, ARTI_DATA_NAME);
    return @r;
}

1
