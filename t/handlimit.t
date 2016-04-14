#!perl -w
use strict;

use Game::Util				qw(knapsack_0_1);
use Game::ScepterOfZavandor::Constant	qw(/^[A-Z]/);
use Game::ScepterOfZavandor::Test;
use RS::Handy				qw(shuffle);

*TODO = \$Test::More::TODO;

create_standard_test_game;

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
add_cards           26, 4 => GEM_EMERALD,   6;
add_cards           33, 5 => GEM_SAPPHIRE,  7;
add_cards           48, 6 => GEM_RUBY,     15;
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
is $Player->current_energy_liquid, 19;
TODO: {
    local $TODO = "prefer 10 dust to 3x 3 sapphire cards";
    # XXX $TODO isn't working here
    #enforce_and_test 0, 15, 5 => 10, 5;
}

#------------------------------------------------------------------------------
