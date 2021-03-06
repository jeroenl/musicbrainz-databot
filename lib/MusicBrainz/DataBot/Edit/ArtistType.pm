package MusicBrainz::DataBot::Edit::ArtistType;

use Moose;

extends 'MusicBrainz::DataBot::Edit::BaseEditTask';

has '+autoedit' => (default => 1);
has '+type' => (default => 'edits_artist_typechange');

sub run_task {
	my ($self, $edit) = @_;
	my $bot = $self->bot;
	$self->debug("Processing edit $edit->{id}");
	
	my $artistid = $self->find_artist_id($edit->{'gid'});
	
	if ($self->is_artist_being_edited($artistid)) {
		return $self->report_failure($edit->{'id'}, 'Artist has open edits, waiting for things to calm down');
	}
	
	$self->throttle('mbsite');
	$bot->get('http://musicbrainz.org/edit/artist/edit.html?artistid=' . $artistid);
	$self->check_login;
	
	my $edit_form = $bot->form_with_fields(qw/type sortname/);
	if (!defined $edit_form) {
		return $self->report_failure($edit->{'id'}, 'Could not find edit form');
	}
	if ($edit_form->value('type')) {
		return $self->report_failure($edit->{'id'}, 'Type already set');
	}
	if (defined $edit_form->find_input('confirm')) {
		if ($edit_form->value('resolution')) {
			$bot->field('confirm', 1);
		} else {
			return $self->report_failure($edit->{'id'}, 'Edit requires confirmation');
		}
	}
	
	$self->info("Edit $edit->{id}: Changing type of $edit->{gid} to $edit->{newtype}");
	$self->throttle('mbedit');
	$bot->set_fields( 'type' => $edit->{'newtype'} ); #, 'notetext' => 'Setting artist type, based on relationships.' );
	$bot->click_button( 'input' => $bot->current_form()->find_input( '#btnYes', 'submit' ) );
	
	if ($bot->title =~ /^Edit Artist/) {
		return $self->report_failure($edit->{'id'}, 'Edit was rejected');
	}
	
	return $self->report_success($edit->{'id'});
}

sub is_artist_being_edited {
	my ($self, $artist) = @_;
	
	my $editcount = $self->_editcount_on_url('http://musicbrainz.org/mod/search/results.html?mod_status=1&automod=&mod_type=33&mod_type=40&mod_type=35&ar_type=artist-artist&moderator_type=0&moderator_id=11780&voter_type=0&voter_id=11780&artist_type=3&orderby=desc&minid=&maxid=&isreset=0&artist_id=' . $artist);
	
	return ($editcount > 0);
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;
