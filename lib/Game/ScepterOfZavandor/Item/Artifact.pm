# $Id: Artifact.pm,v 1.2 2008-07-25 01:06:44 roderick Exp $

use strict;

# XXX Auctionable super class

package Game::ScepterOfZavandor::Item::Artifact;

use base qw(Game::ScepterOfZavandor::Item::Auctionable);

use Game::Util	qw(add_array_index debug make_ro_accessor);
use RS::Handy	qw(badinvo data_dump dstr shuffle xcroak);

use Game::ScepterOfZavandor::Constant qw(
    /^ARTI_/
    /^ITEM_/
    @Artifact
    @Artifact_data
    @Artifact_data_field
);

#BEGIN {
#    add_array_index 'ITEM_AUC', $_ for map { "ARTI_$_" } qw(TYPE);
#}

sub new {
    @_ == 2 || badinvo;
    my ($class, $auc_type) = @_;

    #XXX
    #defined $Artifact[$auc_type] or xcroak;;

    my $self = $class->SUPER::new(ITEM_TYPE_ARTIFACT, $auc_type, \@Artifact_data);

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

sub data {
    @_ >= 2 || badinvo;
    my $self = shift;
    my @ix   = @_;

    my $auc_type = $self->a_auc_type;
    my @r;
    for my $ix (@ix) {
	$ix >= 0 && $ix <= $#Artifact_data_field || die dstr $ix;
	push @r, $Artifact_data[$auc_type][$ix];
    }

    return @r == 1 ? $r[0] : @r;
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

# cost modifiers
#     - knowledge of artifacts
#     - turn order
#     - other artifacts

#sub produce_energy {
#    @_ == 1 || badinvo;
#    my $self = shift;
#
#    # XXX
#    return $self->is_active ? $self->[ITEM_GEM_DECK]->draw : ();
#}

1
