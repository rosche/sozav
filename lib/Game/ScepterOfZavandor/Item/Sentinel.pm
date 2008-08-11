# $Id: Sentinel.pm,v 1.9 2008-08-11 23:53:47 roderick Exp $

use strict;

package Game::ScepterOfZavandor::Item::Sentinel;

use base qw(Game::ScepterOfZavandor::Item::Auctionable);

use Game::Util	qw(add_array_index debug make_ro_accessor);
use RS::Handy	qw(badinvo data_dump dstr shuffle xconfess);

use Game::ScepterOfZavandor::Constant qw(
    /^GEM_/
    /^ITEM_/
    /^OPT_/
    /^SENT_/
    @Sentinel
    @Sentinel_real_ix_xxx
    @Sentinel_data
);

sub new {
    @_ == 3 || badinvo;
    my ($class, $game, $auc_type) = @_;

    my $self = $class->SUPER::new($game, ITEM_TYPE_SENTINEL,
				    \@Sentinel_data, $auc_type);

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
    	$self->data(SENT_DATA_VP_PER) . 'x',
	$self->data(SENT_DATA_DESC);
    if (my $max = $self->data(SENT_DATA_MAX_BONUS_VP)) {
    	push @r, "(max bonus $max)";
    }
    return @r;
}

# XXX name
sub new_deck {
    @_ == 2 || badinvo;
    my $self = shift;
    my $game = shift;

    my @a = ();
    for (@Sentinel_real_ix_xxx) {
	push @a, __PACKAGE__->new($game, $_);
    }
    return @a;
}

sub vp_extra {
    @_ == 1 || badinvo;
    my $self = shift;

    if (!$self->a_player) {
	return 0;
    }

    my $auc_type  = $self->a_auc_type;
    my $ct        = $self->a_auc_type;
    my $p         = $self->a_player;

    if (0) {

    } elsif (defined(my $bonus_gem = $self->data(SENT_DATA_BONUS_GEM))) {

	# per active gem of some type

	$ct = grep { $_->a_gem_type == $bonus_gem } $p->active_gems;

    } elsif (defined(my $bonus_auc = $self->data(SENT_DATA_BONUS_AUC_TYPE))) {

    	$ct = grep { $bonus_auc->{$_->a_auc_type} } $p->auctionables;

    } elsif ($auc_type == SENT_PHOENIX) {

	# per kind of active gem

    	my %g;
	for ($p->active_gems) {
	    $g{$_->a_gem_type} = 1;
	}
	$ct = scalar keys %g;

    } elsif ($auc_type == SENT_OWL) {

	# per top-level knowledge

	$ct = grep { $_->maxed_out } $p->knowledge_chips;

    } else {
	xconfess "auc_type $auc_type";
    }

    defined $ct
	or xconfess $auc_type;

    my $bvp = $ct * $self->data(SENT_DATA_VP_PER);

    my $max_bvp = $self->data(SENT_DATA_MAX_BONUS_VP);
    if (defined $max_bvp && $bvp > $max_bvp) {
	debug "clamping bonus vp to $max_bvp";
	$bvp = $max_bvp;
    }

    return $bvp;
}

1
