# $Id: Constant.pm,v 1.1 2008-07-17 12:50:53 roderick Exp $

package Game::ScepterOfZavandor::Constant;

use strict;

use base qw(Exporter);

use RS::Handy	qw(badinvo create_constant_subs data_dump dstr xcroak);

use Game::ScepterOfZavandor::Util;

use vars qw($VERSION @EXPORT @EXPORT_OK);

$VERSION = q$Revision: 1.1 $ =~ /(\d\S+)/ ? $1 : '?';

BEGIN {
    @EXPORT_OK = qw(
    	@Config_by_num_players
	@Gem
    );
}

use subs grep { /^[a-z]/    } @EXPORT, @EXPORT_OK;
use vars grep { /^[\$\@\%]/ } @EXPORT, @EXPORT_OK;

BEGIN {
    @Config_by_num_players = (
    	undef, # 0
    	undef, # 1
    	[], # 2
    	[], # 3
    	[], # 4
    	[], # 5
    	[], # 6
    );

    @Gem = qw(opal sapphire emerald diamond ruby);
    add_array_index_type 'GEM';
    add_array_index 'GEM', $_ for @Gem;

    add_array_index_type 'GAME';
    for (
	    'option',
    	    'player',
	    'gem_decks',
	    'artifact_deck',
	    'player_order',
    	) {
	add_array_index 'GAME', $_;
    }
}

1
