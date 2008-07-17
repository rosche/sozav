# $Id: Deck.pm,v 1.1 2008-07-17 17:40:57 roderick Exp $

package Game::Util::Deck;

use strict;

use base qw(Exporter);

use RS::Handy	qw(badinvo create_constant_subs data_dump dstr xcroak);

use vars qw($VERSION @EXPORT @EXPORT_OK);

$VERSION = q$Revision: 1.1 $ =~ /(\d\S+)/ ? $1 : '?';

BEGIN {
    @EXPORT_OK = qw(
    	@Energy_distribution
    );
}

use subs grep { /^[a-z]/    } @EXPORT, @EXPORT_OK;
use vars grep { /^[\$\@\%]/ } @EXPORT, @EXPORT_OK;

BEGIN {
    add_array_indices 'DECK', qw(draw discard);
}

sub new {
    @_ || badinvo;
    my ($class, @card) = @_;

    my $self = bless [], $class;
    $self->[DECK_DRAW]    = [];
    $self->[DECK_DISCARD] = [];

    if (@card) {
	$self->discard(@card);
	$self->shuffle;
    }

    return $self;
}

sub shuffle {
    @_ == 1 || badinvo;
    my ($self) = @_;

    $self->[DECK_DRAW] = [RS::Handy::shuffle
			    @{ $self->[DECK_DRAW] },
			    @{ $self->[DECK_DISCARD] }];
    $self->[DECK_DISCARD] = [];
}

sub draw {
    @_ == 1 || badinvo;
    my ($self) = @_;

    if (!@{ $self->[DECK_DRAW] }) {
	$self->shuffle;
	if (!@{ $self->[DECK_DRAW] }) {
	    xcroak "ran out of $Gem[$self->[DECK_GTYPE]] cards";
	}
    }

    return shift @{ $self->[DECK_DRAW] };
}

sub discard {
    @_ >= 2 || badinvo;
    my ($self, @card) = @_;

    push @{ $self->[DECK_DISCARD] }, @card;
}

1

__END__
