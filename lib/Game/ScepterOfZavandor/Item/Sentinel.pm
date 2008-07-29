# $Id: Sentinel.pm,v 1.3 2008-07-29 17:15:16 roderick Exp $

use strict;

package Game::ScepterOfZavandor::Item::Sentinel;

use base qw(Game::ScepterOfZavandor::Item::Auctionable);

use Game::Util	qw(add_array_index debug make_ro_accessor);
use RS::Handy	qw(badinvo data_dump dstr shuffle xcroak);

use Game::ScepterOfZavandor::Constant qw(
    /^ITEM_/
    /^SENT_/
    @Sentinel
    @Sentinel_real_ix_xxx
    @Sentinel_data
);

sub new {
    @_ == 2 || badinvo;
    my ($class, $auc_type) = @_;

    my $self = $class->SUPER::new(ITEM_TYPE_SENTINEL,
				    \@Sentinel_data, $auc_type);

    return $self;
}

# XXX name
sub new_deck {
    @_ == 1 || badinvo;
    my $self = shift;

    my @a = ();
    for (@Sentinel_real_ix_xxx) {
	push @a, __PACKAGE__->new($_);
    }
    return @a;
}

1
