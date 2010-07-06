package MusicBrainz::DataBot::EditBot;

use Moose;

use MusicBrainz::DataBot::Edit::BaseEditTask;

extends 'MusicBrainz::DataBot::BaseTaskApp';

has '+runner_class' => (default => sub { MusicBrainz::DataBot::Edit::BaseEditTask->meta } );
has '+task_table' => (default => 'mbot.edits');

1;
