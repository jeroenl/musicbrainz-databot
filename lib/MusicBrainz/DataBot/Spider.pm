package MusicBrainz::DataBot::Spider;

use Moose;

use WWW::Mechanize;
use Log::Dispatch;
use Log::Dispatch::File;
use Log::Dispatch::Screen;

use MusicBrainz;
use Sql;

use MusicBrainz::DataBot::Throttle;
use MusicBrainz::DataBot::BotConfig;
use MusicBrainz::DataBot::Spider::BaseSpiderTask;

has 'bot' => (is => 'ro', default => sub { my $m = WWW::Mechanize->new; $m->agent_alias('Windows IE 6'); return $m; } );
has 'mbc' => (is => 'ro', default => sub { my $mb = new MusicBrainz; $mb->Login(); return $mb; } );
has 'sql' => (is => 'ro', builder => '_build_sql');
has 'spiders' => (is => 'ro', isa => 'HashRef', lazy => 1, builder => '_build_spiders');

### Queue processing

sub run {
	my $self = MusicBrainz::DataBot::Spider->new;
	
	while (1) {
		$self->_run;
	}
}

sub _run {
	my $self = shift;
	
	my $sql = $self->sql;
	my %spiders = %{$self->spiders};
	my $openeditcount;
		
	my $spidertypes = $sql->SelectSingleColumnArray('SELECT type from mspider.tasks WHERE date_processed IS NULL GROUP BY type ORDER BY COUNT(1) DESC');

	unless (defined $spidertypes) {
		$self->info('No flies left to catch...');
		return;
	}

	foreach my $spidertype (@{$spidertypes}) {
		if (!defined $spiders{$spidertype}) {
			$self->error("Spider '$spidertype' does not exist... skipping.");
			next;
		}
		
		my $spider = $spiders{$spidertype};
		
		$self->info("Running '$spidertype' tasks...");
		return $spider->run_tasks;
	}
	
	$self->info('Nothing to be done, at the moment...');
	$self->throttle('flyquery');
}

### Utilities

# for var 'sql'
sub _build_sql
{
	my $self = shift;
	my $sql = new Sql($self->mbc->{DBH});
	return $sql;
}

# for var 'spiders'
sub _build_spiders
{
	my $self = shift;
	$self->debug('Initializing spiders...');
	
	my %spiders;
	
	my @modules = MusicBrainz::DataBot::Spider::BaseSpiderTask->meta->subclasses;
	foreach my $module (@modules) {
		my $spider = Moose::Meta::Class->initialize($module)->new_object
			(bot => $self->bot,
			 sql => $self->sql);
		my $spider_type = $spider->type;

		$spiders{$spider_type} = $spider;
		$self->debug("Loaded spider $spider_type.");
	}

	return \%spiders;
}

# Logging
sub debug
{
	my ($self, $message) = @_;
	MusicBrainz::DataBot::Log->log->debug(localtime() . " $message \r\n"); 
}
sub info 
{
	my ($self, $message) = @_; 
	MusicBrainz::DataBot::Log->log->info(localtime() . " $message \r\n");
}
sub error
{
	my ($self, $message) = @_; 
	MusicBrainz::DataBot::Log->log->error(localtime() . " $message \r\n");
}

# Throttle
sub throttle { my ($self, $area) = @_; MusicBrainz::DataBot::Throttle->throttle($area); }

1;
