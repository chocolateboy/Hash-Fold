#!/usr/bin/perl

use strict;
use warnings;

use Hash::Fold qw(fold);
use Test::More;

# exercise a bit of everything to make sure the basics work
{
    my $folder = Hash::Fold->new;
    my $object = bless {};
    my $regex  = qr{whatever};
    my $glob   = \*STDIN;

    my $hash = {
        foo => {
            bar => {
                string => 'Hello, world!',
                number => 42,
                regex  => $regex,
                glob   => $glob,
                array  => [ 'one', 'two', { three => 'four', five => { six => 'seven' } }, [ 'eight', ['nine'] ] ],
                object => $object,
            }
        },
        baz => 'quux',
    };

    my $want = {
        'baz'                      => 'quux',
        'foo.bar.array.0'          => 'one',
        'foo.bar.array.1'          => 'two',
        'foo.bar.array.2.five.six' => 'seven',
        'foo.bar.array.2.three'    => 'four',
        'foo.bar.array.3.0'        => 'eight',
        'foo.bar.array.3.1.0'      => 'nine',
        'foo.bar.glob'             => $glob,
        'foo.bar.number'           => 42,
        'foo.bar.object'           => $object,
        'foo.bar.regex'            => $regex,
        'foo.bar.string'           => 'Hello, world!'
    };

    my $got = $folder->fold($hash);
    is_deeply $folder->unfold($got), $hash; # roundtrip
    is_deeply $got, $want;
}

# seeing a value more than once is not the same thing as seeing a value inside itself
# (circular reference). make sure the former doesn't trigger the callback associated
# with the latter
{
    my $seen   = 0;
    my $folder = Hash::Fold->new(on_seen => sub { $seen = 1 });
    my $object = bless {};

    my $hash = {
        a => { b => $object },
        c => { d => $object },
    };

    my $want = {
        'a.b' => $object,
        'c.d' => $object,
    };

    my $got = $folder->fold($hash);
    is_deeply $got, $want;
    is_deeply $folder->unfold($got), $hash; # roundtrip
    is $seen, 0;
}

# on_seen: trigger the circular reference callback (hashref)
{
    my @seen;
    my $on_seen= sub { isa_ok $_[0], 'Hash::Fold'; push @seen, $_[1] };
    my $folder = Hash::Fold->new(on_seen => $on_seen);
    my $circular = { self => undef };

    $circular->{self} = $circular;

    my $hash = {
        a => { b => $circular },
        c => { d => $circular },
    };

    my $want = {
        'a.b.self' => $circular,
        'c.d.self' => $circular,
    };

    my $got = $folder->fold($hash);
    is_deeply $got, $want;

    # FIXME this causes an "Out of memory!" error in perl 5.14.2,
    # but works fine (with the same version of Test::More
    # (and Scalar::Util)) in 5.16.0
    # is_deeply \@seen [ $circular, $circular ];

    is scalar(@seen), 2;
    is $seen[0], $circular; # same ref
    is $seen[1], $circular; # same ref

    is_deeply $folder->unfold($got), $hash; # roundtrip
}

# on_seen: trigger the circular reference callback (arrayref)
{
    my @seen;
    my $on_seen= sub { isa_ok $_[0], 'Hash::Fold'; push @seen, $_[1] };
    my $folder = Hash::Fold->new(on_seen => $on_seen);
    my $circular = [ undef ];

    $circular->[0] = $circular;

    my $hash = {
        a => { b => $circular },
        c => { d => $circular },
    };

    my $want = {
        'a.b.0' => $circular,
        'c.d.0' => $circular,
    };

    my $got = $folder->fold($hash);
    is_deeply $got, $want;
    is_deeply \@seen [ $circular, $circular ];
    is $seen[0], $circular; # same ref
    is $seen[1], $circular; # same ref
    is_deeply $folder->unfold($got), $hash; # roundtrip
}

# on_object: trigger the on_object type for a Regexp, a GLOB, and a blessed object
{
    my @on_object;

    my $on_object = sub {
        my ($folder, $object) = @_;
        isa_ok $folder, 'Hash::Fold';
        push @on_object, $_[1];
        return $object;
    };

    my $folder = Hash::Fold->new(on_object => $on_object);
    my $regexp = qr{foo};
    my $glob = \*STDIN;
    my $object = bless {};

    my $hash = {
        a => { b => $regexp },
        c => { d => $glob },
        e => [ 'foo', $object, 'bar' ],
        f => { g => 42, h => 'Hello, world!' },
    };

    my $want = {
        'a.b' => $regexp,
        'c.d' => $glob,
        'e.0' => 'foo',
        'e.1' => $object,
        'e.2' => 'bar',
        'f.g' => 42,
        'f.h' => 'Hello, world!'
    };

    my $got = $folder->fold($hash);
    is_deeply $got, $want;
    is_deeply \@on_object, [ $regexp, $glob, $object ];
    is_deeply $folder->unfold($got), $hash; # roundtrip
}

# on_object: trigger the on_object type for a terminal and turn it into a non-terminal
{
    my $expand_object = sub {
        my ($folder, $object) = @_;
        isa_ok $folder, 'Hash::Fold';
        isa_ok $object, __PACKAGE__;
        my $expanded = { %$object };
        return $expanded;
    };

    my $folder_without_expand = Hash::Fold->new();
    my $folder_with_expand = Hash::Fold->new(on_object => $expand_object);
    my $object = bless { one => { two => [ qw(three four five) ] } };

    my $hash = {
        a => $object,
        b => 42,
    };

    my $want_without_expand = {
        a => $object,
        b => 42,
    };

    my $want_with_expand = {
        'a.one.two.0' => 'three',
        'a.one.two.1' => 'four',
        'a.one.two.2' => 'five',
        'b'           => 42
    };

    my $got_without_expand = $folder_without_expand->fold($hash);
    my $got_with_expand = $folder_with_expand->fold($hash);

    is_deeply $got_without_expand, $want_without_expand;
    is_deeply $got_with_expand, $want_with_expand;

    # the folder options shouldn't make a difference here as far as unfolding is concerned
    is_deeply $folder_without_expand->unfold($got_without_expand), $hash; # roundtrip
    is_deeply $folder_with_expand->unfold($got_with_expand), $hash; # roundtrip
}

# on_object: combine object expansion with the circular-reference check i.e.
# if we convert an object into an unblessed hashref, we should detect a
# circular reference in that hashref. check that the nested self-reference
# is detected and returned as a terminal
{
    my $expand_object = sub {
        my ($folder, $object) = @_;
        isa_ok $folder, 'Hash::Fold';
        isa_ok $object, __PACKAGE__;
        my $expanded = { %$object };
        $expanded->{self} = $expanded;
        return $expanded;
    };

    my $folder = Hash::Fold->new(on_object => $expand_object);

    my $expanded = {
        foo => { bar => 'baz' },
    };

    $expanded->{self} = $expanded;

    my $hash = {
        a => $expanded,
        b => 42,
    };

    my $want = {
        'a.foo.bar' => 'baz',
        'a.self'    => $expanded,
        'b'         => 42
    };

    my $got = $folder->fold($hash);
    is_deeply $got, $want;
    is_deeply $folder->unfold($got), $hash; # roundtrip
}

done_testing;
