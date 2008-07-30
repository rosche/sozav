# $Id: Constant.pm,v 1.9 2008-07-30 15:45:27 roderick Exp $

use strict;

package Game::ScepterOfZavandor::Constant;

use base qw(Exporter);

use Game::Util		qw(add_array_indices debug);
use List::Util		qw(sum);
use List::MoreUtils	qw(minmax);
use RS::Handy		qw(badinvo data_dump dstr xcroak);

use vars qw($VERSION @EXPORT @EXPORT_OK);
BEGIN {
    $VERSION = q$Revision: 1.9 $ =~ /(\d\S+)/ ? $1 : '?';
    @EXPORT_OK = qw(
	$Base_gem_slots
	$Base_hand_limit
	@Artifact
    	%Artifact
	@Artifact_data
	@Artifact_data_field
	@Auctionable
	%Auctionable
	@Auctionable_data_field
	@Character
	%Character
	@Character_data
	@Config_by_num_players
	$Concentrated_card_count
	$Concentrated_additional_dust
	$Concentrated_hand_count
	@Current_energy
	@Dust_data
	$Dust_data_val_1
	$Game_end_sentinels_sold_count
	@Gem
	%Gem
	@Gem_data
	@Item_type
	%Item_type
	@Knowledge
	%Knowledge
	@Knowledge_chip_cost
	@Knowledge_data
	$Knowledge_9sages_card_count
	$Knowledge_top_vp
	@Option
	%Option
	@Sentinel
	@Sentinel_real_ix_xxx
    	%Sentinel
	@Sentinel_data
	@Sentinel_data_field
	@Turn_order
	@Turn_order_data
    );
}
use subs grep { /^[a-z]/    } @EXPORT, @EXPORT_OK;
use vars grep { /^[\$\@\%]/ } @EXPORT, @EXPORT_OK;

BEGIN {
    @Character = qw(witch elf druid fairy mage kobold);
    %Character = map { $Character[$_] => $_ } 0..$#Character;
    add_array_indices 'CHAR', @Character;
    add_array_indices 'CHAR_DATA', (
    	'KNOWLEDGE_TRACK',
    	'START_DUST',
	'START_ITEMS',
    );

    @Current_energy = (
    	'total',		# total = liquid + active gems
	    'liquid',		# liquid = cards+dust + inactive gems
		'cards+dust',	# XXY better name
		'inactive gems',
	    'active gems',
    	'min',			# publically visible minimum
    	'max',			# publically visible maximum
    	'avg',			# publically visible average
    );
    add_array_indices 'CUR_ENERGY', @Current_energy;

    add_array_indices 'DUST_DATA', (
    	'VALUE',
    	'HAND_COUNT',
	'OPAL_COUNT',
    );

    @Gem = qw(opal sapphire emerald diamond ruby);
    %Gem = map { $Gem[$_] => $_ } 0..$#Gem;
    add_array_indices 'GEM', @Gem;
    add_array_indices 'GEM_DATA', (
    	'COST',
	'VP',
	'LIMIT',
    	'CARD_LIST',
    	'CARD_MIN',
    	'CARD_MAX',
    	'CARD_AVG',
    	'CONCENTRATED',
    );

    @Item_type = qw(turn_order knowledge sentinel artifact gem
		    concentrated card dust);
    %Item_type = map { $Item_type[$_] => $_ } 0..$#Item_type;
    add_array_indices 'ITEM_TYPE', @Item_type;

    @Knowledge = qw(gems eflow fire 9sages artifacts accum);
    %Knowledge = map { $Knowledge[$_] => $_ } 0..$#Knowledge;
    add_array_indices 'KNOW', @Knowledge;
    add_array_indices 'KNOW_DATA', qw(
	NAME
    	HAND_LIMIT
    	LEVEL_COST
	DETAIL
    );

    @Option = (
    	'1 dust',
    );
    %Option = map { $Option[$_] => $_ } 0..$#Option;
    add_array_indices 'OPT', @Option;

    # XXX indices overlap

    @Artifact = (
	'Crystal Ball',
	'Runestone',
	'Spellbook',
	'Magic Belt',
	'Magic Mirror',
	'Elixir',
	'Crystal of Protection',
	'Mask of Charisma',
	'Magic Wand',
	'Chalice of Fire',
	'Shadow Cloak',
	'Talisman',
    );
    %Artifact = map { $Artifact[$_] => $_ } 0..$#Artifact;
    add_array_indices 'ARTI', @Artifact;

    @Sentinel = ((undef) x @Artifact, qw(
	Phoenix
	Owl
	Fox
	Toad
	Unicorn
	Tomcat
	Scarab
	Raven
	Salamander
    ));
    @Sentinel_real_ix_xxx = grep { defined $Sentinel[$_] } 0..$#Sentinel;
    %Sentinel = map { $Sentinel[$_] => $_ } @Sentinel_real_ix_xxx;
    #XXX add_array_indices 'SENT', @Sentinel;
    push @EXPORT_OK, RS::Handy::create_index_subs 'SENT', undef, @Sentinel;

    # XXX
    @Auctionable = (@Artifact, @Sentinel[@Sentinel_real_ix_xxx]);
    %Auctionable = map { $Auctionable[$_] => $_ } 0..$#Auctionable;
    add_array_indices 'AUC', @Auctionable;

    @Auctionable_data_field = (
	'NAME',
	'MIN_BID',
	'VP',
    );
    add_array_indices 'AUC_DATA', @Auctionable_data_field;

    @Artifact_data_field = (
    	@Auctionable_data_field,
	'DECK_LETTER',			# A-D
	'COST_MOD_ARTIFACT',		# artifact you get a cost_mod on
	'COST_MOD_ARTIFACT_AMOUNT',	# cost_mod of N on specified artifact
	'COST_MOD_SENTINELS',		# cost_mod of N on sentinels
	'OWN_ONLY_ONE',			# can only own 1 of these
	'KNOWLEDGE_CHIP',		# stage N knowledge chips
	'ADVANCE_KNOWLEDGE',		# advance N knowledge stages
	'GEM_SLOTS',			# add N gem slots
    	'HAND_LIMIT',			# add N to hand limit
	'CAN_BUY_GEM',			# you can by gem type GTYPE
    	'FREE_GEM',			# you get a free gem of type GTYPE
	'GEM_ENERGY_PRODUCTION',	# produces an energy card of type GTYPE
	'DESTROY_GEM',			# destroy N gems of each other player
    );
    add_array_indices 'ARTI_DATA', @Artifact_data_field;

    @Sentinel_data_field = (
    	@Auctionable_data_field,
	'MAX_BONUS_VP',
	'VP_PER',
	'BONUS_GEM',
	'BONUS_AUC_TYPE',
    );
    add_array_indices 'SENT_DATA', @Sentinel_data_field;

    @Turn_order = (1..6);
    add_array_indices 'TURN', @Turn_order;
    add_array_indices 'TURN_DATA', qw(
    	NAME
	ACTIVE_IF_MY_VP_GE
	ACTIVE_IF_ANY_VP_GE
    	ARTIFACT_COST_MOD
    	SENTINEL_COST_MOD
    );
}

BEGIN {
    $Base_gem_slots                = 5;
    $Base_hand_limit               = 5;
    $Concentrated_card_count       = 4;
    $Concentrated_additional_dust  = 2;
    $Concentrated_hand_count       = 3;
    $Game_end_sentinels_sold_count = 5;
    @Knowledge_chip_cost           = qw(20 25 30 35 40);
    $Knowledge_9sages_card_count   = 2;
    $Knowledge_top_vp              = 2;
}

BEGIN {
    my $i;

    for (0..$#Turn_order) {
	$Turn_order_data[$_][TURN_DATA_NAME]                = $_ + 1;
	$Turn_order_data[$_][TURN_DATA_ARTIFACT_COST_MOD]   = 0;
	$Turn_order_data[$_][TURN_DATA_SENTINEL_COST_MOD]   = 0;
    }

    $Turn_order_data[TURN_1][TURN_DATA_ACTIVE_IF_MY_VP_GE]  =  10;
    $Turn_order_data[TURN_1][TURN_DATA_ARTIFACT_COST_MOD]   =  10;
    $Turn_order_data[TURN_1][TURN_DATA_SENTINEL_COST_MOD]   =  20;

    $Turn_order_data[TURN_2][TURN_DATA_ACTIVE_IF_MY_VP_GE]  =  10;
    $Turn_order_data[TURN_2][TURN_DATA_ARTIFACT_COST_MOD]   =   5;
    $Turn_order_data[TURN_2][TURN_DATA_SENTINEL_COST_MOD]   =  10;

    $Turn_order_data[TURN_5][TURN_DATA_ACTIVE_IF_ANY_VP_GE] =  10;
    $Turn_order_data[TURN_5][TURN_DATA_ARTIFACT_COST_MOD]   =  -5;
    $Turn_order_data[TURN_5][TURN_DATA_SENTINEL_COST_MOD]   = -10;

    $Turn_order_data[TURN_6][TURN_DATA_ACTIVE_IF_ANY_VP_GE] =  10;
    $Turn_order_data[TURN_6][TURN_DATA_ARTIFACT_COST_MOD]   = -10;
    $Turn_order_data[TURN_6][TURN_DATA_SENTINEL_COST_MOD]   = -20;

    $i = KNOW_DATA_NAME;
    my $k = 'Knowledge of';
    $Knowledge_data[KNOW_GEMS     ][$i] = "$k Gems";
    $Knowledge_data[KNOW_EFLOW    ][$i] = "$k Energy Flow";
    $Knowledge_data[KNOW_FIRE     ][$i] = "$k Fire";
    $Knowledge_data[KNOW_9SAGES   ][$i] = "$k the 9 Sages";
    $Knowledge_data[KNOW_ARTIFACTS][$i] = "$k Artifacts";
    $Knowledge_data[KNOW_ACCUM    ][$i] = "$k Accumulation";

    $i = KNOW_DATA_LEVEL_COST;
    $Knowledge_data[KNOW_GEMS     ][$i] = [qw(2  4  8 16)];
    $Knowledge_data[KNOW_EFLOW    ][$i] = [qw(3  6 12 24)];
    $Knowledge_data[KNOW_FIRE     ][$i] = [qw(5 10 15 20)];
    $Knowledge_data[KNOW_9SAGES   ][$i] = [qw(3  6 12 24)];
    $Knowledge_data[KNOW_ARTIFACTS][$i] = [qw(2  4  8 16)];
    $Knowledge_data[KNOW_ACCUM    ][$i] = [qw(2  4  8 16)];

    $i = KNOW_DATA_HAND_LIMIT;
    $Knowledge_data[KNOW_GEMS     ][$i] = -1;
    $Knowledge_data[KNOW_EFLOW    ][$i] = -1;
    $Knowledge_data[KNOW_FIRE     ][$i] =  0;
    $Knowledge_data[KNOW_9SAGES   ][$i] =  0;
    $Knowledge_data[KNOW_ARTIFACTS][$i] =  1;
    $Knowledge_data[KNOW_ACCUM    ][$i] =  1;

    $i = KNOW_DATA_DETAIL;
    $Knowledge_data[KNOW_GEMS     ][$i] = [qw(0.9 0.8 0.7 0.6)];
    $Knowledge_data[KNOW_EFLOW    ][$i] = [qw(0 2 5 10)];
    $Knowledge_data[KNOW_FIRE     ][$i] = [qw(0 0 0 1)];
    $Knowledge_data[KNOW_9SAGES   ][$i] = [GEM_SAPPHIRE, GEM_EMERALD,
					    GEM_DIAMOND, GEM_RUBY];
    $Knowledge_data[KNOW_ARTIFACTS][$i] = [qw(0 -5 -5 -10)];
    $Knowledge_data[KNOW_ACCUM    ][$i] = [qw(0 1 1 2)];

    $i = CHAR_DATA_KNOWLEDGE_TRACK;
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
    	(start_items_common(@_),
	    $_[0]->a_game->draw_from_deck(GEM_SAPPHIRE, 2)) };
    $Character_data[CHAR_MAGE  ][$i] = \&start_items_common;
    $Character_data[CHAR_KOBOLD][$i] = \&start_items_common;
}

BEGIN {
    # These have to be ordered by descending hand count efficiency.

    for ([10 => 3, 3], [5 => 2, 2], [2 => 1, 1], [1 => 1, 1]) {
    	my ($v, $hl, $opal_count) = @$_;
    	my $r = [];
	$r->[DUST_DATA_VALUE]      = $v;
	$r->[DUST_DATA_HAND_COUNT] = $hl;
	$r->[DUST_DATA_OPAL_COUNT] = $opal_count;
	push @Dust_data, $r;
    }

    # 1-value dust isn't normally present, it can be added via an option.

    # XXX modifying the global means you can't have two $game objects at
    # once

    $Dust_data_val_1 = pop @Dust_data;
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

    $Gem_data[GEM_RUBY    ][GEM_DATA_LIMIT] = 5;

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
    my ($r, $ix);

    # XXX
    @Config_by_num_players = (
    	undef, # 0
    	[24, 2], # XXX undef, # 1
    	[2, 1], # 2
    	[3, 2], # 3
    	[4, 2], # 4
    	[5, 3], # 5
    	[6, 3], # 6
    );

    for ([\@Artifact, \@Artifact_data],
	    [\@Sentinel, \@Sentinel_data]) {
    	my ($ritem, $rdata) = @$_;
    	for my $i (0..$#{ $ritem }) {
	    $rdata->[$i] = [];
	    $rdata->[$i][AUC_DATA_NAME]    = $ritem->[$i];
	    $rdata->[$i][AUC_DATA_MIN_BID] = undef;
	    $rdata->[$i][AUC_DATA_VP]      = undef;
	}
    }

    for (@Sentinel_real_ix_xxx) {
    	$Sentinel_data[$_][AUC_DATA_MIN_BID        ] = 120;
    	$Sentinel_data[$_][AUC_DATA_VP             ] = 5;
	$Sentinel_data[$_][SENT_DATA_MAX_BONUS_VP  ] = undef;
	$Sentinel_data[$_][SENT_DATA_VP_PER        ] = undef;
	$Sentinel_data[$_][SENT_DATA_BONUS_GEM     ] = undef;
	$Sentinel_data[$_][SENT_DATA_BONUS_AUC_TYPE] = undef;
    }

    for (0..$#Artifact) {
    	my $r = $Artifact_data[$_];
	$r->[ARTI_DATA_DECK_LETTER]              = undef;
	$r->[ARTI_DATA_COST_MOD_ARTIFACT]        = undef;
	$r->[ARTI_DATA_COST_MOD_ARTIFACT_AMOUNT] = 0;
	$r->[ARTI_DATA_COST_MOD_SENTINELS]       = 0;
	$r->[ARTI_DATA_OWN_ONLY_ONE]             = 0;
	$r->[ARTI_DATA_KNOWLEDGE_CHIP]           = 0;
	$r->[ARTI_DATA_ADVANCE_KNOWLEDGE]        = 0;
	$r->[ARTI_DATA_GEM_SLOTS]                = 0;
	$r->[ARTI_DATA_HAND_LIMIT]               = 0;
	$r->[ARTI_DATA_CAN_BUY_GEM]              = undef;
	$r->[ARTI_DATA_FREE_GEM]                 = undef;
	$r->[ARTI_DATA_GEM_ENERGY_PRODUCTION]    = undef;
	$r->[ARTI_DATA_DESTROY_GEM]              = 0;
    }

    # A deck

    $r = $Artifact_data[ARTI_CRYSTAL_BALL];
    $r->[ARTI_DATA_MIN_BID]                  = 20;
    $r->[ARTI_DATA_VP]                       = 1;
    $r->[ARTI_DATA_DECK_LETTER]              = 'A';
    $r->[ARTI_DATA_COST_MOD_ARTIFACT]        = ARTI_ELIXIR;
    $r->[ARTI_DATA_COST_MOD_ARTIFACT_AMOUNT] = -5;
    $r->[ARTI_DATA_HAND_LIMIT]               = 3;

    $r = $Artifact_data[ARTI_RUNESTONE];
    $r->[ARTI_DATA_MIN_BID]                  = 20;
    $r->[ARTI_DATA_VP]                       = 1;
    $r->[ARTI_DATA_DECK_LETTER]              = 'A';
    $r->[ARTI_DATA_COST_MOD_ARTIFACT]        = ARTI_CHALICE_OF_FIRE;
    $r->[ARTI_DATA_COST_MOD_ARTIFACT_AMOUNT] = -10;
    $r->[ARTI_DATA_ADVANCE_KNOWLEDGE]        = 1;

    $r = $Artifact_data[ARTI_SPELLBOOK];
    $r->[ARTI_DATA_MIN_BID]                  = 20;
    $r->[ARTI_DATA_VP]                       = 1;
    $r->[ARTI_DATA_DECK_LETTER]              = 'A';
    $r->[ARTI_DATA_COST_MOD_ARTIFACT]        = ARTI_SHADOW_CLOAK;
    $r->[ARTI_DATA_COST_MOD_ARTIFACT_AMOUNT] = -15;
    $r->[ARTI_DATA_CAN_BUY_GEM]              = GEM_EMERALD;

    # B deck

    $r = $Artifact_data[ARTI_MAGIC_BELT];
    $r->[ARTI_DATA_MIN_BID]                  = 30;
    $r->[ARTI_DATA_VP]                       = 2;
    $r->[ARTI_DATA_DECK_LETTER]              = 'B';
    $r->[ARTI_DATA_OWN_ONLY_ONE]             = 1;
    $r->[ARTI_DATA_GEM_SLOTS]                = 2;

    $r = $Artifact_data[ARTI_MAGIC_MIRROR];
    $r->[ARTI_DATA_MIN_BID]                  = 40;
    $r->[ARTI_DATA_VP]                       = 2;
    $r->[ARTI_DATA_DECK_LETTER]              = 'B';
    $r->[ARTI_DATA_KNOWLEDGE_CHIP]           = 1;
    $r->[ARTI_DATA_DESTROY_GEM]              = 1;

    $r = $Artifact_data[ARTI_ELIXIR];
    $r->[ARTI_DATA_MIN_BID]                  = 60;
    $r->[ARTI_DATA_VP]                       = 2;
    $r->[ARTI_DATA_DECK_LETTER]              = 'B';
    $r->[ARTI_DATA_CAN_BUY_GEM]              = GEM_DIAMOND;
    $r->[ARTI_DATA_FREE_GEM]                 = GEM_DIAMOND;

    $r = $Artifact_data[ARTI_CRYSTAL_OF_PROTECTION];
    $r->[ARTI_DATA_MIN_BID]                  = 40;
    $r->[ARTI_DATA_VP]                       = 2;
    $r->[ARTI_DATA_DECK_LETTER]              = 'B';
    $r->[ARTI_DATA_GEM_ENERGY_PRODUCTION]    = GEM_EMERALD;

    # C deck

    $r = $Artifact_data[ARTI_MASK_OF_CHARISMA];
    $r->[ARTI_DATA_MIN_BID]                  = 50;
    $r->[ARTI_DATA_VP]                       = 3;
    $r->[ARTI_DATA_DECK_LETTER]              = 'C';
    $r->[ARTI_DATA_COST_MOD_SENTINELS]       = -20;
    $r->[ARTI_DATA_ADVANCE_KNOWLEDGE]        = 1;

    $r = $Artifact_data[ARTI_MAGIC_WAND];
    $r->[ARTI_DATA_MIN_BID]                  = 60;
    $r->[ARTI_DATA_VP]                       = 3;
    $r->[ARTI_DATA_DECK_LETTER]              = 'C';
    $r->[ARTI_DATA_OWN_ONLY_ONE]             = 1;
    $r->[ARTI_DATA_GEM_SLOTS]                = 2;
    $r->[ARTI_DATA_HAND_LIMIT]               = 3;

    $r = $Artifact_data[ARTI_CHALICE_OF_FIRE];
    $r->[ARTI_DATA_MIN_BID]                  = 80;
    $r->[ARTI_DATA_VP]                       = 4;
    $r->[ARTI_DATA_DECK_LETTER]              = 'C';
    $r->[ARTI_DATA_GEM_ENERGY_PRODUCTION]    = GEM_RUBY;

    # D deck

    $r = $Artifact_data[ARTI_SHADOW_CLOAK];
    $r->[ARTI_DATA_MIN_BID]                  = 80;
    $r->[ARTI_DATA_VP]                       = 5;
    $r->[ARTI_DATA_DECK_LETTER]              = 'D';
    $r->[ARTI_DATA_KNOWLEDGE_CHIP]           = 1;
    $r->[ARTI_DATA_DESTROY_GEM]              = 1;

    $r = $Artifact_data[ARTI_TALISMAN];
    $r->[ARTI_DATA_MIN_BID]                  = 100;
    $r->[ARTI_DATA_VP]                       = 8;
    $r->[ARTI_DATA_DECK_LETTER]              = 'D';
    $r->[ARTI_DATA_ADVANCE_KNOWLEDGE]        = 2;

    # Sentinels

    $Sentinel_data[SENT_PHOENIX   ][SENT_DATA_VP_PER      ] = 2; # type of gem
    $Sentinel_data[SENT_OWL       ][SENT_DATA_VP_PER      ] = 2; # knowledge

    $Sentinel_data[SENT_TOAD      ][SENT_DATA_VP_PER      ] = 2;
    $Sentinel_data[SENT_TOAD      ][SENT_DATA_BONUS_AUC_TYPE]
    	= { map { $_ => 1 } (
	    AUC_RUNESTONE,
	    AUC_CRYSTAL_OF_PROTECTION,
	    AUC_SPELLBOOK,
	    AUC_ELIXIR,
	) };

    $Sentinel_data[SENT_RAVEN     ][SENT_DATA_VP_PER      ] = 2;
    $Sentinel_data[SENT_RAVEN     ][SENT_DATA_BONUS_AUC_TYPE]
    	= { map { $_ => 1 } (
    	    AUC_CRYSTAL_BALL,
    	    AUC_MASK_OF_CHARISMA,
    	    AUC_MAGIC_BELT,
    	    AUC_MAGIC_WAND,
	) };

    $Sentinel_data[SENT_TOMCAT    ][SENT_DATA_BONUS_GEM   ] = GEM_OPAL;
    $Sentinel_data[SENT_TOMCAT    ][SENT_DATA_VP_PER      ] = 2;
    $Sentinel_data[SENT_TOMCAT    ][SENT_DATA_MAX_BONUS_VP] = 12;

    $Sentinel_data[SENT_FOX       ][SENT_DATA_BONUS_GEM   ] = GEM_SAPPHIRE;
    $Sentinel_data[SENT_FOX       ][SENT_DATA_VP_PER      ] = 2;
    $Sentinel_data[SENT_FOX       ][SENT_DATA_MAX_BONUS_VP] = 12;

    $Sentinel_data[SENT_SCARAB    ][SENT_DATA_BONUS_GEM   ] = GEM_EMERALD;
    $Sentinel_data[SENT_SCARAB    ][SENT_DATA_VP_PER      ] = 1;

    $Sentinel_data[SENT_UNICORN   ][SENT_DATA_BONUS_GEM   ] = GEM_DIAMOND;
    $Sentinel_data[SENT_UNICORN   ][SENT_DATA_VP_PER      ] = 1;

    $Sentinel_data[SENT_SALAMANDER][SENT_DATA_BONUS_GEM   ] = GEM_RUBY;
    $Sentinel_data[SENT_SALAMANDER][SENT_DATA_VP_PER      ] = 2;
}


#------------------------------------------------------------------------------

sub start_items_common {
    my ($player) = @_;

    my @i;

    require Game::ScepterOfZavandor::Item::Gem;
    for (GEM_OPAL, GEM_OPAL, GEM_SAPPHIRE) {
    	push @i, Game::ScepterOfZavandor::Item::Gem->new($player, $_);
    }

    my $char = $player->a_char;
    push @i, Game::ScepterOfZavandor::Item::Energy::Dust->make_dust(
    	    	$Character_data[$char][CHAR_DATA_START_DUST]);

    # XXX do knowledge here?

    return @i;
}

1

__END__

# - XXX use $ix instead of $i for indexes, $i for items
# - XXX use confess for assertions
# - XXX POE to facilitate multiple clients
# - XXX can't put magic mirror/shadow cloak up for auction unless you
#   have an active gem
# - XXX you can combine purchases to avoid losing 1 dust (except you
#   have to pay before opening an auction)
# - XXX The phases 3a, 3b and 3c may be done in any order, although you
#   may NOT split any of the phases, like selling gems (3a), increase
#   gems knowledge (3b) and then buy gems (3a again).

XXX
    - manually activate/disactivate gems
    - ask user about which gem to destroy
    - ask user about what to pay with
    - ask user about which knowledge to advance
    - combine purchases where possible
    	- maybe always allow 1 dust, then remove it when appropriate
	- but this likely wouldn't let you do everything you could by
	  combining purchases for real
    - auto-activate gem on your own turn after having one destroyed
