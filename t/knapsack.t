#!perl -w
use strict;

use Game::Util				qw(knapsack_0_1);
use Game::ScepterOfZavandor::Constant	qw(/^[A-Z]/);
use Game::ScepterOfZavandor::Test;
use RS::Handy				qw(shuffle);

*TODO = \$Test::More::TODO;

create_standard_test_game;

# knapsack_0_1 ----------------------------------------------------------------

{

my @s = map { [$_ => $_] } qw(2 5 7 11 13 17 19 23) x 3;

sub test_knapsack_0_1 {
    my ($max_cost, $want_total_cost, $want_total_value, @want_cost) = @_;

    my ($got_total_cost, $got_total_value, @got)
	= knapsack_0_1 \@s, sub { @{ +shift } }, $max_cost;
    #print RS::Handy::data_dump \@got;

    my @got_cost = map { $_->[0] } @got;
    my $desc     = "$max_cost => want @want_cost got @got_cost";

    is         $got_total_cost,   $want_total_cost,  $desc;
    is         $got_total_value,  $want_total_value, $desc;
    is_deeply \@got_cost,        \@want_cost,        $desc;
}

test_knapsack_0_1 0 => 0, 0;
test_knapsack_0_1 1 => 0, 0;
test_knapsack_0_1 2 => 2, 2 => 2;
test_knapsack_0_1 3 => 2, 2 => 2;
test_knapsack_0_1 4 => 4, 4 => 2, 2;
test_knapsack_0_1 5 => 5, 5 => 5;
test_knapsack_0_1 6 => 6, 6 => 2, 2, 2;
test_knapsack_0_1 7 => 7, 7 => 2, 5;
test_knapsack_0_1 8 => 7, 7 => 2, 5;
test_knapsack_0_1 9 => 9, 9 => 2, 7;

}

# knapsack_0_1 efficiency -----------------------------------------------------

# example is from Rosetta Code
# https://rosettacode.org/wiki/Knapsack_problem/0-1#Perl

{
    my $max_cost = 400;
    my $max_time_secs = 5;

    my $raw = <<'TABLE';
        anvil			500	 5
        map			9	150
        compass			13	35
        water			153	200
        sandwich		50	160
        glucose			15	60
        tin			68	45
        banana			27	60
        apple			39	40
        cheese			23	30
        beer			52	10
        suntancream		11	70
        camera			32	30
        T-shirt			24	15
        trousers		48	10
        umbrella		73	40
        waterproof trousers	42	70
        waterproof overclothes	43	75
        note-case		22	80
        sunglasses		7	20
        towel			18	12
        socks			4	50
        book			30	10
TABLE

    my @item;
    for (split "\n", $raw) {
        s/^\s+//;
        push @item, [split /\t+/];
    }
    my $start_time = time;
    my ($tot_cost, $tot_value, @ans)
        = knapsack_0_1 \@item, sub { @{ shift @_ }[1, 2] }, $max_cost;
    my $secs = time - $start_time;
    my @ans_name = sort map { $_->[0] } @ans;
    ok $secs <= $max_time_secs, "calculation time ($secs) <= $max_time_secs";
    is_deeply \@ans_name, [
        'banana',
        'compass',
        'glucose',
        'map',
        'note-case',
        'sandwich',
        'socks',
        'sunglasses',
        'suntancream',
        'water',
        'waterproof overclothes',
        'waterproof trousers',
    ], "long test result";
}

#------------------------------------------------------------------------------
