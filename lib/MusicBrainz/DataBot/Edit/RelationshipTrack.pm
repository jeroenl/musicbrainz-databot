package MusicBrainz::DataBot::Edit::RelationshipTrack;

use Moose;
use WebService::MusicBrainz::Artist;
use WebService::MusicBrainz::Track;

extends 'MusicBrainz::DataBot::Edit::BaseEditTask';

has '+type' => (default => 'edits_relationship_track');

sub run_task {
	my ($self, $edit) = @_;
	my $bot = $self->bot;
	my $sql = $self->sql;
	
	$self->debug("Processing edit $edit->{id}");
	
	my $note = $self->note_text($edit);
	return unless $note;
	
	$self->debug("Note:\n" . $note);
	
	return unless $self->validate($edit);
	
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
			$self->select_from(
				['role_details'],
				'discogs.track_info',
				{'mb_artist' => $edit->{'link0gid'},
				 'mb_track'  => $edit->{'link1gid'},
				 'url'       => $edit->{'sourceurl'},
				 'link_type' => $edit->{'linktype'}},
				'LIMIT 1'));
			
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
				
				my $reltypeid = $sql->SelectSingleValue(
							$self->select_from(
								['id'],
								'mbot.ltinfo_artist_track',
								{'shortlinkphrase' => lc($reltype)}));
				
				return $self->report_failure($edit->{'id'}, "Unknown link type: $reltype") unless defined $reltypeid && $reltypeid;
				
				my $rel_is_higher = $sql->SelectSingleValue(
					$self->select_from(
						['1'],
						'mbot.mb_link_type_descs',
						{'link_type' => $reltypeid,
						 'desc_type' => $edit->{'linktype'},
						 'link0type' => $edit->{'link0type'},
						 'link1type' => $edit->{'link1type'}},
						'LIMIT 1'));
				my $rel_is_lower = $sql->SelectSingleValue(
					$self->select_from(
						['1'],
						'mbot.mb_link_type_descs',
						{'link_type' => $edit->{'linktype'},
						 'desc_type' => $reltypeid,
						 'link0type' => $edit->{'link0type'},
						 'link1type' => $edit->{'link1type'}},
						'LIMIT 1'));
				
				my $relmsg;
				if ($reltypeid == $edit->{'linktype'}) {
					$relmsg = '.';
				} elsif ($rel_is_higher || $rel_is_lower) {
					my $link_is_planned = $sql->SelectSingleValue(
						$self->select_from(
							['1',],
							'discogs.edits_artist_track',
							{'artist'   => $rel->target,
							 'track'    => $edit->{'link1gid'},
							 'linktype' => $reltypeid}));
							 
					next if $link_is_planned;
					
					$relmsg = ', existing type is more ' . ($rel_is_higher ? 'general.' : 'specific.');
				} else {
					next;
				}
				
				if ($rel->target eq $edit->{'link0gid'}) {
					return $self->report_failure($edit->{'id'}, 'Link exists with track' . $relmsg);
				}
				

				foreach my $equiv (@{$artist_equiv}) {
					if ($rel->target eq $equiv) {
						my $link_is_planned = $sql->SelectSingleValue(
							$self->select_from(
								['1',],
								'discogs.edits_artist_track',
								{'artist'   => $rel->target,
								 'track'    => $edit->{'link1gid'},
								 'linktype' => $reltypeid}));
								 
						next if $link_is_planned;
						
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
		my $d_track = $sql->SelectSingleRowHash(
			$self->select_from(
				['track_id', 'tracktitle', 'position', 'artist_name', 'role_name',
				 'role_details', 'reltitle', 'nametext', 'discogs_id'],
				'discogs.track_info',
				{'mb_artist' => $edit->{'link0gid'},
				 'mb_track'  => $edit->{'link1gid'},
				 'url'       => $edit->{'sourceurl'},
				 'link_type' => $edit->{'linktype'}},
				'LIMIT 1'));
				 
		return $self->report_failure($edit->{'id'}, 'Could not retrieve track info for edit note') unless defined $d_track;
		
		my $is_albumedit = $sql->SelectSingleValue(
			$self->select_from(
				['1'],
				'discogs.releases_extraartists_roles',
				{'discogs_id'   => $d_track->{'discogs_id'},
				 'artist_name'  => $d_track->{'artist_name'},
				 'role_name'    => $d_track->{'role_name'},
				 'role_details' => $d_track->{'role_details'}},
				'LIMIT 1'));

		my $otherartists = $sql->SelectListOfHashes(
			$self->select_from(
				['artist_name', 'name', 'resolution', 'artist_alias', 'nametext'],
				'discogs.discogs_credits_for_track',
				{'track_id'        => $d_track->{'track_id'},
				 'artist_name <> ' => $d_track->{'artist_name'},
				 'link_type'       => $edit->{'linktype'}}));
			
		my $roletext = "$d_track->{role_name}" . ($d_track->{'role_details'} ? " ($d_track->{role_details})" : '');
		my $tracktext = ($d_track->{'position'} ? $d_track->{'position'} . '. ' : '') . $d_track->{'tracktitle'};
		
		my $note = "Discogs has:\n" .
				($is_albumedit ? "''Album''" : $tracktext)
				. " - $roletext" 
				. ": $d_track->{nametext}\n";
			
		if (@{$otherartists}) {
			$note .= "\nCo-credited with:\n";
			foreach my $other (@{$otherartists}) {
				my $listed = $sql->SelectSingleRowHash(
					$self->select_from(
						['name', 'resolution'],
						'discogs.mb_track_credits_for_discogs_artist',
						{'track_gid' => $edit->{'link1gid'},
						 'link_type' => $edit->{'linktype'},
						 'd_artist'  => $other->{'artist_name'},
						 'd_alias'   => $other->{'artist_alias'}},
						'LIMIT 1'));
				
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
			. "* Discogs - $d_track->{reltitle}: $edit->{sourceurl}\n"
			. ($is_albumedit ? "* This track matched to: $tracktext" : '') . "\n";

		return $note;
	} else {
		return $self->report_failure($edit->{'id'}, 'Do not know how to create note for source '. $edit->{'source'});
	}
}
		
__PACKAGE__->meta->make_immutable;
no Moose;

1;
