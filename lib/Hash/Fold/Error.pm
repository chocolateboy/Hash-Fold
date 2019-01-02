package Hash::Fold::Error;

use Moo;
extends 'Throwable::Error';

# XXX this declaration must be on a single line
# https://metacpan.org/pod/version#How-to-declare()-a-dotted-decimal-version
use version 0.77; our $VERSION = version->declare('v1.0.0');

has path => (
    is => 'ro',
);

has type => (
    is => 'ro',
);

1;

__END__

=head1 NAME

 Hash::Fold::Error

=head1 SYNOPSIS

  use Hash::Fold::Error;

  Hash::Fold::Error->throw($message);
  Hash::Fold::Error->throw({
                    message => $message,
                    path => $path,
                    type => $type,
  });

=head1 DESCRIPTION

L<Hash::Fold> will throw on object instantiated from this class on error.

=head1 ATTRIBUTES

=head3 path

If the C<path> attribute is defined, the error was thrown during
merging or unfolding, and indicates the location in the structure
which was inappropriately used as an array or a hash.

L</type> is set to either C<array> or C<hash>.

=head3 type

When defined, C<type> indicates the type of the structure
that caused the error.

=head1 AUTHOR

chocolateboy <chocolate@cpan.org>

=head1 COPYRIGHT

Copyright (c) 2018 by chocolateboy.

This is free software; you can redistribute it and/or modify it under the
terms of the Artistic License 2.0.

=cut

