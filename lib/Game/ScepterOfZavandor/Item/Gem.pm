# $Id: Gem.pm,v 1.1 2008-07-17 19:53:56 roderick Exp $

use strict;

package Game::ScepterOfZavandor::Item::Gem;

use base qw(Game::ScepterOfZavandor::Item);

use Game::Util	qw(add_array_index debug);
use RS::Handy	qw(badinvo data_dump dstr xcroak);

use Game::ScepterOfZavandor::Constant qw(
    @Gem
);

BEGIN {
    add_array_index 'ITEM', $_ for map { "GEM_$_" } qw(TYPE ACTIVE_VP);
}

sub new {
    @_ == 2 || badinvo;
    my ($class, $type) = @_;

    defined $Gem[$type] or die;;

    my $self = $class->SUPER::new;
    $self->[ITEM_GEM_TYPE]  = $gtype;
    $self->[ITEM_ACTIVE_VP] = $Gem_vp[$gtype];

    return $self;
}

sub value {
    @_ == 1 || badinvo;
    my $self = shift;

    return $self->[ITEM_ENERGY_VALUE];
}
