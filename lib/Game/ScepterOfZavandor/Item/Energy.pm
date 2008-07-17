# $Id: Energy.pm,v 1.1 2008-07-17 18:19:03 roderick Exp $

use strict;

package Game::ScepterOfZavandor::Item::Energy;

use base qw(Game::ScepterOfZavandor::Item);

use Game::Util	qw(add_array_indices debug);
use RS::Handy	qw(badinvo create_constant_subs data_dump dstr xcroak);

use Game::ScepterOfZavandor::Constant qw(
    /^GEM_/
    @Gem
);

use vars qw($VERSION);

$VERSION = q$Revision: 1.1 $ =~ /(\d\S+)/ ? $1 : '?';

BEGIN {
    add_array_indices 'ENERGY', qw(value);
}

package Game::ScepterOfZavandor::Item::Energy::Card;

sub new {
    @_ == 3 || badinvo;
    my ($class, $deck, $value) = @_;

    my $self = $class->SUPER::new($value);

    $self->[CARD_DECK]  = $deck; # XXX circular reference

    return $self;
}

sub discard {
    @_ == 1 || badinvo;
    my $self = shift;

    $self->[CARD_DECK]->discard($self);
}


1
