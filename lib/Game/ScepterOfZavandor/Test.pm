use strict;

package Game::ScepterOfZavandor::Test;

use base qw(Test::More);

use Game::ScepterOfZavandor::Constant
		qw(/^[A-Z]/);
use RS::Handy	qw(badinvo data_dump dstr process_arg_pairs
		    subcall_info xconfess);
use Test::More	qw(no_plan);

use vars qw($VERSION @EXPORT @EXPORT_OK);
BEGIN {
    $VERSION = 'XXX';
    @EXPORT = qw(
	$Game
	$Player
	add_cards
	add_concentrated
	add_dust
	add_energy
	create_standard_test_game
	create_dust
	create_test_game
	discard_all_energy
	test_energy_and_count
    );

    push @EXPORT, @Test::More::EXPORT;

    $SIG{__WARN__} = sub { xconfess @_ };
#    for (qw(is fail)) {
#	no strict 'refs';
#	*$_ = \&{ "Test::More::$_" };
#    }
}
use subs grep { /^[a-z]/    } @EXPORT, @EXPORT_OK;
use vars grep { /^[\$\@\%]/ } @EXPORT, @EXPORT_OK;

#my $Base = "Game::ScepterOfZavandor";
#
#sub import {
#    @_ || badinvo;
#    my ($class) = shift;
#
#    for my $pkg_part (@_) {
#	my $full_class = "${Base}::${pkg_part}";
#
#	my $req_class = $full_class;
#	$req_class =~ s/(::Energy)::.*/$1/;
#	eval "require $req_class";
#	die if $@;
#
#	no strict 'refs';
#	*{ "SoZ::${pkg_part}::" } = \%{ "${full_class}::" };
#    }
#}

#------------------------------------------------------------------------------

sub create_test_game {
    process_arg_pairs \@_, (
	num_players => \(my $num_players = 1),
	rwant_char  => \my $rwant_char,
    );

    my @want_char = $rwant_char ? @$rwant_char : ();

    require Game::ScepterOfZavandor::Game;
    require Game::ScepterOfZavandor::UI::Test;

    my $g = Game::ScepterOfZavandor::Game->new
	or xconfess;
    $g->option(OPT_CHOOSE_CHARACTER, 1)
	if @want_char;

    my @p;
    for (1 .. $num_players) {
	my $ui = Game::ScepterOfZavandor::UI::Test->new($g);
	$ui->a_want_char(shift @want_char);
	push @p, Game::ScepterOfZavandor::Player->new($g, $ui, undef);
	$g->add_player($p[-1]);
    }

    return wantarray ? ($g, $p[0]) : $g;
}

sub create_standard_test_game {
    ($Game, $Player) = Game::ScepterOfZavandor::Test::create_test_game (
	num_players => 1,
	rwant_char  => [CHAR_DRUID],
    );
    while (@_) {
	$Game->option(splice @_, 0, 2);
    }
    $Game->init;
}

sub discard_all_energy {
    $Player->remove_items(grep { $_->is_energy } $Player->items);
    is $Player->current_hand_count, 0;
}

sub test_energy_and_count {
    my ($frames, $new_energy, $new_hand_count, @new_e) = @_;

    my $desc = subcall_info $frames;
    #my @e    = grep { $_->is_energy } $Player->items;
    #my $desc = "items=[@e] " . subcall_info $frames;
    my @e = sort { $b <=> $a }
		map { $_->is_energy ? $_->energy : () }
		    $Player->items;

    is $Player->current_energy_liquid, $new_energy,	$desc
	if defined $new_energy;
    is $Player->current_hand_count,    $new_hand_count,	$desc
	if defined $new_hand_count;
    is_deeply \@e,			\@new_e,
	    "$desc \@new_e=[@new_e] \@e=[@e]"
	if @new_e;
}

# XXX take @new_e to pass to test_energy_and_count
sub add_energy {
    my ($frames, $new_energy, $new_hand_count, @e) = @_;
    $Player->add_items(@e);
    test_energy_and_count $frames + 1, $new_energy, $new_hand_count;
}

sub add_dust {
    my ($new_energy, $new_hand_count, @e) = @_;
    add_energy 1, $new_energy, $new_hand_count, map { create_dust $_ } @e;
}

# XXX take @new_e to pass to test_energy_and_count
sub add_cards {
    my ($new_energy, $new_hand_count, $gtype, @value) = @_;

    for my $value (@value) {
	my $tries = 0;
	while (1) {
	    my $card = $Game->draw_from_deck($gtype, 1);
	    if ($card->energy == $value) {
		$Player->add_items($card);
		last;
	    }
	    $card->use_up;
	    if ($tries++ > 100) {
		fail "can't find card gtype=$gtype value=$value "
			. subcall_info;
		last;
	    }
	}
    }
    test_energy_and_count 1, $new_energy, $new_hand_count;
}

sub add_concentrated {
    my ($new_energy, $new_hand_count, $gtype, $count) = @_;
    $count ||= 1;
    add_energy 1, $new_energy, $new_hand_count,
	map {
	    Game::ScepterOfZavandor::Item::Energy::Concentrated
		->new($Player, $gtype)
	} 1..$count;
}

sub create_dust {
    my ($val) = @_;
    return Game::ScepterOfZavandor::Item::Energy::Dust
		->make_dust($Player, $val);
}

1
