package MusicBrainz::DataBot::BaseTask;

use Moose;
use WWW::Mechanize;
use OSSP::uuid;

use Scalar::Util 'reftype';

use MusicBrainz::DataBot::Throttle;


has 'bot' => (is => 'rw', required => 1);
has 'sql' => (is => 'rw', required => 1);

has 'uuidgen' => (is => 'ro', lazy => 1, default => sub { return new OSSP::uuid; } );

### To be defined by children
sub type
{
	die 'Not defined';
}

sub query
{
	die 'Not defined';
}

sub schema
{
	die 'Not defined';
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
#		eval {
			$self->run_task($task);
#		};
		
		if ($@) {
			$self->report_failure($task->{id}, $@);
			$self->throttle('mberror');
		}
	}
	
	$self->debug('Finished edits.');
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
sub debug { my ($self, $message) = @_; MusicBrainz::DataBot::Log->debug($message); }
sub info  { my ($self, $message) = @_; MusicBrainz::DataBot::Log->info($message); }
sub error { my ($self, $message) = @_; MusicBrainz::DataBot::Log->error($message); }

# Throttle
sub throttle { my ($self, $area) = @_; MusicBrainz::DataBot::Throttle->throttle($area); }

# Prepare an array for insertion into a text[] column
sub quote_array {
	my ($self, $valueref) = @_;
	my $sql = $self->sql;
	
	my @value;
	
	foreach (@{$valueref}) {
		$_ =~ s/'/''/g;
		push @value, $_;
	}
	
	my $quoted_value = 'E' . $sql->Quote(\@value);
	$quoted_value =~ s/\\"/\\\\"/g;
	$quoted_value =~ s/^EE/E/;
	
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

	if (!defined reftype $value) {
		utf8::encode($value);
		return $value;
	} elsif (reftype $value eq 'ARRAY') {
		return $self->utf8_encode_array($value);
	} elsif (reftype $value eq 'HASH') {
		if (%{$value}) {
			return $self->utf8_encode_hash($value);
		} else {
			return '';
		}
	} elsif (reftype $value eq 'REF' || reftype $value eq 'SCALAR') {
		return $self->utf8_encode($$value);
	} else {
		$self->error('Unknown reftype in utf8_encode: ' . reftype $value . "\n");
	}
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
1;
