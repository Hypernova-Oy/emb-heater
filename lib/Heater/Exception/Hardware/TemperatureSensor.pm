package Heater::Exception::Hardware::TemperatureSensor;

use Modern::Perl;

use Exception::Class (
    'Heater::Exception::Hardware::TemperatureSensor' => {
        isa => 'Heater::Exception::Hardware',
        fields => ['sensorId'],
    },
);

1;
