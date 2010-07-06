package MusicBrainz::DataBot::Spider::BaseSpiderTask;

use Moose;

extends 'MusicBrainz::DataBot::BaseTask';

has '+schema' => (default => 'mspider');

# Types
require MusicBrainz::DataBot::Spider::DiscogsRelease;

1;
