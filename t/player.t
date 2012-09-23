#!perl -w
use strict;

# $Id: player.t,v 1.1 2012-09-23 01:14:25 roderick Exp $

use Game::Util				qw(knapsack_0_1);
use Game::ScepterOfZavandor::Constant	qw(/^[A-Z]/);
use Game::ScepterOfZavandor::Test;

# without 1 dust --------------------------------------------------------------

create_standard_test_game;

discard_all_energy;
add_dust 6, 3 => 2, 2, 2;
# don't mistakenly consolidate 2 2 2 -> 5, losing a dust, when there's
# no 1 dust
$Player->consolidate_dust;
test_energy_and_count 0, 6, 3, => 2, 2, 2;

# OPT_1_DUST ------------------------------------------------------------------

create_standard_test_game OPT_1_DUST, 1;

discard_all_energy;
add_dust 11, 5 => 2, 2, 5, 2;
$Player->consolidate_dust;
test_energy_and_count 0, 11, 4, => 10, 1;

#------------------------------------------------------------------------------
