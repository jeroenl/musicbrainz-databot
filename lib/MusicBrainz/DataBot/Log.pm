package MusicBrainz::DataBot::Log;

use Moose;
use MooseX::ClassAttribute;

use Log::Dispatch;
use Log::Dispatch::Screen;

class_has 'log' => (is => 'ro', default => 
	sub 
	{
		my $log = Log::Dispatch->new;
		#$log->add ( Log::Dispatch::File->new( name => 'infolog', min_level => 'info', filename => 'edit.log' ) );
		$log->add ( Log::Dispatch::Screen->new ( name => 'debugscreen', min_level => 'debug' ) );
		return $log;
	} );


# Logging
sub debug
{
	my ($self, $message) = @_;
	$self->log->debug(localtime() . " $message \r\n"); 
}
sub info 
{
	my ($self, $message) = @_; 
	$self->log->info(localtime() . " $message \r\n");
}
sub error
{
	my ($self, $message) = @_; 
	$self->log->error(localtime() . " $message \r\n");
}

1;
