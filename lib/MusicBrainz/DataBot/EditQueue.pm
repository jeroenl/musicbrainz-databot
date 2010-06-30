package MusicBrainz::DataBot::EditQueue;

use Moose;
use MooseX::ClassAttribute;

use WWW::Mechanize;
use Log::Dispatch;
use Log::Dispatch::File;
use Log::Dispatch::Screen;

use MusicBrainz;
use Sql;

use MusicBrainz::DataBot::Edit;
use MusicBrainz::DataBot::Throttle;
use MusicBrainz::DataBot::BotConfig;

class_has 'log' => (is => 'ro', default => 
	sub 
	{
		my $log = Log::Dispatch->new;
		#$log->add ( Log::Dispatch::File->new( name => 'infolog', min_level => 'info', filename => 'edit.log' ) );
		$log->add ( Log::Dispatch::Screen->new ( name => 'debugscreen', min_level => 'debug' ) );
		return $log;
	} );

has 'bot' => (is => 'ro', default => sub { my $m = WWW::Mechanize->new; $m->agent_alias('Windows IE 6'); return $m; } );
has 'mbc' => (is => 'ro', default => sub { my $mb = new MusicBrainz; $mb->Login(); return $mb; } );
has 'sql' => (is => 'ro', builder => '_build_sql');
has 'editrunners' => (is => 'ro', isa => 'HashRef', builder => '_build_editrunners');

### Queue processing

sub process_edits {
	my $self = MusicBrainz::DataBot::EditQueue->new;
	
	while (1) {
		$self->_process_edits_run;
	}
}

sub _process_edits_run {
	my $self = shift;
	
	my $sql = $self->sql;
	my %runners = %{$self->editrunners};
	my $openeditcount;
		
	my $edittypes = $sql->SelectSingleColumnArray('SELECT edit_type from mbot.edits WHERE date_processed IS NULL GROUP BY edit_type ORDER BY COUNT(1) DESC');

	unless (defined $edittypes) {
		$self->info('No pending edits...');
		return;
	}

	foreach my $edittype (@{$edittypes}) {
		if (!defined $runners{$edittype}) {
			$self->error("Edit runner '$edittype' does not exist... skipping.");
			next;
		}
		
		my $runner = $runners{$edittype};
		unless ($runner->autoedit) {
			unless (defined $openeditcount) {
				$openeditcount = $self->openeditcount;
			}
			
			if ($openeditcount > 200) {
				$self->error("Too many open edits for edit runner '$edittype'... skipping.");
				next;
			}
		}
		
		$self->info("Running '$edittype' edits...");
		return $runner->process_edits;
	}
	
	$self->info('No eligible edits...');
	$self->throttle('editquery');
}

### Utilities

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
	};
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

# for var 'sql'
sub _build_sql
{
	my $self = shift;
	my $sql = new Sql($self->mbc->{DBH});
	return $sql;
}

# for var 'editrunners'
sub _build_editrunners
{
	my $self = shift;
	$self->debug('Initializing edit runners...');
	
	my %runners;
	
	my @modules = MusicBrainz::DataBot::Edit->meta->subclasses;
	foreach my $module (@modules) {
		my $runner = Moose::Meta::Class->initialize($module)->new_object
			(bot => $self->bot,
			 sql => $self->sql);
		my $edit_type = $runner->edit_type;

		$runners{$edit_type} = $runner;
		$self->debug("Loaded runner $edit_type.");
	}

	return \%runners;
}

# Logging
sub debug
{
	my ($self, $message) = @_;
	MusicBrainz::DataBot::EditQueue->log->debug(localtime() . " $message \r\n"); 
}
sub info 
{
	my ($self, $message) = @_; 
	MusicBrainz::DataBot::EditQueue->log->info(localtime() . " $message \r\n");
}
sub error
{
	my ($self, $message) = @_; 
	MusicBrainz::DataBot::EditQueue->log->error(localtime() . " $message \r\n");
}

sub _get_log_params {
	my @PARAMS = shift;
	
	my ($self, $message) = @PARAMS;
	my $log;
	if (!defined $message) {
		$message = $self;
		$log = MusicBrainz::DataBot::EditQueue->log();
	} else {
		$log = $self->log;
	}
	
	return ($log, $message);
}

# Throttle
sub throttle { my ($self, $area) = @_; MusicBrainz::DataBot::Throttle->throttle($area); }

1;
