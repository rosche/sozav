# $Id: Util.pm,v 1.10 2008-08-04 13:02:59 roderick Exp $

package Game::Util;

use strict;

use base qw(Exporter);

use RS::Handy	qw(badinvo data_dump dstr xconfess);
use Scalar::Util qw(looks_like_number);

use vars qw($VERSION @EXPORT @EXPORT_OK);

$VERSION = q$Revision: 1.10 $ =~ /(\d\S+)/ ? $1 : '?';

BEGIN {
    @EXPORT = qw(
	$Debug
	add_array_index_type
	add_array_index
	add_array_indices
	debug
	debug_var
	eval_block
	make_ro_accessor
	make_rw_accessor
	make_accessor_pkg
	same_object
	valid_ix
	valid_ix_plus_1
    );
    @EXPORT_OK = qw(
    	%Index
    );
}

use subs grep { /^[a-z]/    } @EXPORT, @EXPORT_OK;
use vars grep { /^[\$\@\%]/ } @EXPORT, @EXPORT_OK;

BEGIN {
    $Debug = 0 if !defined $Debug;
}

sub debug {
    # XXX attach debug flag to game object +/- other objects
    print @_, "\n" if $Debug;
}

sub debug_var {
    return unless $Debug;
    while (@_) {
    	my ($key, $val) = splice @_, 0, 2;
	debug sprintf "%-20s %s", $key, dstr $val;
    }
}

# XXX beef this up
#
#{
#
#my %used_index_name;
#
## $Index{GAME}{''} = 1; # next index
## $Index{GAME}{NUM_PLAYERS} = 0;
#
#sub _index_backend {
#    my ($pkg, $is_leaf, @iname) = @_;
#
#    @iname = map { uc } @iname;
#    my $full_name = join '_', @iname;
#
#    if ($used_index_name{$full_name}++) {
#	xconfess "index name $full_name has already been used\n";
#    }
#
#    my $r = \%Index;
#    while (@iname) {
#    	my $this_part = shift @iname;
#	if ($this_part !~ /^\w+\z/) {
#	    xconfess "invalid index name part ", dstr $this_part;
#	}
#
#	my $next_r = $r->{$this_part};
#
#	if (defined $next_r) {
#	    kkkkkkkk
#	    if (@iname) {
#
#
#	if (@iname) {
#	    # there's more, this isn't a leaf
#
#
#	    #
#
#	if (!defined $next_r) {
#
#
#
#	if (@iname || !$is_leaf) {
#
#
#}

# XXX sub-types handling:  when adding a field to an object, it's
# important not to class with fields of your ancestors, but it doesn't
# matter if you clash with your siblings.  Right now all are disjoint,
# which wasts array space.  Eg it'd be nice to have:
#
#     object Foo,          fields fa = 0, fb = 1
#     object Bar @ISA Foo, fields bc = 2, bc = 3
#     object Baz @ISA Foo, fields zd = 2, ze = 3
#
# but now we have
#
#     object Foo,          fields fa = 0, fb = 1
#     object Bar @ISA Foo, fields bc = 2, bc = 3
#     object Baz @ISA Foo, fields zd = 4, ze = 5

sub add_array_index_type {
    @_ == 1 || badinvo;
    my ($itype) = map { uc } @_;

    if ($Index{$itype}) {
	xconfess "index type $itype already exists";
    }
    $Index{$itype} = [];
}

sub add_array_index {
    @_ == 2 || @_ == 3 || badinvo;
    my $itype = uc shift;
    my $iname = uc shift;
    my $pkg = shift || caller;

    my $r = $Index{$itype};

    $iname =~ tr/ +-/_/;

    if (!$r) {
	xconfess "invalid index type ", dstr $itype;
    }

    if (grep { $_ eq $iname } @$r) {
	xconfess "key $iname already exists in index for $itype";
    }

    push @$r, $iname;
    my $ix = $#$r;

    # XXX need exported name for index type, combine these subs somehow

    my $sub = "${itype}_${iname}";
    no strict 'refs';
    debug "create ${pkg}::${sub} -> $ix" if $Debug > 2;
    *{ "${pkg}::${sub}" } = sub () { $ix };
    push @{ "${pkg}::EXPORT_OK" }, $sub;
}

sub add_array_indices {
    @_ >= 2 || badinvo;
    my ($itype, @iname) = @_;

    add_array_index_type $itype;
    add_array_index $itype, $_, scalar caller for @iname;
}

sub eval_block (&) {
    return eval {
	local $SIG{__DIE__};
	$_[0]->()
    };
}

sub make_accessor_pkg {
    @_ >= 4 || badinvo;
    my $pkg = shift;
    my $rw  = shift;
    @_ % 2 && badinvo;

    while (@_) {
	my ($name, $index) = splice @_, 0, 2;
	my $sub = $rw
	    ? sub {
		@_ == 1 || @_ == 2 || badinvo;
		my $self = shift;
		my $old = $self->[$index];
		$self->[$index] = shift if @_;
		return $old;
	    }
	    : sub {
	    	@_ == 1 || badinvo 1, "$name property is read-only";
		return $_[0]->[$index];
	    };
	no strict 'refs';
	*{ "${pkg}::${name}" } = $sub;
    }
}

sub make_ro_accessor {
    return make_accessor_pkg scalar caller, 0, @_;
}

sub make_rw_accessor {
    return make_accessor_pkg scalar caller, 1, @_;
}

sub same_referent {
    # 3-args used by overload.pm
    @_ == 2 || @_ == 3 || badinvo;

    return ref($_[0]) && ref($_[1]) && refaddr($_[0]) == refaddr($_[1]);
}

sub valid_ix {
    @_ == 2 || badinvo;
    my ($ix, $r) = @_;

    return @$r
	&& defined $ix
	&& looks_like_number($ix)
	&& $ix >= 0
    	&& $ix <= $#{ $r };
}

sub valid_ix_plus_1 {
    @_ == 2 || badinvo;
    my ($ix, $r) = @_;

    return looks_like_number($ix) ? valid_ix($ix + 1, $r) : 0;
}

1
