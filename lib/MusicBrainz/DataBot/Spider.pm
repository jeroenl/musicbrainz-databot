package MusicBrainz::DataBot::Spider;

use Moose;

use MusicBrainz::DataBot::Spider::BaseSpiderTask;

extends 'MusicBrainz::DataBot::BaseTaskApp';

has '+runner_class' => (default => sub { MusicBrainz::DataBot::Spider::BaseSpiderTask->meta } );
has '+task_table' => (default => 'mspider.tasks');

1;
