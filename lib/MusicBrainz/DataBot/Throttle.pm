package MusicBrainz::DataBot::Throttle;

require MusicBrainz::DataBot::Log;

our %freq = 
	( 
	 # runedits
	 mbedit => 15,
	 mbsite => 1,
	 mbapi => 1,
	 mberror => 60,
	 editquery => 900,
	 
	 # runtasks
	 mbreplicate => 3600,
	 
	 # runspider
	 flyquery => 900,
	 discogsapi => 10,
	 nodiscogs => 3600
	 );
our $sysstarttime = time();
our %lastrun = ();

sub throttle {
	my (undef, $area) = @_;
	
	return MusicBrainz::DataBot::Log->error("No such throttle area: $area") unless defined $freq{$area};
	$lastrun{$area} = 0 unless defined $lastrun{$area};
	
	my $delay = $freq{$area} - (time() - $lastrun{$area});
	if ($delay > 0) {
		MusicBrainz::DataBot::Log->debug("[$area:$freq{$area}] Sleeping for $delay seconds...");
		sleep($delay);
	}
	
	if ($area eq 'mbedit') {
		MusicBrainz::DataBot::Throttle->throttle('mbsite');
	}

	$lastrun{$area} = time();
	
	return $delay;
}

1;
