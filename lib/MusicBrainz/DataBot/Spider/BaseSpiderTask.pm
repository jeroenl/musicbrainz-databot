package MusicBrainz::DataBot::Spider::BaseSpiderTask;

use Moose;

extends 'MusicBrainz::DataBot::BaseTask';

has '+schema' => (default => 'mspider');

# Types
require MusicBrainz::DataBot::Spider::DiscogsRelease;

__PACKAGE__->meta->make_immutable;
no Moose;

1;
