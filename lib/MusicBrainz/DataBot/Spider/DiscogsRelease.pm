package MusicBrainz::DataBot::Spider::DiscogsRelease;

use Moose;
use WWW::Discogs;

use List::Uniq 'uniq';

extends 'MusicBrainz::DataBot::Spider::BaseSpiderTask';

has 'discogs' => (is => 'ro', lazy => 1, builder => '_build_discogs');
has '+type' => (default => 'tasks_discogs_release');
		  
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
	$sql->Commit;
	
	$sql->Begin;
	
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
		 
	foreach my $artist (uniq @{$release->{'artists'}->{'artist'}}) {
		$sql->InsertRow('discogs.releases_artists',
			{discogs_id => $release->{'id'},
			 artist_name => $artist->{'name'}
			});
		$self->debug("Artist: $artist->{name}");
	}
	
	if ($release->{'formats'}) {
		foreach my $format (@{$release->{'formats'}->{'format'}}) {
			$sql->InsertRow('discogs.releases_formats',
				{discogs_id => $release->{'id'},
				 format_name => $format->{'name'},
				 qty => $format->{'qty'},
				 descriptions => $self->quote_array($format->{'descriptions'}->{'description'})
				});
		}
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
	my @albumseqs;
	my @disctrackcount;
	
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
		
		push @albumseqs, $albumseq;
		$disctrackcount[$albumseq]++;
		
		$self->debug("$track->{position}. $track->{title}");
		
		my $durationms;
		if ($track->{'duration'} =~ /(?:([0-9]+):)?([0-9]+):([0-9]+)/) {
			$durationms = ((defined $1 ? $1 * 3600 : 0) + ($2 * 60) + $3) * 1000;
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
	
	my $positionchars = join '', @positions;
	
	foreach my $artist (@{$release->{'extraartists'}->{'artist'}}) {
		foreach my $role ($artist->{'role'} =~ /([^, ]+[^[,]*(?:\[[^]]+])?)+/g) {
			my $role_name = $role;
			my $role_details;
			
			if ($role =~ /(.*) \[(.*)\]/) {
				$role_name = $1;
				$role_details = $2;
			}
			
			if (defined $artist->{'tracks'} && $artist->{'tracks'} ne 'CD') {
				$artist->{'tracks'} =~ s/[&;]/,/g;
				$artist->{'tracks'} =~ s/([A-NP-Z0-9]) ([A-SU-Z0-9])/$1,$2/gi unless $positionchars =~ / /;
			
				foreach my $trackrange (split ',', $artist->{'tracks'}) {
					$trackrange =~ s/^ +//;
					$trackrange =~ s/ +$//;
					
					my $first = $trackrange;
					my $last;
					
					if ($trackrange =~ /(.*) to (.*)/i || $trackrange =~ /(.*) - (.*)/
						|| $trackrange =~ /(.*)- (.*)/ || $trackrange =~ /(.*) -(.*)/
						|| (!($positionchars =~ /-/) && $trackrange =~ /(.*)-(.*)/)) {
						$first = $1;
						$last = $2;
					}
					
					my $posstr = $first;
					if (defined $last) {
						$posstr .= "-$last";
					}
					
					$self->debug_role($posstr, $artist, $role_name, $role_details);
					
					my @matchingtracks;
					my @roledisctrackcount;
					
					my $found = 0;
					for (my $i=0;$i<=$#track_ids;$i++) {
						my $posstr = $positions[$i];
						
						$posstr = $self->clean_position($posstr);
						$first = $self->clean_position($first);
						$last = $self->clean_position($last) if defined $last;
						
						if (!$found && $posstr eq $first) {
							$found = 1;
						}
						
						if ($found) {
							push @matchingtracks, $i;
							$roledisctrackcount[$albumseqs[$i]]++;
						}
						
						if ($found && (!defined $last || $posstr eq $last)) {
							$found = 2;
							last;
						}
					}
					
					if ($found != 2) {
						return $self->report_failure($task->{'id'}, "Could not match track range: $trackrange");
					}
					
					foreach my $i (@matchingtracks) {
						$sql->InsertRow('discogs.tracks_extraartists_roles',
							{track_id => $track_ids[$i],
							 role_name => $role_name,
							 role_details => $role_details,
							 artist_name => $artist->{'name'},
							 artist_alias => $artist->{'anv'},
							 is_disc_role => ($roledisctrackcount[$albumseqs[$i]] 
							 			== $disctrackcount[$albumseqs[$i]]) ? 1 : 0
							});
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

sub clean_position {
	my ($self, $pos) = @_;
	
	$pos =~ s/^(CD)?0*//;
	$pos =~ s/\.0+/./g;
	$pos =~ s/-0+/-/g;
	
	return $pos;
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
	
	return $self->debug("$pos $name: $role_name");
}

# Var builders
sub _build_discogs { 
	my $self = shift;
	my $config = $self->config;
	
	return WWW::Discogs->new(apikey => $config->get_config('discogs_apikey'));
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;
