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
        'Modern::Perl' => '1',
        'Time::HiRes' => '1.9',
        'GPIO' => '0.01',
        'GPIO::Relay::DoubleLatch' => '0.02',
        'HiPi::Interface::DS18X20' => '0.22',
        'Config::Simple' => '4',
        'Sys::Syslog' => '0.33',
        'Test::MockModule' => '0.11',
        'Proc::PID::File' => '1.28',
        'File::Temp' => '0.2304',
    },

);

$build->create_build_script;
