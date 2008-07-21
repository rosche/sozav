# $Id: Player.pm,v 1.2 2008-07-21 16:07:15 roderick Exp $

use strict;

package Game::ScepterOfZavandor::Player;

use List::Util	qw(sum);
use Game::Util  qw($Debug add_array_indices debug make_rw_accessor);
use RS::Handy	qw(badinvo data_dump dstr xcroak);
use Scalar::Util qw(refaddr);

use Game::ScepterOfZavandor::Constant qw(
    /^CHAR_/
    /^CUR_ENERGY_/
    /^GEM_/
    @Character
    @Character_data
    $Concentrated_card_count
    $Concentrated_additional_dust
    @Current_energy
    @Gem_data
);

BEGIN {
    add_array_indices 'PLAYER', qw(GAME UI CHAR ITEM);
}

# - items are sub of item class which has default methods which do nothing
# - items are kept in lists by type
# - get_items method returns all items from all lists
# - when doing something iterate through items offering each of them the
#   opportunity to modify it
#     - need to know discount on an item when bidding so you know how
#       high you can bid

sub new {
    @_ == 3 || badinvo;
    my ($class, $game, $ui) = @_;

    $ui or die;

    my $self = bless [], $class;
    $self->a_game($game);
    $self->a_ui($ui);
    $ui->a_player($self); # XXX circular reference

    return $self;
}

make_rw_accessor (
    a_game => PLAYER_GAME,
    a_ui   => PLAYER_UI,
    a_char => PLAYER_CHAR,
);

sub init {
    @_ == 3 || badinvo;
    my ($self, $game, $char) = @_;

    $self->a_char($char);
    $self->[PLAYER_ITEM] = [];

    $self->add_items(
    	$Character_data[$char][CHAR_DATA_START_ITEMS]->($game, $char));
    for ($self->gems) {
	$_->activate;
    }

    debug "$Character[$char] items ", join " ", $self->items;
}

#------------------------------------------------------------------------------

# XXX standard list accessors?

sub add_items {
    @_ || badinvo;
    my ($self, @item) = @_;

    for (@item) {
    	$_ or die;
	debug "$Character[$self->[PLAYER_CHAR]] add item $_";
	push @{ $self->[PLAYER_ITEM] }, $_;
    }
}

sub items {
    @_ == 1 || badinvo;

    return @{ $_[0]->[PLAYER_ITEM] };
}

sub name {
    @_ == 1 || badinvo;

    return $Character[$_->[PLAYER_CHAR]];
}

sub gems {
    @_ == 1 || badinvo;
    my $self = shift;
    return grep { $_->is_gem } $self->items;
}

sub remove_items {
    @_ || badinvo;
    my ($self, @remove_item) = @_;

    debug "remove @remove_item";

    my @old = $self->items;
    my @new;
    for my $old ($self->items) {
	push @new, $old
	    unless grep { refaddr($old) == refaddr($_) } @remove_item;
    }

    if (@new + @remove_item != @old) {
	die "remove_items missing something",
	    "\n",
	    "(new=", 0+@new, " old=", 0+@old, ")\n",
	    "new: @new\n",
	    "old: @old\n";
    }

    for (@remove_item) {
	debug "$Character[$self->[PLAYER_CHAR]] remove item $_";
    }

    $self->[PLAYER_ITEM] = \@new;
}

sub current_energy {
    @_ == 1 || badinvo;
    my $self = shift;

    # unused gems

    my @e = (0) x @Current_energy;

    for my $i ($self->items) {
	my $this_e = $i->energy;
	next unless $this_e;

    	$e[CUR_ENERGY_TOTAL] += $this_e;
    	$e[($i->is_gem && $i->active)
    	    	? CUR_ENERGY_ACTIVE_GEMS
    	    	: CUR_ENERGY_LIQUID] += $this_e;
    }

    return @e;
}

sub current_energy_liquid {
    @_ == 1 || badinvo;
    my $self = shift;
    return ($self->current_energy)[CUR_ENERGY_LIQUID];
}

sub current_hand_count {
    @_ == 1 || badinvo;
    my $self = shift;
    return sum map { $_->a_hand_limit } $self->items;
}

#------------------------------------------------------------------------------

sub buy_gem {
    @_ == 2 || badinvo;
    my $self = shift;
    my ($gtype) = @_;

    my $cost = $self->gem_cost($gtype);
    my $cash  = $self->current_energy_liquid;
    if ($cost > $cash) {
    	die "not enough liquid cash";
    }

    # XXX test you're allowed can make

    my $g = Game::ScepterOfZavandor::Item::Gem->new($gtype, $self->a_game);
    $self->pay_energy($cost);
    $self->add_items($g);

    return $g;
}

sub gain_energy {
    @_ == 1 || badinvo;
    my $self = shift;

    # gain energy from non-gems, save gems to process below

    my %gem;
    for my $i ($self->items) {
    	if ($i->is_gem) {
	    push @{ $gem{$i->a_gem_type} }, $i
		if $i->is_active;
	}
	else {
	    $self->add_items($i->produce_energy);
	}
    }

    # opals

    if (my $ro = delete $gem{+GEM_OPAL}) {
    	debug 0+@$ro, " opals" if $Debug > 1;
	$self->add_items(
	    Game::ScepterOfZavandor::Item::Energy::Dust->make_dust_from_opals(
	    	scalar @$ro));
    }

    # other gems

    for my $gtype (keys %gem) {
	my @g = @{ $gem{$gtype} };
	while (@g >= $Concentrated_card_count) {
	    splice @g, 0, $Concentrated_card_count;
	    $self->add_items(
		Game::ScepterOfZavandor::Item::Energy::Concentrated->new(
    	    	    $gtype),
		Game::ScepterOfZavandor::Item::Energy::Dust->make_dust(
    	    	    $Concentrated_additional_dust));
    	}
	$self->add_items(map { $_->produce_energy } @g);
    }
}

sub gem_cost {
    my $self = shift;
    my $gtype = shift;

    my $cost = $Gem_data[$gtype][GEM_DATA_COST];
    # XXX knowledge of gems
    return $cost;
}

sub gem_value {
    @_ == 2 || badinvo;
    my $self = shift;
    my $gtype = shift;

    my $cost = $self->gem_cost($gtype);
    return int($cost / 2);
}

sub pay_energy {
    @_ == 2 || badinvo;
    my $self = shift;
    my $tot  = shift;

    # XXX allow UI to say what to pay with, on general pricinple and
    # more realistically because you might want to sell gems early
    # knowing you'll be going up the gem track

    $tot > 0 or die;

    # XXX proper algorithm for choosing what to pay with

    my @to_use;
    for my $i (sort { $a <=> $b } grep { $_->is_energy } $self->items) {
	my $v = $i->a_value;
	push @to_use, $i;
	$tot -= $v;
	last if $tot <= 0;
    }

    if ($tot > 0) {
    	die "short by $tot energy";
    }

    for (@to_use) {
	$_->use_up;
    }
    $self->remove_items(@to_use);
    $self->add_items(
	    Game::ScepterOfZavandor::Item::Energy::Dust->make_dust(0 - $tot))
	if $tot < 0;
}

#------------------------------------------------------------------------------

sub actions {
    @_ == 1 || badinvo;
    my $self = shift;

    while ($self->a_ui->one_action) {
	;
    }
}

1

__END__

- method ->can_produce_card for 9 sages
