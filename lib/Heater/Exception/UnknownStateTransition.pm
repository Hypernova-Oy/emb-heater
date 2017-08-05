package Heater::Exception::UnknownStateTransition;

use Modern::Perl;

use Exception::Class (
    'Heater::Exception::UnknownStateTransition' => {
        isa => 'Heater::Exception',
        fields => ['previousState'],
    },
);

1;
