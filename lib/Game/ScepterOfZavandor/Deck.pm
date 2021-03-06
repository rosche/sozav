use strict;

package Game::ScepterOfZavandor::Deck;

use base qw(Game::Util::Deck);

use overload (
    '""'  => "as_string",
);

use Game::Util	qw($Debug add_array_indices debug make_ro_accessor);
use List::Util	qw(sum);
use RS::Handy	qw(badinvo data_dump dstr xconfess);

use Game::ScepterOfZavandor::Constant qw(
    /^ENERGY_EST_/
    /^GAME_GEM_DATA_/
    /^GEM_/
    /^OPT_/
    @Gem
    @Gem_data
);
use Game::ScepterOfZavandor::Item::Energy ();

BEGIN {
    add_array_indices 'DECK', 'GAME';
    add_array_indices 'DECK', 'GTYPE';
}

sub new {
    @_ == 3 || badinvo;
    my ($class, $game, $gtype) = @_;

    my $self = $class->SUPER::new;

    $self->[DECK_GAME ] = $game;
    $self->[DECK_GTYPE] = $gtype;

    my $card_list_ix = $self->a_game->option(OPT_LOWER_VARIANCE)
			? GEM_DATA_CARD_LIST_LESS_VARIANT
			: GEM_DATA_CARD_LIST_NORMAL;
    $Gem_data[$gtype] or xconfess 1;
    $Gem_data[$gtype][$card_list_ix] or xconfess 2;
    my @card_val = @{ $Gem_data[$gtype][$card_list_ix] };

    if ($self->a_game->option(OPT_AVERAGED_CARDS)) {
	my $real_avg = sum(@card_val) / @card_val;
	my $int_avg  = int $real_avg;

	debug "$Gem[$gtype] card real average $real_avg";

	# average for emeralds is 7.5, so toggle between 7 and 8
	my $toggle = $real_avg > $int_avg ? 1 : 0;

	for (0..$#card_val) {
	    $card_val[$_] = $int_avg + ($_ % 2 ? $toggle : 0);
	}
    }

    my @card =
	map { Game::ScepterOfZavandor::Item::Energy::Card->new($self, $_) }
	    @card_val;

    # XXX have to recompute card min, max, average here

    $self->discard(@card);
    $self->shuffle;

    if ($Debug > 2) {
	print "$Gem[$gtype] draw deck:\n";
	print "$_\n" for @{ $self->[0] };
	if (my @d = @{ $self->[1] }) {
	    print "$Gem[$gtype] discard deck:\n";
	    print "$_\n" for @d;
	}
    }
    elsif ($Debug > 1) {
	print "$self\n";
    }

    return $self;
}

make_ro_accessor (
    a_game     => DECK_GAME,
    a_gem_type => DECK_GTYPE,
);

sub as_string {
    @_ == 3 || badinvo;
    my $self = shift;

    return sprintf "deck-%s(draw=[%s] discard=[%s])",
	    $Gem[$self->a_gem_type],
	    join(" ", map { $_->energy } $self->draw_deck_items),
	    join(" ", map { $_->energy } $self->discard_deck_items);
}

sub draw {
    @_ || badinvo;
    my $self = shift;

    my @r = $self->SUPER::draw(@_);
    if (!defined $r[-1]) {
	# XXX find out what's supposed to happen
	xconfess "ran out of $Gem[$self->a_gem_type] cards";
    }

    return @r == 1 ? $r[0] : @r;
}

sub discard_outliers {
    @_ == 1 || badinvo;
    my $self = shift;

    my $gem_data = $self->a_game->gem_data($self->a_gem_type);
    my $min = $gem_data->[GAME_GEM_DATA_CARD_MIN];
    my $max = $gem_data->[GAME_GEM_DATA_CARD_MAX];

    my @new;
    while (my $c = $self->draw_1_no_shuffle) {
	if ($c->energy == $min || $c->energy == $max) {
	    $self->discard($c);
	}
	else {
	    push @new, $c;
	}
    }
    $self->push(@new)
        if @new;

    debug "deck after discarding outliers: $self";
}

sub energy_estimate {
    @_ == 1 || badinvo;
    my $self = shift;

    my $gtype = $self->a_gem_type;
    my $gdata = $self->a_game->gem_data($gtype);

    my @ee;
    $ee[ENERGY_EST_MIN] = $gdata->[GAME_GEM_DATA_CARD_MIN];
    $ee[ENERGY_EST_AVG] = $gdata->[GAME_GEM_DATA_CARD_AVG];
    $ee[ENERGY_EST_MAX] = $gdata->[GAME_GEM_DATA_CARD_MAX];

    return @ee;
}

1
