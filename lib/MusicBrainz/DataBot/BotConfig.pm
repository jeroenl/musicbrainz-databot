package MusicBrainz::DataBot::BotConfig;

use Moose;
use Carp qw/croak/;

has 'sql' => (is => 'rw', required => 1);

sub get_config {
	my ($self, $key) = @_;
	my $sql = $self->sql;
	
	my $value = $sql->SelectSingleValue('SELECT config_value FROM mbot.config WHERE config_key = ?', $key);
	unless (defined $value) {
		croak "Config key $key is undefined";
	}
	
	return $value;
}

sub set_config {
	my ($self, $key, $value) = @_;
	my $sql = $self->sql;
	
	unless (defined $self->get_config($key)) {
		croak "Config key $key is undefined";
	}
	
	$sql->SelectSingleValue('UPDATE mbot.config SET config_value = ? WHERE config_key = ?', $value, $key);
	
	return 1;
}
	
__PACKAGE__->meta->make_immutable;
no Moose;

1;
