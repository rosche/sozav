# $Id: Constant.pm,v 1.7 2008-07-28 02:13:28 roderick Exp $

use strict;

package Game::ScepterOfZavandor::Constant;

use base qw(Exporter);

use Game::Util		qw(add_array_indices debug);
use List::Util		qw(sum);
use List::MoreUtils	qw(minmax);
use RS::Handy		qw(badinvo data_dump dstr xcroak);

use vars qw($VERSION @EXPORT @EXPORT_OK);
BEGIN {
    $VERSION = q$Revision: 1.7 $ =~ /(\d\S+)/ ? $1 : '?';
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
	@Gem
	%Gem
	@Gem_data
	@Item_type
	%Item_type
	@Knowledge
	%Knowledge
	@Knowledge_chip_cost
	@Knowledge_data
	@Knowledge_data_field
	$Knowledge_top_vp
	@Option
	%Option
	@Sentinel
	@Sentinel_real_ix_xxx
    	%Sentinel
	@Sentinel_data
	@Sentinel_data_field
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
	    'active gems');
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

    @Item_type = qw(knowledge sentinel artifact gem concentrated card dust);
    %Item_type = map { $Item_type[$_] => $_ } 0..$#Item_type;
    add_array_indices 'ITEM_TYPE', @Item_type;

    @Knowledge = qw(gems eflow fire 9sages artifacts accum);
    %Knowledge = map { $Knowledge[$_] => $_ } 0..$#Knowledge;
    add_array_indices 'KNOW', @Knowledge;
    add_array_indices 'KNOW_DATA', qw(
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
    #add_array_indices 'SENT', @Sentinel;
    RS::Handy::create_index_subs 'SENT', undef, @Sentinel;

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
	'DECK_LETTER',			# A-D, S for sentinels
	'DISCOUNT_ARTIFACT',		# artifact you get a discount on
	'DISCOUNT_ARTIFACT_AMOUNT',	# discount of N on specified artifact
	'DISCOUNT_SENTINELS',		# discount of N on sentinels
	'OWN_ONLY_ONE',			# can only own 1 of these
	'KNOWLEDGE_CHIP',		# XXX stage N knowledge chips
	'ADVANCE_KNOWLEDGE',		# XXX advance N knowledge stages
	'GEM_SLOTS',			# add N gem slots
    	'HAND_LIMIT',			# add N to hand limit
	'CAN_BUY_GEM',			# you can by gem type GTYPE
    	'FREE_GEM',			# you get a free gem of type GTYPE
	'GEM_ENERGY_PRODUCTION',	# produces an energy card of type GTYPE
	'DESTROY_GEM',			# XXX destroy N gems of each other player
    );
    add_array_indices 'ARTI_DATA', @Artifact_data_field;

    @Sentinel_data_field = (
    	@Auctionable_data_field,
	'MAX_BONUS_VP',
    );
    add_array_indices 'SENT_DATA', @Sentinel_data_field;
}

BEGIN {
    $Base_gem_slots               = 5;
    $Base_hand_limit              = 5;
    $Concentrated_card_count      = 4;
    $Concentrated_additional_dust = 2;
    $Concentrated_hand_count      = 3;
    @Knowledge_chip_cost          = qw(20 25 30 35 40);
    $Knowledge_top_vp             = 2;
}

BEGIN {
    $Knowledge_data[KNOW_GEMS     ][KNOW_DATA_LEVEL_COST] = [qw(2  4  8 16)];
    $Knowledge_data[KNOW_EFLOW    ][KNOW_DATA_LEVEL_COST] = [qw(3  6 12 24)];
    $Knowledge_data[KNOW_FIRE     ][KNOW_DATA_LEVEL_COST] = [qw(5 10 15 20)];
    $Knowledge_data[KNOW_9SAGES   ][KNOW_DATA_LEVEL_COST] = [qw(3  6 12 24)];
    $Knowledge_data[KNOW_ARTIFACTS][KNOW_DATA_LEVEL_COST] = [qw(2  4  8 16)];
    $Knowledge_data[KNOW_ACCUM    ][KNOW_DATA_LEVEL_COST] = [qw(2  4  8 16)];

    $Knowledge_data[KNOW_GEMS     ][KNOW_DATA_HAND_LIMIT] = -1;
    $Knowledge_data[KNOW_EFLOW    ][KNOW_DATA_HAND_LIMIT] = -1;
    $Knowledge_data[KNOW_FIRE     ][KNOW_DATA_HAND_LIMIT] =  0;
    $Knowledge_data[KNOW_9SAGES   ][KNOW_DATA_HAND_LIMIT] =  0;
    $Knowledge_data[KNOW_ARTIFACTS][KNOW_DATA_HAND_LIMIT] =  1;
    $Knowledge_data[KNOW_ACCUM    ][KNOW_DATA_HAND_LIMIT] =  1;

    $Knowledge_data[KNOW_GEMS     ][KNOW_DATA_DETAIL] = [qw(0.9 0.8 0.7 0.6)];
    $Knowledge_data[KNOW_EFLOW    ][KNOW_DATA_DETAIL] = [qw(0 2 5 10)];
    $Knowledge_data[KNOW_FIRE     ][KNOW_DATA_DETAIL] = [qw(0 0 0 1)];
    # XXX knowledge implemntation
    $Knowledge_data[KNOW_9SAGES   ][KNOW_DATA_DETAIL] = [GEM_SAPPHIRE, GEM_EMERALD, GEM_DIAMOND, GEM_RUBY];
    $Knowledge_data[KNOW_ARTIFACTS][KNOW_DATA_DETAIL] = [qw(0 5 5 10)];
    $Knowledge_data[KNOW_ACCUM    ][KNOW_DATA_DETAIL] = [qw(0 1 1 2)];

    my $i = CHAR_DATA_KNOWLEDGE_TRACK;
    $Character_data[CHAR_WITCH ][$i] = KNOW_GEMS;	# XXX
    $Character_data[CHAR_ELF   ][$i] = KNOW_EFLOW;	# XXX
    $Character_data[CHAR_DRUID ][$i] = KNOW_FIRE;	# XXX
    $Character_data[CHAR_FAIRY ][$i] = KNOW_9SAGES;	# XXX
    $Character_data[CHAR_MAGE  ][$i] = KNOW_ARTIFACTS;	# XXX
    $Character_data[CHAR_KOBOLD][$i] = KNOW_ACCUM;	# XXX

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
    	$Sentinel_data[$_][AUC_DATA_MIN_BID]     = 120;
    	$Sentinel_data[$_][AUC_DATA_VP]          = 5;
    }

    for (0..$#Artifact) {
    	my $r = $Artifact_data[$_];
	$r->[ARTI_DATA_DECK_LETTER]              = undef;
	$r->[ARTI_DATA_DISCOUNT_ARTIFACT]        = undef;
	$r->[ARTI_DATA_DISCOUNT_ARTIFACT_AMOUNT] = 0;
	$r->[ARTI_DATA_DISCOUNT_SENTINELS]       = 0;
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

    $r = $Artifact_data[ARTI_CRYSTAL_BALL];
    $r->[ARTI_DATA_MIN_BID]                  = 20;
    $r->[ARTI_DATA_VP]                       = 1;
    $r->[ARTI_DATA_DECK_LETTER]              = 'A';
    $r->[ARTI_DATA_DISCOUNT_ARTIFACT]        = ARTI_ELIXIR;
    $r->[ARTI_DATA_DISCOUNT_ARTIFACT_AMOUNT] = 5;
    $r->[ARTI_DATA_HAND_LIMIT]               = 3;

    $r = $Artifact_data[ARTI_RUNESTONE];
    $r->[ARTI_DATA_MIN_BID]                  = 20;
    $r->[ARTI_DATA_VP]                       = 1;
    $r->[ARTI_DATA_DECK_LETTER]              = 'A';
    $r->[ARTI_DATA_DISCOUNT_ARTIFACT]        = ARTI_CHALICE_OF_FIRE;
    $r->[ARTI_DATA_DISCOUNT_ARTIFACT_AMOUNT] = 10;
    $r->[ARTI_DATA_ADVANCE_KNOWLEDGE]        = 1;

    $r = $Artifact_data[ARTI_SPELLBOOK];
    $r->[ARTI_DATA_MIN_BID]                  = 20;
    $r->[ARTI_DATA_VP]                       = 1;
    $r->[ARTI_DATA_DECK_LETTER]              = 'A';
    $r->[ARTI_DATA_DISCOUNT_ARTIFACT]        = ARTI_SHADOW_CLOAK;
    $r->[ARTI_DATA_DISCOUNT_ARTIFACT_AMOUNT] = 15;
    $r->[ARTI_DATA_CAN_BUY_GEM]              = GEM_EMERALD;


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


    $r = $Artifact_data[ARTI_MASK_OF_CHARISMA];
    $r->[ARTI_DATA_MIN_BID]                  = 50;
    $r->[ARTI_DATA_VP]                       = 3;
    $r->[ARTI_DATA_DECK_LETTER]              = 'C';
    $r->[ARTI_DATA_DISCOUNT_SENTINELS]       = 20;
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
    $r->[ARTI_DATA_KNOWLEDGE_CHIP]           = 2;

# real limits are only on fox and tomcat I think
#
# Phoenix * 120 5 2 per kind of active gem 10
# Owl 120 5 2 per top-level knowledge 12
# Fox 120 5 2 per active sapphire 12
# Toad 120 5 2 for each Runestone, Protective Crystal, Spellbook, Elixir -
# Unicorn 120 5 1 for each active diamond 11
# Tomcat 120 5 2 for each active opal 12
# Scarab * 120 5 1 for each active emerald 11
# Raven 120 5 2 for each Crystal Ball, Charismatic Mask, Magic Belt, Magic Wand -
# Salamander * 120 5 2 for each active ruby 10

}


#------------------------------------------------------------------------------

sub start_items_common {
    my ($player) = @_;

    my @i;

    require Game::ScepterOfZavandor::Item::Gem;
    for (GEM_OPAL, GEM_OPAL, GEM_SAPPHIRE) {
    	push @i, Game::ScepterOfZavandor::Item::Gem->new($_, $player);
    }

    my $char = $player->a_char;
    push @i, Game::ScepterOfZavandor::Item::Energy::Dust->make_dust(
    	    	$Character_data[$char][CHAR_DATA_START_DUST]);

    # XXX knowledge

    return @i;
}

1

# XXX use $ix instead of $i for indexes, $i for items
# XXX use confess for assertions
# XXX limit to 5 rubies
# XXX POE to facilitate multiple clients
