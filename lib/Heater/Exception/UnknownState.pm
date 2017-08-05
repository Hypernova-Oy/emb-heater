package Heater::Exception::UnknownState;

use Modern::Perl;

use Exception::Class (
    'Heater::Exception::UnknownState' => {
        isa => 'Heater::Exception',
        fields => qw(state),
    },
);

1;
