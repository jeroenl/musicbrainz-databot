package MusicBrainz::DataBot::Spider::BaseSpiderTask;

use Moose;

# Types
require MusicBrainz::DataBot::Spider::DiscogsRelease;

extends 'MusicBrainz::DataBot::BaseTask';

sub schema {
	return 'mspider';
}

1;
