# $Id: Artifact.pm,v 1.1 2008-07-24 00:49:04 roderick Exp $

use strict;

package Game::ScepterOfZavandor::Item::Artifact;

use base qw(Game::ScepterOfZavandor::Item);

use Game::Util	qw(add_array_index debug make_ro_accessor);
use RS::Handy	qw(badinvo data_dump dstr xcroak);

use Game::ScepterOfZavandor::Constant qw(
    /^ARTI_/
    Artifact_data
);

BEGIN {
    add_array_index 'ITEM', $_ for map { "ARTI_$_" } qw(TYPE);
}

sub new {
    @_ == 2 || badinvo;
    my ($class, $arti_type) = @_;

    defined $Artifact[$arti_type] or xcroak;;

    my $self = $class->SUPER::new(ITEM_TYPE_ARTI);
    $self->[ITEM_ARTI_TYPE]     = $arti_type;
    return $self;
}

make_ro_accessor (
    a_arti_type => ITEM_ARTI_TYPE,
);

sub as_string_fields {
    @_ || badinvo;
    my $self = shift;
    my @r = $self->SUPER::as_string_fields(@_);
    push @r,
	$self->[ARTI_DECK_LETTER,
    	$Artifact[$self->[ITEM_ARTI_TYPE]];
    return @r;
}

sub new_deck {
    @_ == 2 || badinvo;
    my $self   = shift;
    my $copies = shift;

    $copies > 0 or xcroak $copies;

    my %by_letter;
    for my $i (@Artifact_data) {
	for (1..$copies) {
	    push @{ $by_letter{$_->[ARTI_DATA_DECK_LETTER]} },
	    	__PACKAGE__->new($i);
    	}
    }

    my $deck = Game::Util::Deck->new;
    $deck->auto_reshuffle(0);
    for (sort keys %by_letter) {
	$deck->discard(shuffle @{ $by_letter{$_} };
    }

    return $deck;
}

# cost modifiers
#     - knowledge of artifacts
#     - turn order
#     - other artifacts

sub produce_energy {
    @_ == 1 || badinvo;
    my $self = shift;

    # XXX
    return $self->is_active ? $self->[ITEM_GEM_DECK]->draw : ();
}

1
