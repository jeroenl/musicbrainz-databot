package MusicBrainz::DataBot::Spider;

use Moose;

use MusicBrainz::DataBot::Spider::BaseSpiderTask;

extends 'MusicBrainz::DataBot::BaseTaskApp';

has '+runner_class' => (default => sub { MusicBrainz::DataBot::Spider::BaseSpiderTask->meta } );
has '+task_table' => (default => 'mspider.tasks');

__PACKAGE__->meta->make_immutable;
no Moose;

1;
