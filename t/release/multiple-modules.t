use Test::More;
use strict;
use warnings;

use MetaCPAN::Model;

my $model   = MetaCPAN::Model->new( es => ':9900' );
my $idx     = $model->index('cpan');
my $release = $idx->type('release')->get(
    {   author => 'LOCAL',
        name   => 'Multiple-Modules-1.01'
    }
);

is( $release->name, 'Multiple-Modules-1.01', 'name ok' );

is( $release->author, 'LOCAL', 'author ok' );

ok(!$release->first, 'Release is not first');

{
    my @files = $idx->type('file')->filter(
        {   and => [
                { term   => { 'file.author'  => $release->author } },
                { term   => { 'file.release' => $release->name } },
                { exists => { field          => 'file.module.name' } },
            ]
        }
    )->all;
    is( @files, 3, 'includes three files with modules' );

    @files = sort { $a->{name} cmp $b->{name} } @files;

    foreach my $test (
        ['A.pm', 'Multiple::Modules::A', [
            {name => 'Multiple::Modules::A',  indexed => 1},
            {name => 'Multiple::Modules::A2', indexed => 1},
        ]],
        ['B.pm', 'Multiple::Modules::B', [
            {name => 'Multiple::Modules::B',  indexed => 1},
           #{name => 'Multiple::Modules::_B2', indexed => 0}, # hidden
            {name => 'Multiple::Modules::B::Secret', indexed => 0},
        ]],
        ['Modules.pm', 'Multiple::Modules', [
            {name => 'Multiple::Modules', indexed => 1},
        ]],
    ){
        my ($basename, $doc, $expmods) = @$test;

        my $file = shift @files;
        is( $file->name,           $basename, 'file name' );
        is( $file->documentation,  $doc,      'documentation ok' );

        is( scalar @{ $file->module },
            scalar @$expmods,
            'correct number of modules' );

        foreach my $expmod ( @$expmods ){
            my $mod = shift @{ $file->module };
            is( $mod->name,    $expmod->{name},    'module name ok' );
            is( $mod->indexed, $expmod->{indexed}, 'module indexed (or not)' );
        }
            
        is( scalar @{ $file->module }, 0, 'all mods tested' );
    }
}

done_testing;
