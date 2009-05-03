use 5.008;

use strict;
use warnings;
use ExtUtils::MakeMaker;

my @DEFINES;

# Threads, Windows and 5.8.x don't seem to be best friends
if ($^O eq 'MSWin32' && $^V lt v5.9.0) {
 push @DEFINES, '-DI_MULTIPLICITY=0';
}

@DEFINES = (DEFINE => join ' ', @DEFINES) if @DEFINES;

my $dist = 'indirect';

my %META = (
 configure_requires => {
  'ExtUtils::MakeMaker' => 0,
 },
 build_requires => {
  'ExtUtils::MakeMaker' => 0,
  'Test::More'          => 0,
 },
 resources => {
  bugtracker => "http://rt.cpan.org/NoAuth/ReportBug.html?Queue=$dist",
  homepage   => "http://search.cpan.org/dist/$dist/",
  license    => 'http://dev.perl.org/licenses/',
  repository => "http://git.profvince.com/?p=perl%2Fmodules%2F$dist.git",
 },
);

WriteMakefile(
    NAME             => 'indirect',
    AUTHOR           => 'Vincent Pit <perl@profvince.com>',
    LICENSE          => 'perl',
    VERSION_FROM     => 'lib/indirect.pm',
    ABSTRACT_FROM    => 'lib/indirect.pm',
    PL_FILES         => {},
    @DEFINES,
    PREREQ_PM        => {
        'XSLoader' => 0,
    },
    MIN_PERL_VERSION => 5.008,
    META_MERGE       => \%META,
    dist             => {
        PREOP    => 'pod2text lib/indirect.pm > $(DISTVNAME)/README',
        COMPRESS => 'gzip -9f', SUFFIX => 'gz'
    },
    clean            => {
        FILES => "$dist-* *.gcov *.gcda *.gcno cover_db Debian_CPANTS.txt"
    },
);
