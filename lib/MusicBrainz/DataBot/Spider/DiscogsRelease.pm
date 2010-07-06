package MusicBrainz::DataBot::Spider::DiscogsRelease;

use Moose;
use MusicBrainz::DataBot::BotConfig;

use WWW::Discogs;

extends 'MusicBrainz::DataBot::Spider::BaseSpiderTask';

has 'discogs' => (is => 'ro', default => sub { return WWW::Discogs->new(apikey => MusicBrainz::DataBot::BotConfig->DISCOGS_APIKEY); } );
has '+type' => (default => 'tasks_discogs_release');
has '+query' => 
	(default => sub { 
	  	my $self = shift;
	  	return 'SELECT e.id, e.discogs_id
			  FROM ' . $self->schema . '.' . $self->type . ' e
			  WHERE date_processed IS NULL
			  ORDER BY e.id ASC
			  LIMIT 50'; });
		  
sub run_task {
	my ($self, $task) = @_;
	my $bot = $self->bot;
	my $discogs = $self->discogs;
	my $sql = $self->sql;
	
	$self->debug('-'x50);
	$self->debug("Processing task $task->{id}");
	
	$self->throttle('discogsapi');
	my $release = $discogs->release($task->{'discogs_id'});
	unless (defined $release) {
		$self->error('Could not retrieve Discogs data');
		$self->throttle('nodiscogs');
		return;
	}

	$self->utf8_encode($release);
	
	$self->debug("Release $release->{id}: $release->{title}");

	$sql->Begin;
	$sql->Do('DELETE FROM discogs.release WHERE discogs_id=' . int($release->{'id'}));
	
	$sql->InsertRow('discogs.release', 
		{discogs_id => $release->{'id'},
		 status => $release->{'status'},
		 title => $release->{'title'},
		 country => $release->{'country'},
		 released => $release->{'released'},
		 notes => $release->{'notes'},
		 genres => $self->quote_array($release->{'genres'}->{'genre'}),
		 styles => $self->quote_array($release->{'styles'}->{'style'})
		});
		
	$sql->InsertRow('discogs.discogs_release_url', 
		{discogs_id => $release->{'id'},
		 url => 'http://www.discogs.com/release/' . $release->{'id'}
		});
		 
	foreach my $artist (@{$release->{'artists'}->{'artist'}}) {
		$sql->InsertRow('discogs.releases_artists',
			{discogs_id => $release->{'id'},
			 artist_name => $artist->{'name'}
			});
		$self->debug("Artist: $artist->{name}");
	}
		 
	foreach my $format (@{$release->{'formats'}->{'format'}}) {
		$sql->InsertRow('discogs.releases_formats',
			{discogs_id => $release->{'id'},
			 format_name => $format->{'name'},
			 qty => $format->{'qty'},
			 descriptions => $self->quote_array($format->{'descriptions'}->{'description'})
			});
	}
	
	foreach my $label (@{$release->{'labels'}->{'label'}}) {
		$sql->InsertRow('discogs.releases_labels',
			{discogs_id => $release->{'id'},
			 label => $label->{'name'},
			 catno => $label->{'catno'}
			});
	}
	
	my @track_ids;
	my @positions;
	
	my $albumseq = 0;
	my $trackseq = 0;
	my $lastdiscmarker = '';
	my $albumseq_enabled = 1;
	foreach my $track (@{$release->{'tracklist'}->{'track'}}) {
		unless ($track->{'position'}) {
			$self->info("Skipping track: $track->{title} (no position)");
			next;
		}
	
		my $track_id = $self->gen_uuid;
		
		push @track_ids, $track_id;
		push @positions, $track->{'position'};
		
		$trackseq++;
		
		if ($albumseq_enabled && $track->{'position'} =~ /(.*)[.-][^.-]+$/) {
			unless ($1 eq $lastdiscmarker) {
				$lastdiscmarker = $1;
				$albumseq++;
				$trackseq = 1;
				$self->debug("Disc $albumseq ($lastdiscmarker)");
			}
		}
		
		if ($albumseq == 0) {
			$albumseq = 1;
			$albumseq_enabled = 0;
		}
		
		$self->debug("$track->{position}. $track->{title}");
		
		my $durationms;
		if ($track->{'duration'} =~ /([0-9]+):([0-9]+)/) {
			$durationms = ($1 + ($2 * 60)) * 1000;
		}
				
		$sql->InsertRow('discogs.track',
			{discogs_id => $release->{'id'},
			 title => $track->{'title'},
			 duration => $track->{'duration'},
			 position => $track->{'position'},
			 track_id => $track_id,
			 albumseq => $albumseq,
			 trackseq => $trackseq,
			 durationms => $durationms
			});
		
		foreach my $trackartist (@{$track->{'extraartists'}->{'artist'}}) {
			foreach my $role ($trackartist->{'role'} =~ /([^, ]+[^[,]*(?:\[[^]]+])?)+/g) {
				my $role_name = $role;
				my $role_details;
				
				if ($role =~ /(.*) \[(.*)\]/) {
					$role_name = $1;
					$role_details = $2;
				}
			
				$self->debug_role('-', $trackartist, $role_name, $role_details);

				$sql->InsertRow('discogs.tracks_extraartists_roles',
					{track_id => $track_id,
					 role_name => $role_name,
					 role_details => $role_details,
					 artist_name => $trackartist->{'name'},
					 artist_alias => $trackartist->{'anv'}
					});
			}
		}
	}
	
	foreach my $artist (@{$release->{'extraartists'}->{'artist'}}) {
		foreach my $role ($artist->{'role'} =~ /([^, ]+[^[,]*(?:\[[^]]+])?)+/g) {
			my $role_name = $role;
			my $role_details;
			
			if ($role =~ /(.*) \[(.*)\]/) {
				$role_name = $1;
				$role_details = $2;
			}
			
			if (defined $artist->{'tracks'}) {
				foreach my $trackrange (split ', ', $artist->{'tracks'}) {
					my $first = $trackrange;
					my $last;
					
					if ($trackrange =~ /(.*) to (.*)/) {
						$first = $1;
						$last = $2;
					}
					
					my $posstr = $first;
					$posstr .= "-$last", if defined $last;
					
					$self->debug_role($posstr, $artist, $role_name, $role_details);
					
					my $found = 0;
					for (my $i=0;$i<=$#track_ids;$i++) {
						if (!$found && $positions[$i] eq $first) {
							$found = 1;
						}
						
						if ($found) {
							$sql->InsertRow('discogs.tracks_extraartists_roles',
								{track_id => $track_ids[$i],
								 role_name => $role_name,
								 role_details => $role_details,
								 artist_name => $artist->{'name'},
								 artist_alias => $artist->{'anv'}
								});
						}
						
						if ($found && (!defined $last || $positions[$i] eq $last)) {
							$found = 0;
							last;
						}
					}
					
					if ($found) {
						return $self->report_failure($task->{'id'}, "Could not match track range: $trackrange");
					}					
				}
			} else {
				$self->debug_role('*', $artist, $role_name, $role_details);
				$sql->InsertRow('discogs.releases_extraartists_roles',
					{discogs_id => $release->{'id'},
					 role_name => $role_name,
					 role_details => $role_details,
					 artist_name => $artist->{'name'},
					 artist_alias => $artist->{'anv'}
					});
			}
		}
	}

	$sql->Commit;
		 
	return $self->report_success($task->{'id'});
}

sub debug_role {
	my ($self, $pos, $artist, $role_name, $role_details) = @_;
	
	if (defined $role_details) {
		$role_name .= " ($role_details)";
	}
	
	my $name = $artist->{'name'};
	if (defined $artist->{'anv'}) {
		$name .= " ($artist->{anv})";
	}
	
	$self->debug("$pos $name: $role_name");
}

1;
