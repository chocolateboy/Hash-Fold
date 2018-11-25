# Hash::Fold

[![Build Status](https://secure.travis-ci.org/chocolateboy/Hash-Fold.svg)](http://travis-ci.org/chocolateboy/Hash-Fold)
[![CPAN Version](https://badge.fury.io/pl/Hash-Fold.svg)](http://badge.fury.io/pl/Hash-Fold)
[![License](https://img.shields.io/badge/license-artistic-blue.svg)](https://github.com/chocolateboy/Hash-Fold/blob/master/LICENSE.md)

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [NAME](#name)
- [SYNOPSIS](#synopsis)
- [DESCRIPTION](#description)
- [OPTIONS](#options)
  - [array_delimiter](#array_delimiter)
  - [hash_delimiter](#hash_delimiter)
  - [delimiter](#delimiter)
  - [on_cycle](#on_cycle)
  - [on_object](#on_object)
- [EXPORTS](#exports)
  - [fold](#fold)
  - [flatten](#flatten)
  - [unfold](#unfold)
  - [unflatten](#unflatten)
  - [merge](#merge)
- [METHODS](#methods)
  - [is_object](#is_object)
- [VERSION](#version)
- [SEE ALSO](#see-also)
- [AUTHOR](#author)
- [COPYRIGHT](#copyright)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

# NAME

Hash::Fold - flatten and unflatten nested hashrefs

# SYNOPSIS

```perl
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

is_deeply $flattened, {
    'baz.a'     => 'b',
    'baz.c.0'   => 'd',
    'baz.c.1.e' => 'f',
    'baz.c.2'   => 42,
    'foo'       => $object,
};

my $roundtrip = unflatten($flattened);

is_deeply $roundtrip, $nested;
```

# DESCRIPTION

This module provides functional and OO interfaces which can be used to flatten,
unflatten and merge nested hashrefs.

Unless noted, the functions listed below are also available as methods. Options
provided to the Hash::Fold constructor can be supplied to the functions e.g.:

```perl
use Hash::Fold;

my $folder = Hash::Fold->new(delimiter => '/');

$folder->fold($hash);
```

is equivalent to:

```perl
use Hash::Fold qw(fold);

my $folded = fold($hash, delimiter => '/');
```

Options (and constructor args) can be supplied as a list of key/value pairs or
a hashref, so the following are equivalent:

```perl
my $folded = fold($hash,   delimiter => '/'  );
my $folded = fold($hash, { delimiter => '/' });
```

In addition, Hash::Fold uses [Sub::Exporter](https://metacpan.org/pod/Sub::Exporter), which allows functions to be
imported with options baked in e.g.:

```
use Hash::Fold fold => { delimiter => '/' };

my $folded = fold($hash);
```

# OPTIONS

As described above, the following options can be supplied as constructor args,
import args, or per-function overrides. Under the hood, they are ([Moo](https://metacpan.org/pod/Moo))
attributes which can be wrapped and overridden like any other attributes.

## array_delimiter

**Type**: Str, ro, default: "."

The delimiter prefixed to array elements when flattening and unflattening.

## hash_delimiter

**Type**: Str, ro, default: "."

The delimiter prefixed to hash elements when flattening and unflattening.

## delimiter

**Type**: Str

This is effectively a write-only attribute which assigns the same string to
[`array_delimiter`](#array_delimiter) and [`hash_delimiter`](#hash_delimiter). It can only be supplied as a
constructor arg or function option (which are equivalent) i.e. Hash::Fold
instances have no `delimiter` method.

## on_cycle

**Type**: (Hash::Fold, Ref) → None, ro

A callback invoked whenever [`fold`](#fold) encounters a circular reference i.e. a
reference which contains itself as a nested value.

The callback is passed two arguments: the Hash::Fold instance and the value e.g.:

```perl
sub on_cycle {
    my ($folder, $value) = @_;
    warn 'self-reference found: ', Dumper(value), $/;
}

my $folder = Hash::Fold->new(on_cycle => \&on_cycle);
```

Note that circular references are handled correctly i.e. they are treated as
terminals and not traversed. This callback merely provides a mechanism to
report them (e.g. by issuing a warning).

The default callback does nothing.

## on_object

**Type**: (Hash::Fold, Ref) → Any, ro

A callback invoked whenever [`fold`](#fold) encounters a value for which the
[`is_object`](#is_object) method returns true i.e. any reference that isn't an unblessed
arrayref or unblessed hashref. This callback can be used to modify
the value e.g. to return a traversable value (e.g. unblessed hashref)
in place of a terminal (e.g.  blessed hashref).

The callback is passed two arguments: the Hash::Fold instance and the object e.g.:

```perl
use Scalar::Util qw(blessed);

sub on_object {
    my ($folder, $value) = @_;

    if (blessed($value) && $value->isa('HASH')) {
        return { %$value }; # unbless
    } else {
        return $value;
    }
}

my $folder = Hash::Fold->new(on_object => \&on_object);
```

The default callback returns its value unchanged.

# EXPORTS

Nothing by default. The following functions can be imported.

## fold

**Signature**: (HashRef \[, Hash|HashRef \]) → HashRef

Takes a nested hashref and returns a single-level hashref with (by default)
dotted keys. The delimiter can be overridden via the [`delimiter`](#delimiter),
[`array_delimiter`](#array_delimiter) and [`hash_delimiter`](#hash_delimiter) options.

Unblessed arrayrefs and unblessed hashrefs are traversed. All other values
(e.g. strings, regexps, objects &c.) are treated as terminals and passed
through verbatim, although this can be overridden by supplying a suitable
[`on_object`](#on_object) callback.

## flatten

**Signature**: (HashRef \[, Hash|HashRef \]) → HashRef

Provided as an alias for [`fold`](#fold).

## unfold

**Signature**: (HashRef \[, Hash|HashRef \]) → HashRef

Takes a flattened hashref and returns the corresponding nested hashref.

## unflatten

**Signature**: (HashRef \[, Hash|HashRef \]) → HashRef

Provided as an alias for [`unfold`](#unfold).

## merge

**Signature**: (HashRef \[, HashRef... \]) → HashRef

**Signature**: (ArrayRef\<HashRef\> \[, Hash|HashRef \]) → HashRef

Takes a list of hashrefs which are then flattened, merged into one (in the
order provided i.e.  with precedence given to the rightmost arguments) and
unflattened i.e. shorthand for:

```perl
unflatten { map { %{ flatten $_ } } @_ }
```

To provide options to the `merge` subroutine, pass the hashrefs in an
arrayref, and the options (as usual) as a list of key/value pairs or a hashref:

```perl
merge([ $hash1, $hash2, ... ],   delimiter => ...  )
merge([ $hash1, $hash2, ... ], { delimiter => ... })
```

# METHODS

## is_object

**Signature**: Any → Bool

This method is called from [`fold`](#fold) to determine whether a value should be
passed to the [`on_object`](#on_object) callback.

It is passed each value encountered while traversing a hashref and returns true
for all references (e.g.  regexps, globs, objects &c.) apart from unblessed
arrayrefs and unblessed hashrefs, and false for all other
values (i.e. unblessed hashrefs, unblessed arrayrefs, and non-references).

# VERSION

1.0.0

# SEE ALSO

* [CGI::Expand](https://metacpan.org/pod/CGI::Expand)
* [Hash::Flatten](https://metacpan.org/pod/Hash::Flatten)
* [Hash::Merge](https://metacpan.org/pod/Hash::Merge)
* [Hash::Merge::Simple](https://metacpan.org/pod/Hash::Merge::Simple)

# AUTHOR

[chocolateboy](mailto:chocolate@cpan.org)

# COPYRIGHT

Copyright © 2014-2018 by chocolateboy.

This is free software; you can redistribute it and/or modify it under the
terms of the [Artistic License 2.0](http://www.opensource.org/licenses/artistic-license-2.0.php).
