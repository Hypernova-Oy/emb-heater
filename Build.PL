use Modern::Perl;
use Module::Build;

my $build = Module::Build->new
    (
     module_name => 'emb-heater',
     dist_author => 'Joonas Kylmälä <joonas.kylmala@jns.fi>',
     dist_abstract => 'Turns on warming pad if it is too cold',

     build_requires => {
	 'Modern::Perl' => '1',
     },

     requires => {
	 'Modern::Perl' => '1',
	 'Time::HiRes' => '1.9',
	 'GPIO' => '0.01',
	 'HiPi::Interface::DS18X20' => '0.22',
	 'Config::Simple' => '4',
	 'Sys::Syslog' => '0.33',
	 'DoubleLatchRelay' => '0.02',
     }

    );

$build->create_build_script;
