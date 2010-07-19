package MusicBrainz::DataBot::BaseTask;

use Moose;
use WWW::Mechanize;
use OSSP::uuid;

use Scalar::Util 'reftype';
use Carp qw/croak/;
use feature 'switch';

use MusicBrainz::DataBot::Throttle;


has 'bot' => (is => 'rw', required => 1);
has 'sql' => (is => 'rw', required => 1);

has 'uuidgen' => (is => 'ro', lazy => 1, default => sub { return OSSP::uuid->new; } );
has 'query' => (is => 'ro', required => 1, 
		lazy => 1, default => sub { 
			my $self = shift;
			
			my $schema = $self->schema;
			my $type = $self->type;
			
			return "SELECT * FROM $schema.batch_$type"; });


### To be defined by children
has 'type' => (is => 'ro', required => 1);
has 'schema' => (is => 'ro', required => 1);

sub run_task
{
	croak 'Not defined';
}

sub ready
{
	return 1;
}

### Exposed to other classes

sub run_tasks {
	my $self = shift;
	my $sql = $self->sql;
	
	my $tasksref = $sql->SelectListOfHashes($self->query);
	my @tasks = @$tasksref;
	my $numtasks = scalar @tasks;

	$self->debug("Loaded $numtasks tasks.");
	
	foreach my $task (@tasks) {
		eval {
			$self->run_task($task); 
			1;
		} or do {
			$self->report_failure($task->{id}, $@);
			$self->throttle('mberror');
		}
	}
	
	$self->debug('Finished edits.');
	
	return 1;
}

### For use by children

# Store result
sub report_success
{
	my ($self, $task) = @_;
	my $sql = $self->sql;
	my $schema = $self->schema;
	
	$self->info("Task $task was successful!");
	$sql->AutoCommit;
	$sql->Do("UPDATE $schema." . $self->type . " SET date_processed = NOW(), error = NULL WHERE id=$task") or $self->error("Error recording result");
	
	return 1; # Exit without error
}

sub report_failure
{
	my ($self, $task, $message) = @_;
	my $sql = $self->sql;
	my $schema = $self->schema;
	
	$self->error("Task $task failed: $message");
	
	if ($sql->IsInTransaction) {
		$sql->Rollback;
	}
	
	$sql->AutoCommit;
	$sql->Do("UPDATE $schema." . $self->type . " SET date_processed = NOW(), error = ? WHERE id=?", $message, $task) or $self->error("Error recording result");
	
	return 0; # Exit with error
}

# Logging
sub debug { my ($self, $message) = @_; return MusicBrainz::DataBot::Log->debug($message); }
sub info  { my ($self, $message) = @_; return MusicBrainz::DataBot::Log->info($message); }
sub error { my ($self, $message) = @_; return MusicBrainz::DataBot::Log->error($message); }

# Throttle
sub throttle { my ($self, $area) = @_; return MusicBrainz::DataBot::Throttle->throttle($area); }

# Prepare an array for insertion into a text[] column
sub quote_array {
	my ($self, $valueref) = @_;
	my $sql = $self->sql;
	
	my @value;
	
	foreach (@{$valueref}) {
		$_ =~ s/'/''/gx;
		push @value, $_;
	}
	
	my $quoted_value = 'E' . $sql->Quote(\@value);
	$quoted_value =~ s/\\"/\\\\"/gx;
	$quoted_value =~ s/^EE/E/x;
	
	return \$quoted_value;
}

# Generate a UUID value
sub gen_uuid {
	my ($self) = @_;
	my $uuidgen = $self->uuidgen;
	
	$uuidgen->make('v4');
	return $uuidgen->export('str');
}

# Wide character conversion
sub utf8_encode {
	my ($self, $value) = @_;

	given (reftype $value) {
		when (undef) { utf8::encode($value); }
		
		when (['REF', 'SCALAR']) { $value = $self->utf8_encode($$value); }
		when ('ARRAY') { $value = $self->utf8_encode_array($value); }
		when ('HASH') { $value = %{$value} ? $value = $self->utf8_encode_hash($value) : ''; }

		default { $self->error('Unknown reftype in utf8_encode: ' . (reftype $value) . "\n"); }
	}
	
	return $value;
}

sub utf8_encode_hash {
	my ($self, $hash) = @_;
	
	foreach my $key (keys %{$hash}) {
		$hash->{$key} = $self->utf8_encode($hash->{$key});
	}
	
	return $hash;
}

sub utf8_encode_array {
	my ($self, $arrayref) = @_;
	my @array = @{$arrayref};
	
	for (my $i=0;$i<=$#array;$i++) {
		$array[$i] = $self->utf8_encode(\$array[$i]);
	}
	
	return \@array;
}

# Build simple SELECT query
sub select_from {
	my ($self, $columns, $table, $params, $closing) = @_;
	my $sql = $self->sql;
	
	my $columntext = @{$columns} ? join(', ', @{$columns}) : '*';
	
	my @criteria;
	foreach my $key (keys(%{$params})) {
		push @criteria, $key . (($key =~ / /) ? '' :
					(!defined $params->{$key} ? ' IS ' : ' = ')) . $sql->Quote($params->{$key});
	}
	my $criteriatext = @criteria ? 'WHERE ' . join(' AND ', @criteria) : '';
	
	$closing = '' unless defined $closing;
	
	return "SELECT $columntext FROM $table $criteriatext $closing";
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;
