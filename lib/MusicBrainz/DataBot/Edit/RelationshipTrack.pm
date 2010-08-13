package MusicBrainz::DataBot::Edit::RelationshipTrack;

use Moose;
use WebService::MusicBrainz::Artist;
use WebService::MusicBrainz::Track;

use List::Uniq 'uniq';
use Clone qw(clone);

extends 'MusicBrainz::DataBot::Edit::BaseEditTask';

has '+type' => (default => 'edits_relationship_track');

sub prepare_tasks {
	my ($self, @edits) = @_;
	
	my @keys = qw(link0gid link1gid linktype);
	my @aggr = qw(id sourceurl attrgid);
	my %newedits;
	
	foreach my $edit (@edits) {
		my $key = join(':', @{$edit}{@keys});
		
		if (exists $newedits{$key}) {
			my $newedit = $newedits{$key};
			
			map { push @{$newedit->{$_}}, $edit->{$_} } @aggr;
		} else {
			map { $edit->{$_} = [$edit->{$_}] } @aggr;
			
			$newedits{$key} = $edit;
		}
	}
	
	@edits = values %newedits;
	
	foreach my $edit (@edits) {
		map { $edit->{$_} = uniq {'flatten' => 1}, $edit->{$_} } @aggr;
	}
	
	return sort { $a->{'tracknr'} <=> $b->{'tracknr'} } @edits;
}

sub run_task {
	my ($self, $edit) = @_;
	my $bot = $self->bot;
	my $sql = $self->sql;
	
	$self->debug('Processing edit ' . join('+', @{$edit->{'id'}}));
	
	my $note = $self->note_text($edit);
	return unless $note;
	
	$self->debug("Note:\n" . $note);
	
	return unless $self->validate($edit);
	
	my $link0id = $self->_find_official_id($edit->{'link0type'}, $edit->{'link0gid'});
	my $link1id = $self->_find_official_id($edit->{'link1type'}, $edit->{'link1gid'});
	
	return $self->report_failure($edit->{'id'}, 'Could not find official link0 ID') unless defined $link0id;
	return $self->report_failure($edit->{'id'}, 'Could not find official link1 ID') unless defined $link1id;
	
	$self->throttle('mbsite');
	$bot->get("http://musicbrainz.org/edit/relationship/add.html?link0=$edit->{link0type}=$link0id&link1=$edit->{link1type}=$link1id");
	$self->check_login;
	
	my $edit_form = $bot->form_with_fields(qw/linktypeid link0 link1/);
	if (!defined $edit_form) {
		return $self->report_failure($edit->{'id'}, 'Could not find edit form');
	}
	
	$edit_form->accept_charset('iso-8859-1');
	
	my $typeinput = $edit_form->find_input('linktypeid');
	my $foundtype = 0;

	foreach my $type ($typeinput->possible_values) {
		if ($type =~ /^$edit->{linktype}\|/) {
			$typeinput->value($type);
			$foundtype = 1;
			last;
		}	
	}
	
	return $self->report_failure($edit->{'id'}, 'Could not find relation type') unless $foundtype;
	
	foreach my $attrgid (@{$edit->{'attrgid'}}) {
		my $attr = $sql->SelectSingleRowHash(
			$self->select_from(
				['valueid', 'valuename', 'attrid', 'attrname'],
				'mbot.attrinfo',
				{'valuegid' => $attrgid},
				'LIMIT 1'));
				
		unless (defined $attr) {
			return $self->report_failure($edit->{'id'}, "Could not find info for attribute $attrgid");
		}
				
		my $field = $edit_form->find_input("attr_$attr->{attrname}_0");
		
		unless (defined $field) {
			return $self->report_failure($edit->{'id'}, "Could not find $attr->{attrname} field");
		}
		
		if ($field->type eq 'checkbox') {
			$field->check;
			$self->debug("Set $attr->{attrname} attribute");
		} elsif ($field->type eq 'option') {
			my $fieldindex = 0;
			while ($field->value) {
				my $fieldname = "attr_$attr->{attrname}_" . ++$fieldindex;
				my $nextfield = $edit_form->find_input($fieldname);
				
				unless (defined $nextfield) {
					$nextfield = clone $field;
					$nextfield->{'name'} = $fieldname;
					$edit_form->push_input('option', $nextfield);
				}
				
				$field = $nextfield;
			}
			
			$field->value($attr->{'valueid'});
			$self->debug("Set $attr->{attrname} attribute to $attr->{valuename}");
		} else {
			return $self->report_failure($edit->{'id'}, "Unknown field type for attribute $attr->{attrname}");
		}
	}
	
	$self->info('Edit ' . join('+', @{$edit->{'id'}}) . ": Adding relationship $edit->{link0gid}\->$edit->{linkname}\->$edit->{link1gid}");
	
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
				
				my $reltypegid = $sql->SelectSingleValue(
							$self->select_from(
								['gid'],
								'mbot.ltinfo_artist_track',
								{'shortlinkphrase' => lc($reltype)}));
				
				return $self->report_failure($edit->{'id'}, "Unknown link type: $reltype") unless defined $reltypegid && $reltypegid;
				
				my $rel_is_higher = $sql->SelectSingleValue(
					$self->select_from(
						['1'],
						'mbot.mb_link_type_descs',
						{'link_type' => $reltypegid,
						 'desc_type' => $edit->{'linkgid'},
						 'link0type' => $edit->{'link0type'},
						 'link1type' => $edit->{'link1type'}},
						'LIMIT 1'));
				my $rel_is_lower = $sql->SelectSingleValue(
					$self->select_from(
						['1'],
						'mbot.mb_link_type_descs',
						{'link_type' => $edit->{'linkgid'},
						 'desc_type' => $reltypegid,
						 'link0type' => $edit->{'link0type'},
						 'link1type' => $edit->{'link1type'}},
						'LIMIT 1'));
				
				my $relmsg;
				if ($reltypegid eq $edit->{'linkgid'}) {
					$relmsg = '.';
				} elsif ($rel_is_higher || $rel_is_lower) {
					my $link_is_planned = $sql->SelectSingleValue(
						$self->select_from(
							['1',],
							'discogs.both_links_listed',
							{'artist'    => $rel->target,
							 'track'     => $edit->{'link1gid'},
							 'linktype1' => $edit->{'linkgid'},
							 'linktype2' => $reltypegid},
							'LIMIT 1'));
					
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
								'discogs.both_links_listed',
								{'artist'    => $rel->target,
								 'track'     => $edit->{'link1gid'},
								 'linktype1' => $edit->{'linkgid'},
								 'linktype2' => $reltypegid},
								'LIMIT 1'));
						
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
		my $note = "Discogs has:\n";
		my $d_track;
		my $discogsrefs;
		
		foreach my $sourceurl (@{$edit->{'sourceurl'}}) {
			$d_track = $sql->SelectSingleRowHash(
				$self->select_from(
					['track_id', 'tracktitle', 'position', 'artist_name', 'role_name',
					 'role_details', 'reltitle', 'nametext', 'discogs_id', 'mb_original'],
					'discogs.track_info',
					{'mb_artist' => $edit->{'link0gid'},
					 'mb_track'  => $edit->{'link1gid'},
					 'url'       => $sourceurl,
					 'link_type' => $edit->{'linktype'}},
					'LIMIT 1'));
					 
			return $self->report_failure($edit->{'id'}, 'Could not retrieve track info for edit note') unless defined $d_track;
		
			my $num_otherartists = $sql->SelectSingleValue(
				$self->select_from(
					['COUNT(DISTINCT artist_name)'],
					'discogs.discogs_credits_for_track',
					{'track_id'        => $d_track->{'track_id'},
					 'artist_name <> ' => $d_track->{'artist_name'},
					 'link_type'       => $edit->{'linktype'}}));
			
			my $roletext = "$d_track->{role_name}" . ($d_track->{'role_details'} ? " ($d_track->{role_details})" : '');
			my $tracktext = ($d_track->{'position'} ? $d_track->{'position'} . '. ' : '') . $d_track->{'tracktitle'};
		
			$note .= "$tracktext - $roletext: $d_track->{nametext}"
				. ($num_otherartists ? " (+ $num_otherartists other" . ($num_otherartists > 1 ? 's' : '') . ')' : '')
				. "\n\n";
			
			$discogsrefs .= "* Discogs - $d_track->{reltitle}: $sourceurl\n";
		}
			
		if (defined $d_track->{'mb_original'}) {
			my $collaborators = $sql->SelectSingleColumnArray(
				$self->select_from(
					['name'],
					'discogs.collab_members',
					{'mb_artist' => $d_track->{'mb_original'}}));
					
			my $collab_name = $sql->SelectSingleValue(
				$self->select_from(
					['name'],
					'musicbrainz.artist',
					{'gid' => $d_track->{'mb_original'}}));
			
			$note .= "Artist is a collaboration; creating links to collaborators instead.\n";
			$note .= "* Collaboration: $collab_name - http://musicbrainz.org/artist/$d_track->{mb_original}.html\n";
			$note .= "* Collaborators: " . join(', ', @{$collaborators}) . "\n\n";
		}
		
		my $mbrel = $sql->SelectSingleRowHash("SELECT gid, name FROM musicbrainz.album WHERE id=$edit->{release}");

		$note .= "References:\n"
			. "* MusicBrainz - $mbrel->{name}: http://musicbrainz.org/release/$mbrel->{gid}.html\n"
			. $discogsrefs;

		return $note;
	} else {
		return $self->report_failure($edit->{'id'}, 'Do not know how to create note for source '. $edit->{'source'});
	}
}
		
__PACKAGE__->meta->make_immutable;
no Moose;

1;
