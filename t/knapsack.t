#!perl -w
use strict;

# $Id: knapsack.t,v 1.1 2012-09-23 01:14:25 roderick Exp $

use Game::Util				qw(knapsack_0_1);
use Game::ScepterOfZavandor::Constant	qw(/^[A-Z]/);
use Game::ScepterOfZavandor::Test;

create_standard_test_game;

# knapsack_0_1 ----------------------------------------------------------------

{

my @s = map { [$_ => $_] } qw(2 5 7 11 13 17 19 23) x 3;

sub test_knapsack_0_1 {
    my ($too_much, $max, $want_total_cost, $want_total_value, @want_cost) = @_;

    #print RS::Handy::data_dump \@s, sub { @$_ }, $max;
    my ($got_total_cost, $got_total_value, @got)
	= knapsack_0_1 \@s, sub {
    #print RS::Handy::data_dump \@_;
@{ +shift } }, $max, $too_much;
    #print RS::Handy::data_dump \@got;

    my @got_cost = map { $_->[0] } @got;
    my $desc     = "$max => want @want_cost got @got_cost";

    is         $got_total_cost,   $want_total_cost,  $desc;
    is         $got_total_value,  $want_total_value, $desc;
    is_deeply \@got_cost,        \@want_cost,        $desc;
}

test_knapsack_0_1 undef, 0 => 0, 0;
test_knapsack_0_1 undef, 1 => 0, 0;
test_knapsack_0_1 undef, 2 => 2, 2 => 2;
test_knapsack_0_1 undef, 3 => 2, 2 => 2;
test_knapsack_0_1 undef, 4 => 4, 4 => 2, 2;
test_knapsack_0_1 undef, 5 => 5, 5 => 5;
test_knapsack_0_1 undef, 6 => 6, 6 => 2, 2, 2;
test_knapsack_0_1 undef, 7 => 7, 7 => 7;
test_knapsack_0_1 undef, 8 => 7, 7 => 7;
test_knapsack_0_1 undef, 9 => 9, 9 => 2, 7;

# $cb_too_much->($this_cost, $max_cost, $this_value, $tot_value)

sub tm_max_val {
    my $max_val = shift;
    return sub { $_[0] > $_[1] || $_[2] + $_[3] > $max_val };
}

test_knapsack_0_1 tm_max_val(6), 0 => 0, 0;
test_knapsack_0_1 tm_max_val(6), 1 => 0, 0;
test_knapsack_0_1 tm_max_val(6), 2 => 2, 2 => 2;
test_knapsack_0_1 tm_max_val(6), 3 => 2, 2 => 2;
test_knapsack_0_1 tm_max_val(6), 4 => 4, 4 => 2, 2;
test_knapsack_0_1 tm_max_val(6), 5 => 5, 5 => 5;
test_knapsack_0_1 tm_max_val(6), 6 => 6, 6 => 2, 2, 2;
test_knapsack_0_1 tm_max_val(6), 7 => 6, 6 => 2, 2, 2;
test_knapsack_0_1 tm_max_val(6), 8 => 6, 6 => 2, 2, 2;
test_knapsack_0_1 tm_max_val(6), 9 => 6, 6 => 2, 2, 2;

test_knapsack_0_1 tm_max_val(7), 0 => 0, 0;
test_knapsack_0_1 tm_max_val(7), 1 => 0, 0;
test_knapsack_0_1 tm_max_val(7), 2 => 2, 2 => 2;
test_knapsack_0_1 tm_max_val(7), 3 => 2, 2 => 2;
test_knapsack_0_1 tm_max_val(7), 4 => 4, 4 => 2, 2;
test_knapsack_0_1 tm_max_val(7), 5 => 5, 5 => 5;
test_knapsack_0_1 tm_max_val(7), 6 => 6, 6 => 2, 2, 2;
test_knapsack_0_1 tm_max_val(7), 7 => 7, 7 => 7;
test_knapsack_0_1 tm_max_val(7), 8 => 7, 7 => 7;
test_knapsack_0_1 tm_max_val(7), 9 => 7, 7 => 7;

# simple dust creation sim -- any cost okay (here, 100), but not over value X
@s = map { [$_ => $_] } (2) x 10, (5) x 4, (10) x 2;
test_knapsack_0_1 tm_max_val( 0), 100 =>  0,  0;
test_knapsack_0_1 tm_max_val( 1), 100 =>  0,  0;
test_knapsack_0_1 tm_max_val( 2), 100 =>  2,  2 => 2;
test_knapsack_0_1 tm_max_val( 3), 100 =>  2,  2 => 2;
test_knapsack_0_1 tm_max_val( 4), 100 =>  4,  4 => 2, 2;
test_knapsack_0_1 tm_max_val( 5), 100 =>  5,  5 => 5;
test_knapsack_0_1 tm_max_val( 6), 100 =>  6,  6 => 2, 2, 2;
test_knapsack_0_1 tm_max_val( 7), 100 =>  7,  7 => 2, 5;
test_knapsack_0_1 tm_max_val( 8), 100 =>  8,  8 => 2, 2, 2, 2;
test_knapsack_0_1 tm_max_val( 9), 100 =>  9,  9 => 2, 2, 5;
test_knapsack_0_1 tm_max_val(10), 100 => 10, 10 => 10;
test_knapsack_0_1 tm_max_val(11), 100 => 11, 11 => 2, 2, 2, 5;
test_knapsack_0_1 tm_max_val(12), 100 => 12, 12 => 2, 10;
test_knapsack_0_1 tm_max_val(13), 100 => 13, 13 => 2, 2, 2, 2, 5;
test_knapsack_0_1 tm_max_val(14), 100 => 14, 14 => 2, 2, 10;
test_knapsack_0_1 tm_max_val(15), 100 => 15, 15 => 5, 10;
test_knapsack_0_1 tm_max_val(16), 100 => 16, 16 => 2, 2, 2, 10;
test_knapsack_0_1 tm_max_val(17), 100 => 17, 17 => 2, 5, 10;
test_knapsack_0_1 tm_max_val(18), 100 => 18, 18 => 2, 2, 2, 2, 10;
test_knapsack_0_1 tm_max_val(19), 100 => 19, 19 => 2, 2, 5, 10;
test_knapsack_0_1 tm_max_val(20), 100 => 20, 20 => 10, 10;

}

# ->enforce_hand_limit --------------------------------------------------------

sub enforce_and_test {
    my ($frames, $new_energy, $new_hand_count, @new_e) = @_;
    $Player->enforce_hand_limit;
    test_energy_and_count $frames + 1, $new_energy, $new_hand_count, @new_e;
}

discard_all_energy;
add_dust            17, 6 => 10, 5, 2;
enforce_and_test 0, 15, 5 => 10, 5;

discard_all_energy;
add_dust 14,  7 =>  2, 2, 2, 2, 2, 2, 2; enforce_and_test 0, 14, 5 => 10, 2, 2;
add_dust 28, 12 =>  2, 2, 2, 2, 2, 2, 2; enforce_and_test 0, 15, 5 => 10, 5;
add_dust 32, 11 => 10, 5, 2;             enforce_and_test 0, 15, 5 => 10, 5;
# test not-over case
enforce_and_test 0, 15, 5 => 10, 5;

discard_all_energy;
add_cards 36, 7 => GEM_SAPPHIRE, 5, 5, 5, 5, 5, 7, 4;
enforce_and_test 0, 27, 5 => 7, 5, 5, 5, 5;

discard_all_energy;
add_concentrated    20, 3 => GEM_SAPPHIRE;
add_concentrated    80, 6 => GEM_RUBY;
enforce_and_test 0, 65, 5 => 60, 5;

discard_all_energy;
add_concentrated    20, 3 => GEM_SAPPHIRE;
add_cards           25, 4 => GEM_SAPPHIRE, 5;
add_dust            35, 7 => 10;
enforce_and_test 0, 27, 5 => 20, 5, 2;

# prefer sapphire 7 to emerald 6

discard_all_energy;
add_concentrated    20, 3 => GEM_SAPPHIRE;
add_cards           35, 4 => GEM_RUBY,     15;
add_cards           42, 5 => GEM_SAPPHIRE,  7;
add_cards           48, 6 => GEM_EMERALD,   6;
enforce_and_test 0, 42, 5 => 20, 15, 7;

# prefer value 7 cards (ratio 7) to concentrated sapphire (ratio 6.6)

discard_all_energy;
add_cards           42, 6 => GEM_EMERALD, 7, 7, 7, 7, 7, 7;
add_concentrated    62, 9 => GEM_SAPPHIRE;
enforce_and_test 0, 35, 5 => 7, 7, 7, 7, 7;

# 10 dust (ratio 3.33) should be preferred to 3 sapphire cards (ratio 3)
# but I haven't implemented this yet.

discard_all_energy;
add_cards  9, 3 => GEM_SAPPHIRE, 3, 3, 3;
add_dust  19, 6 => 10;
#enforce_and_test 0, 15, 5 => 10, 5;
#enforce_and_test 0, undef, 5;
TODO: {
    local $TODO = "prefer 10 dust to 3x 3 sapphire cards";
    #is $Player->current_energy_liquid, 15;
    # XXX $TODO isn't working here
    enforce_and_test 0, 15, 5 => 10, 5;
}

# 2 2 2 shouldn't go to 5 if it'll lose you a dust unnecessarily

# XXX can't find a way to test this without disabling the test in
# ->enforce_hand_limit which causes it to do nothing if you aren't
# over limit

discard_all_energy;
add_dust            6, 3 => 2, 2, 2;
enforce_and_test 0, 6, 3;

#------------------------------------------------------------------------------

if (0) { # XXX doesn't work yet
# XXX better place for this
discard_all_energy;
add_dust 11, 6 => 2, 2, 2;
$Player->consolidate_dust;
# don't mistakenly consolidate 2 2 2 -> 5, losing a dust, when there's
# no 1 dust
test_energy_and_count 0, 6, 3, => 2, 2, 2;
}

# OPT_1_DUST ------------------------------------------------------------------

# XXX better place for this
create_standard_test_game OPT_1_DUST, 1;
discard_all_energy;
add_dust 11, 5 => 2, 2, 5, 2;
$Player->consolidate_dust;
test_energy_and_count 0, 11, 4, => 10, 1;

#------------------------------------------------------------------------------
