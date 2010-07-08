package MusicBrainz::DataBot::Edit::BaseEditTask;

use Moose;

use MusicBrainz::DataBot::BotConfig;

extends 'MusicBrainz::DataBot::BaseTask';

has '+schema' => (default => 'mbot');
has 'autoedit' => (is => 'ro', default => 0);

# Types
require MusicBrainz::DataBot::Edit::ArtistType;
require MusicBrainz::DataBot::Edit::Relationship;
require MusicBrainz::DataBot::Edit::RelationshipTrack;

sub ready
{
	my $self = shift;
	
	unless ($self->autoedit) {
		if ($self->openeditcount > 200) {
			return 0;
		}
	}
	
	return 1;
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
	
	return 1;
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
	
	$link->url =~ /id=([0-9]+)$/
		or return;
	
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
	
	return $sql->selectSingleColumnArray( <<"END_OF_QUERY" );
SELECT u.url
  FROM musicbrainz.l_${type}_url lu, musicbrainz.url u, musicbrainz.link l, musicbrainz.link_type lt
 WHERE lu.link = l.id and l.link_type = lt.id AND lu.entity1 = u.id AND lt.name = 'discogs' AND lu.entity0 = $id
 
END_OF_QUERY
}

sub find_all_discogs_urls
{
	my ($self, $id, $type) = @_;
	my $sql = $self->sql;
	
	return $sql->selectSingleColumnArray( <<"END_OF_QUERY" );
SELECT u.url
  FROM musicbrainz.l_${type}_url lu, musicbrainz.url u, musicbrainz.link l, musicbrainz.link_type lt
 WHERE lu.link = l.id and l.link_type = lt.id AND lu.entity1 = u.id AND lt.name = 'discogs' AND lu.entity0 = $id
 
END_OF_QUERY
}

#################################################################################

# Retrieve unreviewed edit count (= open without yes/abstain vote from approver)
sub openeditcount {
	my $self = shift;
	
	my $botuserid = &MusicBrainz::DataBot::BotConfig::MB_BOTUSERID;
	my $approverid = &MusicBrainz::DataBot::BotConfig::MB_APPROVERID;
	
	my $openedits = $self->_openeditcount_for_user($botuserid, $approverid);
	$self->info("Bot user has $openedits unreviewed edits.");
	
	return $openedits;
}

sub _openeditcount_for_user {
	my ($self, $userid, $approverid) = @_;
	my $bot = $self->bot;
	
	$self->throttle('mbsite');
	eval { 
		$bot->get('http://musicbrainz.org/mod/search/results.html?mod_status=1&automod=&moderator_type=3&voter_type=1&voter_id=' . $approverid . '&vote_cast=-2&vote_cast=0&artist_type=0&orderby=desc&minid=&maxid=&isreset=0&moderator_id=' . $userid);
	} or do { return 1000000; };
	
	$self->check_login;
	my $content = $bot->content;
	
	if ($content =~ /No edits found matching the current selection/g) {
		return 0;
	}
	
	unless ($content =~ /Found ([0-9]+) edits?\s+matching the current selection/g) {
		$self->error("Could not find open edit count for user $userid.");
		return 1000000; # Returning high open count, to block edits until this is fixed.
	}
	
	return $1;
}

1;
