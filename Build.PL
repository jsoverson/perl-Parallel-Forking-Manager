use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Parallel::Forking::Manager',
    license             => 'perl',
    dist_author         => q{Jarrod Overson <jsoverson+cpan@googlemail.com>},
    dist_version_from   => 'lib/Parallel/Forking/Manager.pm',
    build_requires => {
        'Test::More' => 0,
    },
    add_to_cleanup      => [ 'Parallel-Forking-Manager-*' ],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();
