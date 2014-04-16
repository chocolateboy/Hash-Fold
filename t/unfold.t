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

    my $want = {
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

    my $got = $folder->unfold($hash);
    is_deeply $got, $want;
    is_deeply $folder->fold($got), $hash; # roundtrip
}

done_testing;
