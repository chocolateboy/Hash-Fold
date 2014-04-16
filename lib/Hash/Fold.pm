package Hash::Fold;

use Carp qw(confess);
use Moose;
use Scalar::Util qw(refaddr);

use Sub::Exporter -setup => {
    exports => [ map { $_ => \&_build_function } qw(fold unfold flatten unflatten) ],
};

use constant {
    ARRAY => 1,
    HASH  => 2,
    TYPE  => 0,
    VALUE => 1,
};

our $VERSION = '0.0.1';

has on_object => (
    isa      => 'CodeRef',
    is       => 'ro',
    default  => sub { sub { $_[1] } }, # return the value unchanged
);

has on_seen => (
    isa      => 'CodeRef',
    is       => 'ro',
    default  => sub { sub { } }, # do nothing
);

has hash_delimiter => (
    isa      => 'Str',
    is       => 'ro',
    default  => '.',
);

has array_delimiter => (
    isa      => 'Str',
    is       => 'ro',
    default  => '.',
);

# TODO provide flatten and unflatten as synonyms
sub fold {
    my ($self, $value) = @_;
    my $ref = ref($value);

    if ($ref eq 'HASH') {
        my $prefix = undef;
        my $target = {};
        my $seen = {};

        my $hash = $self->_merge($value, $prefix, $target, $seen);
        return $hash;
    } else {
        my $type = length($ref) ? "'$ref'" : 'non-reference';
        confess "invalid argument: expected unblessed HASH reference, got: $type";
    }
}

# TODO provide flatten and unflatten as synonyms
sub unfold {
    my ($self, $hash) = @_;
    my $ref = ref($hash);

    if ($ref eq 'HASH') {
        my $target = {};

        # sorting the keys should lead to better locality of reference,
        # for what that's worth here
        # XXX the sort order is connected with the ambiguity issue mentioned below
        for my $key (sort keys %$hash) {
            my $value = $hash->{$key};
            my $steps = $self->_split($key);
            $self->_set($target, $steps, $value);
        }

        return $target;
    } else {
        my $type = length($ref) ? "'$ref'" : 'non-reference';
        confess "invalid argument: expected unblessed HASH reference, got: $type";
    }
}

BEGIN {
    *flatten   = \&fold;
    *unflatten = \&unfold;
}

sub is_object {
    my ($self, $value) = @_;
    my $ref = ref($value);
    return $ref && ($ref ne 'HASH') && ($ref ne 'ARRAY');
}

sub _build_function {
    my ($class, $name, $base_options) = @_;

    return sub ($;@) {
        my $hash = shift;
        my $custom_options = @_ == 1 ? shift : { @_ };
        my $folder = $class->new({ %$base_options, %$custom_options });
        return $folder->$name($hash);
    }
}

sub _join {
    my ($self, $prefix, $delimiter, $key) = @_;
    return defined($prefix) ? $prefix . $delimiter . $key : $key;
}

=begin comment

TODO: when the hash delimiter is the same as the array delimiter (as it is by default), ambiguities can arise:

    {
        foo => 'bar',
        1   => 'aaagh!',
        baz => 'quux',
    }

In many cases, these can be smartly resolved by looking at the context: if at least one step
is non-numeric, then the container must be a hashref:

    foo.bar.baz
    foo.bar.0   <- must be a hash key
    foo.bar.quux

The ambiguity can either be resolved here/in unfold with a bit of static analysis or resolved
lazily/dynamically in _set (need to sort the keys so that non-integers (if any) are unpacked
before integers (if any)).

Currently, the example above is unpacked corectly :-)

=end comment

=cut

sub _split {
    my ($self, $path) = @_;
    my $hash_delimiter = $self->hash_delimiter;
    my $array_delimiter = $self->array_delimiter;
    my $hash_delimiter_pattern = quotemeta($hash_delimiter);
    my $array_delimiter_pattern = quotemeta($array_delimiter);
    my $same_delimiter = $array_delimiter eq $hash_delimiter;
    my @split = split qr{((?:$hash_delimiter_pattern)|(?:$array_delimiter_pattern))}, $path;
    my @steps;

    # since we require the argument to fold (and unfold) to be a hashref,
    # the top-level keys must always be hash keys (strings) rather than
    # array indices (numbers)
    push @steps, [ HASH, shift @split ];

    while (@split) {
        my $delimiter = shift @split;
        my $step = shift @split;

        if ($same_delimiter) {
            # tie-breaker
            # if ($step =~ /^\d+$/) {
            if (($step eq '0') || ($step =~ /^[1-9]\d*$/)) { # no leading space
                push @steps, [ ARRAY, $step ];
            } else {
                push @steps, [ HASH, $step ];
            }
        } else {
            if ($delimiter eq $array_delimiter) {
                push @steps, [ ARRAY, $step ];
            } else {
                push @steps, [ HASH, $step ];
            }
        }
    }

    return \@steps;
}

sub _merge {
    my ($self, $value, $target_key, $target, $_seen) = @_;

    # "localize" the $seen hash: we want to catch circular references (i.e.
    # an unblessed hashref or arrayref which contains (at some depth) a reference to itself),
    # but don't want to prevent repeated references e.g. { foo => $object, bar => $object }
    # is OK. To achieve this, we need to "localize" the $seen hash i.e. do
    # the equivalent of "local $seen". However, perl doesn't allow lexical variables
    # to be localized, so we have to do it manually.
    my $seen = { %$_seen }; # isolate from the caller's $seen hash and allow scoped additions

    if ($self->is_object($value)) {
        $value = $self->on_object->($self, $value);
    }

    my $ref = ref($value);
    my $refaddr = refaddr($value);

    if ($refaddr && $seen->{$refaddr}) { # seen HASH or ARRAY
        # we've seen this unblessed hashref/arrayref before: possible actions
        #
        #     1) (do nothing and) treat it as a terminal
        #     2) warn and treat it as a terminal
        #     3) die (and treat it as a terminal :-)
        #
        # if the callback doesn't raise a fatal exception,
        # treat the value as a terminal
        $self->on_seen->($self, $value); # might warn or die
        $target->{$target_key} = $value; # treat as a terminal
    } elsif ($ref eq 'HASH') {
        my $delimiter = $self->hash_delimiter;

        $seen->{$refaddr} = 1;

        # sorting the keys ensures a deterministic order,
        # which (at the very least) is required for unsurprising
        # tests
        for my $hash_key (sort keys %$value) {
            my $hash_value = $value->{$hash_key};
            $self->_merge($hash_value, $self->_join($target_key, $delimiter, $hash_key), $target, $seen);
        }
    } elsif ($ref eq 'ARRAY') {
        my $delimiter = $self->array_delimiter;

        $seen->{$refaddr} = 1;

        for my $index (0 .. $#$value) {
            my $array_element = $value->[$index];
            $self->_merge($array_element, $self->_join($target_key, $delimiter, $index), $target, $seen);
        }
    } else { # terminal
        $target->{$target_key} = $value;
    }

    return $target;
}

# the action depends on the number of steps:
#
#     1: e.g. [ 'foo' ]:
#
#        $context->{foo} = $value
#
#     2: e.g. [ 'foo', 42 ]:
#
#        $context = $context->{foo} ||= []
#        $context->[42] = $value
#
#     3 (or more): e.g. [ 'foo', 42, 'bar' ]:
#
#        $context = $context->{foo} ||= []
#        return $self->_set($context, $new_steps, $value)
#
# Note that the 2 case can be implemented in the same way as the 3 (or more) case.

sub _set {
    my ($self, $context, $steps, $value) = @_;
    my $step = shift @$steps; # or die "WTF" (shouldn't happen)

    if (@$steps) { # recursive case
        # peek i.e. look-ahead to the step that will be processed in
        # the tail call and make sure its container exists
        my $next_step = $steps->[0];
        my $next_step_container = sub { $next_step->[TYPE] == ARRAY ? [] : {} };

        $context = ($step->[TYPE] == ARRAY) ?
            ($context->[ $step->[VALUE] ] ||= $next_step_container->()) : # array index
            ($context->{ $step->[VALUE] } ||= $next_step_container->());  # hash key
    } else { # base case
        if ($step->[TYPE] == ARRAY) {
            $context->[ $step->[VALUE] ] = $value; # array index
        } else {
            $context->{ $step->[VALUE] } = $value; # hash key
        }
    }

    return @$steps ? $self->_set($context, $steps, $value) : $value;
}

__PACKAGE__->meta->make_immutable;

1;

=head1 NAME

Hash::Fold - fold and unfold nested hashrefs

=head1 SYNOPSIS

    use Hash::Fold qw(flatten unflatten);

    my $object = bless { foo => 'bar' };
    my $nested = {
        foo => $object,
        baz => {
            a => 'b',
            c => [ 'd', { e => 'f' }, 42 ],
        },
    };

    my $flattened = flatten($nested);
    my $roundtrip = unflatten($flattened);

    is_deeply $flattened, {
        'baz.a'     => 'b',
        'baz.c.0'   => 'd',
        'baz.c.1.e' => 'f',
        'baz.c.2'   => 42,
        'foo'       => $object,
    };

    is_deeply $roundtrip, $nested;

=head1 DESCRIPTION

This module provides functional and OO interfaces that can be used to flatten and unflatten hashrefs.

=head1 EXPORTS

Nothing by default. The following functions can be imported.

=head2 flatten

Takes a nested hashref and returns a single-level hashref with (by default) dotted keys.

Unblessed arrayrefs and unblessed hashrefs are traversed. All other values
(e.g. strings, numbers, objects &c.) are treated as terminals and passed through verbatim.

=head2 fold

Provided as an alias for L<"flatten">.

=head2 unflatten

Takes a flattened hashref and returns the corresponding nested hashref.

=head2 unfold

Provided as an alias for L<"unflatten">.

=head1 VERSION

0.0.1

=head1 SEE ALSO

=over

=item L<CGI::Expand>

=item L<Hash::Flatten>

=back

=head1 AUTHOR

chocolateboy <chocolate@cpan.org>

=head1 COPYRIGHT

Copyright (c) 2014, chocolateboy.

This module is free software. It may be used, redistributed and/or modified under the same terms
as Perl itself.

=cut
