use 5.008003;
use strict;
use warnings;

use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'Hash::Fold',
    AUTHOR           => q{chocolateboy <chocolate@cpan.org>},
    VERSION_FROM     => 'lib/Hash/Fold.pm',
    ABSTRACT_FROM    => 'lib/Hash/Fold.pm',
    LICENSE          => 'Artistic_2_0',
    PL_FILES         => {},
    MIN_PERL_VERSION => '5.008003', # required by Moose
    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker' => 0,
    },
    BUILD_REQUIRES => {
        'Test::More'    => 0,
    },
    PREREQ_PM => {
        'Moose'         => 0,
        'Sub::Exporter' => 0,
    },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES => 'Hash-Fold-*' },
);
