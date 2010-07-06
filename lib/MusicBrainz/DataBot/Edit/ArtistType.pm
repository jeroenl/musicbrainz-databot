package MusicBrainz::DataBot::Edit::ArtistType;

use Moose;

extends 'MusicBrainz::DataBot::Edit::BaseEditTask';

has '+autoedit' => (default => 1);
has '+type' => (default => 'edits_artist_typechange');
has '+query' => 
	(default => sub { 
	  	my $self = shift;
	  	return 'SELECT e.id, e.newtype, e.artistgid gid
			  FROM ' . $self->schema . '.' . $self->type . ' e
			  WHERE date_processed IS NULL
			  ORDER BY e.id ASC
			  LIMIT 50'; });

sub run_task {
	my ($self, $edit) = @_;
	my $bot = $self->bot;
	$self->debug("Processing edit $edit->{id}");
	
	my $artistid = $self->find_artist_id($edit->{'gid'});
	
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

1;
