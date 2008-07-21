# $Id: Constant.pm,v 1.2 2008-07-21 16:20:46 roderick Exp $

use strict;

package Game::ScepterOfZavandor::Constant;

use base qw(Exporter);

use Game::Util		qw(add_array_indices debug);
use List::Util		qw(sum);
use List::MoreUtils	qw(minmax);
use RS::Handy		qw(badinvo data_dump dstr xcroak);

use vars qw($VERSION @EXPORT @EXPORT_OK);
BEGIN {
    $VERSION = q$Revision: 1.2 $ =~ /(\d\S+)/ ? $1 : '?';
    @EXPORT_OK = qw(
	$Base_hand_limit
	@Character
	%Character
	@Character_data
	@Config_by_num_players
	$Concentrated_card_count
	$Concentrated_additional_dust
	$Concentrated_hand_limit
	@Current_energy
	@Dust_data
	@Gem
	%Gem
	@Gem_data
	@Item_type
	%Item_type
	@Knowledge
	%Knowledge
	@Option
	%Option
    );
}
use subs grep { /^[a-z]/    } @EXPORT, @EXPORT_OK;
use vars grep { /^[\$\@\%]/ } @EXPORT, @EXPORT_OK;

BEGIN {
    @Character = qw(witch elf druid fairy mage kobold);
    %Character = map { $Character[$_] => $_ } 0..$#Character;
    add_array_indices 'CHAR', @Character;
    add_array_indices 'CHAR_DATA', (
    	'knowledge_track',
    	'start_dust',
	'start_items',
    );

    add_array_indices 'DUST_DATA', (
    	'value',
    	'hand_limit',
	'opal_count',
    );

    @Gem = qw(opal sapphire emerald diamond ruby);
    %Gem = map { $Gem[$_] => $_ } 0..$#Gem;
    add_array_indices 'GEM', @Gem;
    add_array_indices 'GEM_DATA', (
    	'cost',
	'vp',
    	'card_list',
    	'card_min',
    	'card_max',
    	'card_avg',
    	'concentrated',
    );

    @Item_type = qw(knowledge artifact sentinel gem card dust concentrated);
    %Item_type = map { $Item_type[$_] => $_ } 0..$#Item_type;
    add_array_indices 'ITEM_TYPE', @Item_type;

    @Knowledge = qw(gems eflow fire 9sages artifacts accum);
    %Knowledge = map { $Knowledge[$_] => $_ } 0..$#Knowledge;
    add_array_indices 'KNOW', @Knowledge;

    @Current_energy = ('total', 'liquid', 'active gems');
    add_array_indices 'CUR_ENERGY', @Current_energy;

    @Option = (
    	'1 dust',
    );
    %Option = map { $Option[$_] => $_ } 0..$#Option;
    add_array_indices 'OPT', @Option;
}

BEGIN {
    $Base_hand_limit              = 5;
    $Concentrated_card_count      = 4;
    $Concentrated_additional_dust = 2;
    $Concentrated_hand_limit      = 3;
}

BEGIN {
    my $i = CHAR_DATA_KNOWLEDGE_TRACK;
    $Character_data[CHAR_WITCH ][$i] = KNOW_GEMS;
    $Character_data[CHAR_ELF   ][$i] = KNOW_EFLOW;
    $Character_data[CHAR_DRUID ][$i] = KNOW_FIRE;
    $Character_data[CHAR_FAIRY ][$i] = KNOW_9SAGES;
    $Character_data[CHAR_MAGE  ][$i] = KNOW_ARTIFACTS;
    $Character_data[CHAR_KOBOLD][$i] = KNOW_ACCUM;

    $i = CHAR_DATA_START_DUST;
    $Character_data[CHAR_WITCH ][$i] = 10;
    $Character_data[CHAR_ELF   ][$i] = 10;
    $Character_data[CHAR_DRUID ][$i] = 20;
    $Character_data[CHAR_FAIRY ][$i] = 10;
    $Character_data[CHAR_MAGE  ][$i] = 15;
    $Character_data[CHAR_KOBOLD][$i] = 20;

    $i = CHAR_DATA_START_ITEMS;
    $Character_data[CHAR_WITCH ][$i] = \&start_items_common;
    $Character_data[CHAR_ELF   ][$i] = \&start_items_common;
    $Character_data[CHAR_DRUID ][$i] = \&start_items_common;
    $Character_data[CHAR_FAIRY ][$i] = sub {
    	(start_items_common(@_), $_[0]->draw_from_deck(GEM_SAPPHIRE, 2)) };
    $Character_data[CHAR_MAGE  ][$i] = \&start_items_common;
    $Character_data[CHAR_KOBOLD][$i] = \&start_items_common;
}

BEGIN {
    # XXX 1-dust via options
    for ([10 => 3, 3], [5 => 2, 2], [2 => 1, 1], [1 => 1]) {
    	my ($v, $hl, $opal_count) = @$_;
    	my $r = [];
	$r->[DUST_DATA_VALUE]      = $v;
	$r->[DUST_DATA_HAND_LIMIT] = $hl;
	$r->[DUST_DATA_OPAL_COUNT] = $opal_count;
	push @Dust_data, $r;
    }
}

# 126 energy cards
#
# Opal     (28) Dust 2/5/10/...
# Sapphire (28) Card  3-7  20+2  5   20 1 -
# Emerald  (24) Card  5-10 30+2  7.5 30 2 Spellbook
# Diamond  (24) Card  8-12 40+2 10   40 2 Elixir
# Ruby     (20) Card 13-17 60+2 15   60 3 Knowledge of Fire

BEGIN {
    $Gem_data[GEM_OPAL    ][GEM_DATA_VP] = 1;
    $Gem_data[GEM_SAPPHIRE][GEM_DATA_VP] = 1;
    $Gem_data[GEM_EMERALD ][GEM_DATA_VP] = 2;
    $Gem_data[GEM_DIAMOND ][GEM_DATA_VP] = 2;
    $Gem_data[GEM_RUBY    ][GEM_DATA_VP] = 3;

    $Gem_data[GEM_OPAL    ][GEM_DATA_COST] = 10;
    $Gem_data[GEM_SAPPHIRE][GEM_DATA_COST] = 20;
    $Gem_data[GEM_EMERALD ][GEM_DATA_COST] = 30;
    $Gem_data[GEM_DIAMOND ][GEM_DATA_COST] = 40;
    $Gem_data[GEM_RUBY    ][GEM_DATA_COST] = 60;

    my $i = GEM_DATA_CARD_LIST;
    $Gem_data[GEM_SAPPHIRE][$i] = [( 3, 7)x3,( 4, 6)x6,( 5  )x12];
    $Gem_data[GEM_EMERALD ][$i] = [( 5,10)x3,( 6, 9)x6,( 7,8)x 9];
    $Gem_data[GEM_DIAMOND ][$i] = [( 8,12)x3,( 9,11)x6,(10  )x12];
    $Gem_data[GEM_RUBY    ][$i] = [(13,17)x3,(14,16)x6,(15  )x12];

    # derive values from card distributions

    my $tot = 0;
    for my $gi (0..$#Gem_data) {
    	my $r = $Gem_data[$gi];
	my $rcard_list = $r->[GEM_DATA_CARD_LIST];
	next unless $rcard_list;

	my $ct = scalar @$rcard_list;
	$tot += $ct;
    	my ($min, $max) = minmax @$rcard_list;
	my $avg = sum(@$rcard_list) / $ct;
	my $conc = int($avg * $Concentrated_card_count);
	debug sprintf "%-8s min %2d max %2d avg %5.2f conc %2d",
	    $Gem[$gi], $min, $max, $avg, $conc;

	$r->[GEM_DATA_CARD_MIN    ] = $min;
	$r->[GEM_DATA_CARD_MAX    ] = $max;
	$r->[GEM_DATA_CARD_AVG    ] = $avg;
	$r->[GEM_DATA_CONCENTRATED] = $conc;
    }
    $tot == 126 or die;
}

BEGIN {
   # XXX
   @Config_by_num_players = (
    	undef, # 0
    	[], # XXX undef, # 1
    	[], # 2
    	[], # 3
    	[], # 4
    	[], # 5
    	[], # 6
    );
}

#------------------------------------------------------------------------------

sub start_items_common {
    my ($game, $char) = @_;

    my @i;

    require Game::ScepterOfZavandor::Item::Gem;
    for (GEM_OPAL, GEM_OPAL, GEM_SAPPHIRE) {
    	push @i, Game::ScepterOfZavandor::Item::Gem->new($_, $game);
    }

    push @i, Game::ScepterOfZavandor::Item::Energy::Dust->make_dust(
    	    	$Character_data[$char][CHAR_DATA_START_DUST]);

    # XXX knowledge

    return @i;
}

1



    # XXX druid ruby at level 3
