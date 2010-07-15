package MusicBrainz::DataBot::Edit::RelationshipTrack;

use Moose;
use WebService::MusicBrainz::Artist;
use WebService::MusicBrainz::Track;

extends 'MusicBrainz::DataBot::Edit::BaseEditTask';

has '+type' => (default => 'edits_relationship_track');
has '+query' => 
	(default => sub { 
	  	my $self = shift;
	  	return 'SELECT e.id id, e.link0gid, e.link0type, e.link1gid, e.link1type, e.linktype, 
				l.linkphrase, l.name linkname, e.release, e.source, e.sourceurl
			  FROM ' . $self->schema . '.' . $self->type . ' e, musicbrainz.lt_artist_track l, 
					musicbrainz.track t, musicbrainz.albumjoin aj
			  WHERE e.linktype = l.id AND date_processed IS NULL
			  AND release = (SELECT MIN(release) FROM ' . $self->schema . '.' . $self->type . ' WHERE date_processed IS NULL)
			  AND t.gid = e.link1gid AND aj.album = release AND aj.track = t.id
			  ORDER BY aj.sequence, e.id'; });

sub run_task {
	my ($self, $edit) = @_;
	my $bot = $self->bot;
	my $sql = $self->sql;
	
	$self->debug("Processing edit $edit->{id}");
	
	my $note = $self->note_text($edit);
	$self->debug("Note:\n" . $note);
	
	if (!defined $note) {
		return;
	}
	
	unless ($self->validate($edit)) {
		return;
	}
	
	$edit->{'trackid'} = $self->_find_official_id($edit->{'link1type'}, $edit->{'link1gid'});
	
	my $releasegid = $sql->SelectSingleValue("SELECT gid FROM album WHERE id=$edit->{release}");
	my $link0id = $self->_find_official_id($edit->{'link0type'}, $edit->{'link0gid'});
	my $releaseid = $self->_find_official_id('release', $releasegid);
	
	return $self->report_failure($edit->{'id'}, 'Could not find official link0 ID') unless defined $link0id;
	
	unless (defined $releaseid) {
		$self->report_failure($edit->{'id'}, 'Could not find official release ID');
		return;
	}
	
	$self->throttle('mbsite');
	$bot->get("http://musicbrainz.org/edit/relationship/add.html?link0=$edit->{link0type}=$link0id&link1=album=$releaseid&returnto=1&usetracks=0");
	$self->check_login;
	
	my $edit_form = $bot->form_with_fields(qw/linktypeid link0 link1/);
	if (!defined $edit_form) {
		return $self->report_failure($edit->{'id'}, 'Could not find edit form');
	}
	
	$edit_form->accept_charset('iso-8859-1');
	
	my $typeinput = $edit_form->find_input('linktypeid');
	my $foundtype = 0;

	foreach my $type ($typeinput->value_names) {
		my $clean_mbtype = $type;
		my $clean_mytype = $edit->{'linkphrase'};
		
		$clean_mbtype =~ s/^\s*//g;
		$clean_mbtype =~ s/{[^}]+} ?//g;
		$clean_mytype =~ s/{[^}]+} ?//g;
		
		if ($clean_mbtype eq $clean_mytype) {
			$typeinput->value($type);
			$foundtype = 1;
			last;
		}
	}
	
	$self->report_failure($edit->{'id'}, 'Could not find relation type') unless $foundtype;
	
	if ($edit->{'source'} eq 'discogs-trackrole') {
		my $role = $sql->SelectSingleValue(
			"SELECT txr.role_details
				FROM discogs.track d_t, discogs.dmap_track, discogs.discogs_release_url rel_url,
					discogs.tracks_extraartists_roles txr, discogs.dmap_artist,
					discogs.dmap_role, musicbrainz.lt_artist_track lt
				WHERE dmap_track.d_track = d_t.track_id
					AND rel_url.discogs_id = d_t.discogs_id
					AND txr.track_id = d_t.track_id AND txr.artist_name = dmap_artist.d_artist
					AND COALESCE(txr.artist_alias, '') = COALESCE(dmap_artist.d_alias, '')
					AND dmap_role.link_name = lt.name AND dmap_role.role_name = txr.role_name
					AND dmap_artist.mb_artist = '$edit->{link0gid}'
					AND dmap_track.mb_track = '$edit->{link1gid}'
					AND rel_url.url = '$edit->{sourceurl}' 
					AND lt.id = $edit->{linktype}
				LIMIT 1"
			);
			
		if (defined $role) {
			if ($role =~ /addit/i) {
				my $additionalfield = $edit_form->find_input('attr_additional_0');
				if (defined $additionalfield) {
					$additionalfield->check;
					$self->debug("Role is additional ($role)");
				} else {
					$self->report_failure($edit->{'id'}, 'Could not find additional field');
				}
			}
			if ($role =~ /assist/i) {
				my $additionalfield = $edit_form->find_input('attr_assistant_0');
				if (defined $additionalfield) {
					$additionalfield->check;
					$self->debug("Role is assistant ($role)");
				} else {
					$self->report_failure($edit->{'id'}, 'Could not find additional field');
				}
			}
			if ($role =~ /exec/i) {
				my $additionalfield = $edit_form->find_input('attr_executive_0');
				if (defined $additionalfield) {
					$additionalfield->check;
					$self->debug("Role is executive ($role)");
				} else {
					$self->report_failure($edit->{'id'}, 'Could not find additional field');
				}
			}
			if ($role =~ /(guest|featur)/i) {
				my $additionalfield = $edit_form->find_input('attr_guest_0');
				if (defined $additionalfield) {
					$additionalfield->check;
					$self->debug("Role is guest ($role)");
				} else {
					$self->report_failure($edit->{'id'}, 'Could not find additional field');
				}
			}
			if ($role =~ /associate/i) {
				my $additionalfield = $edit_form->find_input('attr_associate_0');
				if (defined $additionalfield) {
					$additionalfield->check;
					$self->debug("Role is associate ($role)");
				} else {
					$self->report_failure($edit->{'id'}, 'Could not find additional field');
				}
			}
		}
	}
	
	my $trackfield = $edit_form->find_input('track' . $edit->{'trackid'});
		
	if (defined $trackfield) {
		$trackfield->check;
		$self->info("Edit $edit->{id}: Adding relationship $edit->{link0gid}\->$edit->{linkname}\->$edit->{link1gid}");
	} else {
		$self->report_failure($edit->{'id'}, 'Could not find track on edit page');
		return;
	}
	
	$bot->set_fields( 'notetext' => $note );
	
	$self->throttle('mbedit');
	my $submitbutton = $bot->current_form()->find_input( '#btnYes', 'submit' );
	return $self->report_failure($edit->{'id'}, 'Could not find submit button') unless defined $submitbutton;
	
	$bot->click_button( 'input' => $submitbutton );
	
	if ($bot->title =~ /^Create Relationship/) {
		return $self->report_failure($edit->{'id'}, 'Edit was rejected');
	}
	
	return $self->report_success($edit->{'id'});
}

sub validate {
	my ($self, $edit) = @_;
	my $sql = $self->sql;
	
	if ($edit->{'source'} eq 'discogs-trackrole') {
		my $ws = WebService::MusicBrainz::Track->new;
		$self->throttle('mbapi');
		my $track = $ws->search({ MBID => $edit->{'link1gid'}, INC => "$edit->{link0type}-rels" });
		$self->report_failure($edit->{'id'}, 'Could not find track on MusicBrainz WS') unless defined $track;
		$track = $track->track;
		
		$edit->{'ws1'} = $track;
		
		my $artist_equiv = $sql->SelectSingleColumnArray("SELECT equiv FROM mbot.mbmap_artist_equiv WHERE artist='$edit->{link0gid}'");
		my $artist_equiv_rev = $sql->SelectSingleColumnArray("SELECT artist FROM mbot.mbmap_artist_equiv WHERE equiv='$edit->{link0gid}'");
		
		if (defined $track->relation_list) {
			my @rels = @{$track->relation_list->relations};
			foreach my $rel (@rels) {
				my $reltype = $rel->type;
				$reltype =~ s/'/\\'/g;
				my $reltypeid;
				
				if (defined $rel->direction && $rel->direction eq 'backward') {
					$reltypeid = $sql->SelectSingleValue("
						SELECT id FROM musicbrainz.lt_artist_track 
						WHERE replace(shortlinkphrase, ' ', '')=LOWER('$reltype')");
				} else {
					$reltypeid = $sql->SelectSingleValue("
						SELECT id FROM musicbrainz.lt_artist_track
						WHERE replace(shortlinkphrase, ' ', '')=LOWER('$reltype')");
				}
				
				return $self->report_failure($edit->{'id'}, "Unknown link type: $reltype") unless defined $reltypeid && $reltypeid;
				
				my $rel_is_higher = $sql->SelectSingleValue("
					SELECT 1 FROM mbot.mb_link_type_descs 
					WHERE link_type='$reltypeid' AND desc_type = '$edit->{linktype}' LIMIT 1");
				my $rel_is_lower = $sql->SelectSingleValue("
					SELECT 1 FROM mbot.mb_link_type_descs 
					WHERE desc_type='$reltypeid' AND link_type = '$edit->{linktype}' LIMIT 1");
				
				my $relmsg;
				if ($reltypeid == $edit->{'linktype'}) {
					$relmsg = '.';
				} elsif ($rel_is_higher) {
					$relmsg = ', existing type is more general.';
				} elsif ($rel_is_lower) {
					$relmsg = ', existing type is more specific.'; 
				} else {
					next;
				}
				
				if ($rel->target eq $edit->{'link0gid'}) {
					return $self->report_failure($edit->{'id'}, 'Link exists with track' . $relmsg);
				}
				

				foreach my $equiv (@{$artist_equiv}) {
					if ($rel->target eq $equiv) {
						return $self->report_failure($edit->{'id'}, 'Link exists (equiv) with track' . $relmsg);
					}
				}
			}
		}
		
		return 1;
	} else {
		return $self->report_failure($edit->{'id'}, 'Validation not defined for source ' . $edit->{'source'});
	}
}

sub note_text {
	my ($self, $edit) = @_;
	my $sql = $self->sql;
	
	if ($edit->{'source'} eq 'discogs-trackrole') {
		# Be proud... I worked hard on this query. Maybe if I did not want to do everything so generic,
		# and save a bit more Discogs-specific info in the table, I would not have to link so many tables...
		my $d_track = $sql->SelectSingleRowHash(
			"SELECT d_t.track_id, d_t.title tracktitle, position, artist_name, txr.role_name, 
					txr.role_details, release.title reltitle, 
					COALESCE(artist_alias, artist_name) nametext
				FROM discogs.track d_t, discogs.dmap_track, discogs.discogs_release_url rel_url,
					discogs.tracks_extraartists_roles txr, discogs.dmap_artist,
					discogs.dmap_role, musicbrainz.lt_artist_track lt,	discogs.release
				WHERE dmap_track.d_track = d_t.track_id
					AND rel_url.discogs_id = d_t.discogs_id AND release.discogs_id = d_t.discogs_id
					AND txr.track_id = d_t.track_id AND txr.artist_name = dmap_artist.d_artist
					AND COALESCE(txr.artist_alias, '') = COALESCE(dmap_artist.d_alias, '')
					AND dmap_role.link_name = lt.name AND dmap_role.role_name = txr.role_name
					AND dmap_artist.mb_artist = '$edit->{link0gid}'
					AND dmap_track.mb_track = '$edit->{link1gid}'
					AND rel_url.url = '$edit->{sourceurl}' 
					AND lt.id = $edit->{linktype}"
			);


		my $otherartists = $sql->SelectListOfHashes(
			"SELECT txr.artist_name, artist.name, artist.resolution,
					COALESCE(txr.artist_alias, '') artist_alias,
					COALESCE(txr.artist_alias, txr.artist_name) nametext
				FROM discogs.tracks_extraartists_roles txr, discogs.dmap_artist,
					discogs.dmap_role, musicbrainz.artist, musicbrainz.lt_artist_track lt
				WHERE txr.artist_name = dmap_artist.d_artist 
					AND COALESCE(txr.artist_alias, '') = COALESCE(dmap_artist.d_alias, '')
					AND dmap_role.link_name = lt.name and dmap_role.role_name = txr.role_name
					AND artist.gid = dmap_artist.mb_artist
					AND txr.track_id = '$d_track->{track_id}'
					AND txr.artist_name <> " . $sql->Quote($d_track->{artist_name}) . "
					AND lt.id = $edit->{linktype}"
			);
			
		my $note = 
			"Discogs has:\n" .
			($d_track->{'position'} ? $d_track->{'position'} . '. ' : '') . $d_track->{tracktitle}
				. " - $d_track->{role_name}" . ($d_track->{'role_details'} ? " ($d_track->{role_details})" : '') 
				. ": $d_track->{nametext}\n";
			
		if (@{$otherartists}) {
			$note .= "\nCo-credited with:\n";
			foreach my $other (@{$otherartists}) {
				my $listed = $sql->SelectSingleRowHash(
					"SELECT artist.name, artist.resolution
						FROM musicbrainz.l_artist_track l, musicbrainz.track,
							mbot.mbmap_artist_equiv equiv, musicbrainz.artist,
							discogs.dmap_artist
						WHERE l.link1 = track.id AND l.link0 = artist.id
							AND artist.gid = equiv.equiv AND equiv.artist = dmap_artist.mb_artist
							AND track.gid = '$edit->{link1gid}'
							AND dmap_artist.d_artist = '$other->{artist_name}'
							AND COALESCE(dmap_artist.d_alias, '') = '$other->{artist_alias}'
							AND l.link_type = $edit->{linktype}
						LIMIT 1"
				);
				
				if ($listed) {
					$note .= "* $other->{nametext} - is listed, MB artist '$listed->{name}"
							. ($listed->{'resolution'} ? " ($listed->{resolution})" : '') . "'\n";
				} else {
					$note .= "* $other->{nametext} - new link, MB artist '$other->{name}"
							. ($other->{'resolution'} ? " ($other->{resolution})" : '') . "'\n";
				}
			}
		}
		$note .= "\n";
		
		my $mbrel = $sql->SelectSingleRowHash("SELECT gid, name FROM musicbrainz.album WHERE id=$edit->{release}");

		$note .= "References:\n"
			. "* MusicBrainz - $mbrel->{name}: http://musicbrainz.org/release/$mbrel->{gid}.html\n"
			. "* Discogs - $d_track->{reltitle}: $edit->{sourceurl}\n";

		return $note;
	} else {
		return $self->report_failure($edit->{'id'}, 'Do not know how to create note for source '. $edit->{'source'});
	}
}		
		
__PACKAGE__->meta->make_immutable;
no Moose;

1;
