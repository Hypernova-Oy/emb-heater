package Heater::Exception::Hardware::HeatingElement;

use Modern::Perl;

use Exception::Class (
    'Heater::Exception::Hardware::HeatingElement' => {
        isa => 'Heater::Exception::Hardware',
        fields => ['expectedTemperatureRise', 'biggestMeasuredTemperatureRise', 'heatingDuration'],
    },
);

1;
