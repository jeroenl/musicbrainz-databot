package MusicBrainz::DataBot::BaseTaskApp;

use Moose;

use WWW::Mechanize;

use MusicBrainz;
use Sql;

use MusicBrainz::DataBot::BotConfig;
use MusicBrainz::DataBot::Throttle;
use MusicBrainz::DataBot::Log;

has 'bot' => (is => 'ro', default => sub { my $m = WWW::Mechanize->new; $m->agent_alias('Windows IE 6'); return $m; } );
has 'mbc' => (is => 'ro', default => sub { my $mb = MusicBrainz->new; $mb->Login(); return $mb; } );
has 'sql' => (is => 'ro', builder => '_build_sql');
has 'config' => (is => 'ro', lazy => 1, builder => '_build_config');
has 'runners' => (is => 'ro', isa => 'HashRef', lazy => 1, builder => '_build_runners');

### To be defined by children
has 'runner_class' => (is => 'ro', required => 1);
has 'task_table' => (is => 'ro', required => 1);

### Queue processing

sub run {
	my $class = shift;
	my $self = $class->new;
	
	while (1) {
		$self->_run;
	}
	
	return 1;
}

sub _run {
	my $self = shift;
	
	my $sql = $self->sql;
	my $task_table = $self->task_table;

	my %runners = %{$self->runners};
		
	my $runnertypes = $sql->SelectSingleColumnArray("SELECT type from $task_table WHERE date_processed IS NULL GROUP BY type ORDER BY COUNT(1) DESC");

	unless ($runnertypes) {
		$self->info('Nothing to do...');
		return;
	}

	foreach my $runnertype (@{$runnertypes}) {
		if (!defined $runners{$runnertype}) {
			$self->error("Task runner '$runnertype' does not exist... skipping.");
			next;
		}
		
		my $runner = $runners{$runnertype};
		
		unless ($runner->ready) {
			$self->error("Runner '$runnertype' is not ready... skipping.");
			next;
		}
		
		$self->info("Running '$runnertype' tasks...");
		return $runner->run_tasks;
	}
	
	$self->info('Nothing to be done, at the moment...');
	$self->throttle('taskquery');
	
	return 1;
}

### Utilities

# Build vars
sub _build_sql    { my $self = shift; return Sql->new($self->mbc->{DBH}); }
sub _build_config { my $self = shift; return MusicBrainz::DataBot::BotConfig->new(sql => $self->sql); }
sub _build_runners
{
	my $self = shift;
	$self->debug('Initializing runners...');
	
	my %runners;
	
	my @modules = $self->runner_class->subclasses;
	foreach my $module (@modules) {
		my $runner = Moose::Meta::Class->initialize($module)->new_object
			(bot    => $self->bot,
			 sql    => $self->sql,
			 config => $self->config);
		my $runner_type = $runner->type;

		$runners{$runner_type} = $runner;
		$self->debug("Loaded runner $runner_type.");
	}

	return \%runners;
}

# Logging
sub debug { my ($self, $message) = @_; return MusicBrainz::DataBot::Log->debug($message); }
sub info  { my ($self, $message) = @_; return MusicBrainz::DataBot::Log->info($message); }
sub error { my ($self, $message) = @_; return MusicBrainz::DataBot::Log->error($message); }

# Throttle
sub throttle { my ($self, $area) = @_; return MusicBrainz::DataBot::Throttle->throttle($area); }

__PACKAGE__->meta->make_immutable;
no Moose;

1;
