# $Id: Knowledge.pm,v 1.1 2008-07-27 15:05:29 roderick Exp $

use strict;

package Game::ScepterOfZavandor::Item::Knowledge;

use base qw(Game::ScepterOfZavandor::Item);

use Game::Util	qw(add_array_index debug make_ro_accessor);
use RS::Handy	qw(badinvo data_dump dstr xcroak);
use Scalar::Util qw(weaken);

use Game::ScepterOfZavandor::Constant qw(
    /^KNOWLEDGE_/
    /^ITEM_/
    @Knowledge
    @Knowledge_data
);

BEGIN {
    add_array_index 'ITEM', $_ for map { "KNOWLEDGE_$_" }
	qw(TYPE LEVEL);
}

sub new {
    @_ == 3 || badinvo;
    my ($class, $gtype, $player) = @_;

    defined $Knowledge[$gtype] or xcroak;;
    $player->isa(Game::ScepterOfZavandor::Player::) or xcroak;

    my $self = $class->SUPER::new(ITEM_TYPE_KNOWLEDGE);
    $self->[ITEM_KNOWLEDGE_TYPE]      = $gtype;
    $self->[ITEM_KNOWLEDGE_PLAYER]    = $player;
    weaken $self->[ITEM_KNOWLEDGE_PLAYER];
    $self->[ITEM_KNOWLEDGE_DECK]      = $player->a_game->a_knowledge_decks->[$gtype];
    weaken $self->[ITEM_KNOWLEDGE_DECK];
    $self->[ITEM_KNOWLEDGE_ACTIVE_VP] = $Knowledge_data[$gtype][KNOWLEDGE_DATA_VP];
    $self->[ITEM_KNOWLEDGE_ACTIVE]    = 0;

    return $self;
}

make_ro_accessor (
    a_knowledge_type => ITEM_KNOWLEDGE_TYPE,
    a_player   => ITEM_KNOWLEDGE_PLAYER,
);

sub as_string_fields {
    @_ || badinvo;
    my $self = shift;
    my @r = $self->SUPER::as_string_fields(@_);
    push @r,
    	$Knowledge[$self->[ITEM_KNOWLEDGE_TYPE]],
	$self->is_active ? "active" : ();
    return @r;
}

1
