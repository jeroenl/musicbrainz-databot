package MusicBrainz::DataBot::Edit::Relationship;

use Moose;
use WebService::MusicBrainz::Artist;
use WebService::MusicBrainz::Track;

extends 'MusicBrainz::DataBot::Edit::BaseEditTask';

has '+autoedit' => (default => 1);
has '+type' => (default => 'edits_relationship');
has '+query' => 
	(default => sub { 
	  	my $self = shift;
	  	return 'SELECT e.id, e.link0, e.link0type, e.link1, e.link1type, e.linktype, l.linkphrase, l.name linkname, e.source
			  FROM ' . $self->schema . '.' . $self->type . ' e, musicbrainz.link_type l
			  WHERE e.linktype = l.id
			    AND date_processed IS NULL
			  ORDER BY e.id ASC
			  LIMIT 50'; });

sub run_task {
	my ($self, $edit) = @_;
	my $bot = $self->bot;
	my $sql = $self->sql;
	$self->debug("Processing edit $edit->{id}");
	
	$edit->{'gid0type'} = $edit->{'link0type'};
	$edit->{'gid1type'} = $edit->{'link1type'};
	
	if ($edit->{'gid0type'} eq 'track') { $edit->{'gid0type'} = 'recording'; }
	if ($edit->{'gid1type'} eq 'track') { $edit->{'gid1type'} = 'recording'; }
	
	$edit->{'gid0'} = $sql->select_single_value("SELECT gid FROM $edit->{gid0type} WHERE id=$edit->{link0}");
	$edit->{'gid1'} = $sql->select_single_value("SELECT gid FROM $edit->{gid1type} WHERE id=$edit->{link1}");
	
	return unless $self->validate($edit);
	
	my $link0id = $self->_find_official_id($edit->{'link0type'}, $edit->{'gid0'});
	my $link1id = $self->_find_official_id($edit->{'link1type'}, $edit->{'gid1'});
	
	$self->throttle('mbsite');
	$bot->get("http://musicbrainz.org/edit/relationship/add.html?link0=$edit->{link0type}=$link0id&link1=$edit->{link1type}=$link1id&returnto=1");
	$self->check_login;
	
	my $edit_form = $bot->form_with_fields(qw/linktypeid link0 link1/);
	if (!defined $edit_form) {
		return $self->report_failure($edit->{'id'}, 'Could not find edit form');
	}
	
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
	
	my $note = $self->note_text($edit);
	return unless $note;
	$bot->set_fields( 'notetext' => $note );
	
	$self->info("Edit $edit->{id}: Adding relationship $edit->{gid0}\->$edit->{linkname}\->$edit->{gid1}");
	$self->debug('Note = ' . $note);
	$self->throttle('mbedit');
	
	#$bot->click_button( 'input' => $bot->current_form()->find_input( '#btnYes', 'submit' ) );
	
	if ($bot->title =~ /^Create Relationship/) {
		return $self->report_failure($edit->{'id'}, 'Edit was rejected');
	}
	
	return $self->report_success($edit->{'id'});
}

sub validate {
	my ($self, $edit) = @_;
	my $sql = $self->sql;
	
	if ($edit->{'source'} eq 'discogs-memberlist') {
		my $ws = WebService::MusicBrainz::Artist->new;
		$self->throttle('mbapi');
		my $artist = $ws->search({ MBID => $edit->{'gid1'}, INC => "$edit->{link0type}-rels" });
		$self->report_failure($edit->{'id'}, 'Could not find artist on MusicBrainz WS') unless defined $artist;
		$artist = $artist->artist;
		
		$edit->{'ws1'} = $artist;
		
		return $self->report_failure($edit->{'id'}, 'Artist is possibly a collaboration') if ($artist->name =~ / (\&|vs\.) /);
		return $self->report_failure($edit->{'id'}, 'Group is listed as a person') if (defined $artist->type && $artist->type eq 'Person');
		return $self->report_failure($edit->{'id'}, 'Some relation already exists between these entities') if $self->relation_exists($edit);
		
		if (defined $artist->relation_list  && $edit->{'source'} eq 'discogs-memberlist') {
			my @rels = @{$artist->relation_list->relations};
			foreach my $rel (@rels) {
				if ($rel->type eq 'Collaboration' && defined $rel->direction && $rel->direction eq 'backward' ) {
					return $self->report_failure($edit->{'id'}, 'Group already has collaborators listed');
				}
			}
		}
		
		return 1;
	} else {
		return $self->report_failure($edit->{'id'}, 'Validation not defined for source ' . $edit->{'source'});
	}
}

sub relation_exists {
	my ($self, $edit) = @_;
	my $sql = $self->sql;
	
	if ($edit->{'link1type'} eq 'artist') {
		my $artist;
		if (defined $edit->{'ws1'}) {
			$artist = $edit->{'ws1'};
		} else {
			$self->debug('Retrieving WS again!');
			my $ws = WebService::MusicBrainz::Artist->new;
			$self->throttle('mbapi');
			my $artist = $ws->search({ MBID => $edit->{'gid1'}, INC => "$edit->{link1type}-rels" });
			$self->report_failure($edit->{'id'}, 'Could not find artist on MusicBrainz WS') unless defined $artist;
			$artist = $artist->artist;
		}
		
		return 0 unless defined $artist->relation_list;
		
		my $artist_equiv = $sql->select_single_column_array("SELECT equiv FROM mbot.mbmap_artist_equiv WHERE artist='$edit->{gid0}'");
		my $artist_equiv_rev = $sql->select_single_column_array("SELECT artist FROM mbot.mbmap_artist_equiv WHERE equiv='$edit->{gid0}'");
		
		my @rels = @{$artist->relation_list->relations};
		foreach my $rel (@rels) {
			if ($rel->target eq $edit->{'gid0'}) {
				return 1;
			}
			
			foreach my $equiv (@{$artist_equiv}) {
				if ($rel->target eq $equiv) {
					$self->debug('Found relation through equivalence.');
					return 1;
				}
			}
			
			foreach my $equiv (@{$artist_equiv_rev}) {
				if ($rel->target eq $equiv) {
					$self->debug('Found relation through reverse equivalence.');
					return 1;
				}
			}
		}
		
		return 0;
	} else {
		return $self->report_failure($edit->{'id'}, 'Relation exists check not defined for this type');
	}
}

sub note_text {
	my ($self, $edit) = @_;
	my $sql = $self->sql;
	
	if ($edit->{'source'} eq 'discogs-memberlist') {
		my $url = $self->find_discogs_url($edit->{'link1'}, $edit->{'link1type'});
		return $self->report_failure($edit->{'id'}, 'Could not find Discogs URL for source note') unless $url;
		
		return 'Source: ' . $url;
	} elsif ($edit->{'source'} eq 'discogs-trackrole') {
		my $releases = $sql->select_single_column_array("SELECT m.release FROM musicbrainz.track t, musicbrainz.medium m WHERE recording=$edit->{link1} and t.tracklist = m.tracklist");
		return $self->report_failure($edit->{'id'}, 'Could not find release for source note') unless defined $releases;
		
		foreach my $release (@{$releases}) {
			my $url = $self->find_discogs_url($release, 'release');
			return 'Source: ' . $url if defined $url;
		}
		
		return $self->report_failure($edit->{'id'}, 'Could not find Discogs URL for source note');
	}
	
	return $self->report_failure($edit->{'id'}, 'Do not know how to create note for source '. $edit->{'source'});
}		
		

1;
