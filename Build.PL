use Modern::Perl;
use Module::Build;

my $build = Module::Build->new(

    module_name => 'Heater',
    dist_author => ['Joonas Kylmälä <joonas.kylmala@jns.fi>',
                     'Olli-Antti Kivilahti <olli-antti.kivilahti@jns.fi>'],
    dist_abstract => 'Turns on warming pad if it is too cold',

    build_requires => {
        'Modern::Perl' => '1',
    },

    requires => {
        'Modern::Perl'             => '> 0.01',
        'Time::HiRes'              => '> 0.01',
        'GPIO'                     => '> 0.01',
        'GPIO::Relay::DoubleLatch' => '> 0.01',
        'HiPi::Interface::DS18X20' => '> 0.01',
        'Config::Simple'           => '> 0.01',
        'Test::MockModule'         => '> 0.01',
        'Proc::PID::File'          => '> 0.01',
        'File::Temp'               => '> 0.01',
        'Exception::Class'         => '> 0.01',
    },

);

$build->create_build_script;
