package MusicBrainz::DataBot::Edit;

use Moose;
use WWW::Mechanize;
use Log::Dispatch;
use Log::Dispatch::File;
use Log::Dispatch::Screen;

use MusicBrainz::DataBot::Throttle;
use MusicBrainz::DataBot::BotConfig;

# Types
require MusicBrainz::DataBot::Edit::ArtistType;
require MusicBrainz::DataBot::Edit::Relationship;
require MusicBrainz::DataBot::Edit::RelationshipTrack;

has 'bot' => (is => 'rw', required => 1);
has 'sql' => (is => 'rw', required => 1);

### To be defined by children
sub edit_type
{
	die 'Not defined';
}

sub edit_query
{
	die 'Not defined';
}

sub autoedit
{
	return 0;
}

### Exposed to other classes

sub process_edits {
	my $self = shift;
	my $sql = $self->sql;
	
	my $editsref = $sql->SelectListOfHashes($self->edit_query);
	my @edits = @$editsref;
	my $numedits = scalar @edits;

	$self->debug("Loaded $numedits edits.");
	
	foreach my $edit (@edits) {
		eval {
			$self->process_edit($edit);
		};
		
		if ($@) {
			$self->edit_failure($edit->{id}, $@);
			$self->throttle('mberror');
		}
	}
	
	$self->debug('Finished edits.');
}

### For use by children

# Store edit result
sub edit_success
{
	my ($self, $edit) = @_;
	my $sql = $self->sql;
	
	$self->info("Edit $edit was successful!");
	$sql->AutoCommit;
	# $sql->update_row('mbot.' . $self->edit_type, {date_processed => 'NOW()', error => undef}, {id => $edit}) or $self->error("Error recording edit result");
	$sql->Do("UPDATE mbot." . $self->edit_type . " SET date_processed = NOW(), error = NULL WHERE id=$edit") or $self->error("Error recording edit result");
	
	return 1; # Exit without error
}

sub edit_failure
{
	my ($self, $edit, $message) = @_;
	my $sql = $self->sql;
	
	$self->error("Edit $edit failed: $message");
	$sql->AutoCommit;
	#$sql->update_row('mbot.' . $self->edit_type, {date_processed => 'NOW()', error => $message}, {id => $edit}) or $self->error("Error recording edit result");
	$message = $sql->Quote($message);
	$sql->Do("UPDATE mbot." . $self->edit_type . " SET date_processed = NOW(), error = $message WHERE id=$edit") or $self->error("Error recording edit result");
	
	return 0; # Exit with error
}

# Check login
sub check_login
{
	my ($self) = @_;
	my $bot = $self->bot;
	
	my $mb_user = &MusicBrainz::DataBot::BotConfig::MB_USER;
	my $mb_password = &MusicBrainz::DataBot::BotConfig::MB_PASSWORD;
	
	if ($self->has_form_id('LoginForm')) {
		$self->info('Logging in...');
		$self->throttle('mbsite');
		$bot->submit_form('form_id'=>'LoginForm', fields=>{'user'=>$mb_user, 'password'=>$mb_password});
		if ($self->has_form_id('LoginForm')) { $self->error('Login failed'); }
	}
}

sub has_form_id
{
	my ($self, $id) = @_;
	my $bot = $self->bot;
	my $oldquiet = $bot->quiet;
	$bot->quiet(1);
	my $res = $bot->form_id('LoginForm');
	$bot->quiet($oldquiet);
	return $res;
}


# Translate from gid to id on MusicBrainz server
sub find_artist_id 
{
	my ($self, $gid) = @_;
	return $self->_find_official_id('artist', $gid);
	
}

sub find_releasegroup_id 
{
	my ($self, $gid) = @_;
	return $self->_find_official_id('release-group', $gid);
	
}

sub find_release_id 
{
	my ($self, $gid) = @_;
	return $self->_find_official_id('release', $gid);
	
}

sub find_track_id 
{
	my ($self, $gid) = @_;
	return $self->_find_official_id('track', $gid);
	
}

sub _find_official_id
{
	my ($self, $type, $gid) = @_;
	my $bot = $self->bot;
	my $sql = $self->sql;
	
	my $localtype = $type;
	if ($localtype eq 'release') { $localtype = 'album'; }
	my $localid = $sql->SelectSingleValue("SELECT id from musicbrainz.$localtype WHERE gid='$gid'");
	if (defined $localid) {
		$self->debug("Found official $type id for $gid: $localid (local)");
		return $localid;
	}
	
	my $id = $sql->SelectSingleValue("SELECT official_id from mbot.mbmap_official_id WHERE gid='$gid' AND type='$type'");
	if (defined $id) {
		$self->debug("Found official $type id for $gid: $id (cached)");
		return $id;
	}
	
	$self->throttle('mbsite');
	$bot->get(sprintf('http://musicbrainz.org/%s/%s.html', $type, $gid));
	my $link = $bot->find_link( url_regex => qr/${type}\/.*id=[0-9]+$/ );
	
	return unless defined $link;
	
	$link->url =~ /id=([0-9]+)$/;
	
	return unless defined $1;
	$id = int($1);
	$self->debug("Found official $type id for $gid: $id");
	
	$sql->AutoCommit;
	$sql->InsertRow('mbot.mbmap_official_id', {gid => $gid, type => $type, official_id => $id});
	
	return $id;
}

# Discogs URL
sub find_discogs_url
{
	my ($self, $id, $type) = @_;
	my $sql = $self->sql;
	
	return $sql->selectSingleValue(
		"SELECT u.url
		   FROM musicbrainz.l_${type}_url lu, musicbrainz.url u, musicbrainz.link l, musicbrainz.link_type lt
		  WHERE lu.link = l.id and l.link_type = lt.id AND lu.entity1 = u.id AND lt.name = 'discogs' AND
		   lu.entity0 = $id");
}

sub find_all_discogs_urls
{
	my ($self, $id, $type) = @_;
	my $sql = $self->sql;
	
	return $sql->selectSingleColumnArray(
		"SELECT u.url
		   FROM musicbrainz.l_${type}_url lu, musicbrainz.url u, musicbrainz.link l, musicbrainz.link_type lt
		  WHERE lu.link = l.id and l.link_type = lt.id AND lu.entity1 = u.id AND lt.name = 'discogs' AND
		   lu.entity0 = $id");
}

# Logging
sub debug { my ($self, $message) = @_; MusicBrainz::DataBot::EditQueue->debug($message); }
sub info  { my ($self, $message) = @_; MusicBrainz::DataBot::EditQueue->info($message); }
sub error { my ($self, $message) = @_; MusicBrainz::DataBot::EditQueue->error($message); }

# Throttle
sub throttle { my ($self, $area) = @_; MusicBrainz::DataBot::Throttle->throttle($area); }
1;
