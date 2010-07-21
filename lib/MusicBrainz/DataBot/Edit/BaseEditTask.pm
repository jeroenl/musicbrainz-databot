package MusicBrainz::DataBot::Edit::BaseEditTask;

use Moose;

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
		if ($self->openeditcount > 500) {
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
	my $config = $self->config;
	
	my $mb_user = $config->get_config('mb_user');
	my $mb_password = $config->get_config('mb_password');
	
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
sub find_artist_id { my ($self, $gid) = @_; return $self->_find_official_id('artist', $gid); }
sub find_releasegroup_id { my ($self, $gid) = @_; return $self->_find_official_id('release-group', $gid); }
sub find_release_id { my ($self, $gid) = @_; return $self->_find_official_id('release', $gid); }
sub find_track_id { my ($self, $gid) = @_; return $self->_find_official_id('track', $gid); }

sub _find_official_id
{
	my ($self, $type, $gid) = @_;
	my $bot = $self->bot;
	my $sql = $self->sql;
	
	my $localtype = $type;
	if ($localtype eq 'release') { $localtype = 'album'; }
	my $localid = $sql->SelectSingleValue("SELECT id from musicbrainz.$localtype WHERE gid='$gid'");

	if (defined $localid) {
		$self->debug(ucfirst($type) . ": $gid ($localid)");
		return $localid;
	} else {
		$self->error("No $type with GID $gid found");
	}
	
	return 0;
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
	my $config = $self->config;
	
	my $botuserid = $config->get_config('mb_botuserid');
	my $approverid = $config->get_config('mb_approverid');
	
	my $openedits = $self->_editcount_on_url('http://musicbrainz.org/mod/search/results.html?mod_status=1&automod=&moderator_type=3&voter_type=1&voter_id=' . $approverid . '&vote_cast=-2&vote_cast=0&artist_type=0&orderby=desc&minid=&maxid=&isreset=0&moderator_id=' . $botuserid);
	$self->info("Bot user has $openedits unreviewed edits.");
	
	return $openedits;
}

sub _editcount_on_url {
	my ($self, $url) = @_;
	my $bot = $self->bot;
	
	$self->throttle('mbsite');
	eval { 
		$bot->get($url);
	} or do {
		$self->error("Could not retrieve edit count: $@");
		return 1000000;
	};
	
	$self->check_login;
	my $content = $bot->content;
	
	if ($content =~ /No edits found matching the current selection/g) {
		return 0;
	}
	
	unless ($content =~ /Found ([0-9]+) edits?\s+matching the current selection/g) {
		$self->error("Could not find edit count on page.");
		return 1000000; # Returning high open count, to block edits until this is fixed.
	}
	
	return $1;
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;
