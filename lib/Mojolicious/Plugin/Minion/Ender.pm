package Mojolicious::Plugin::Minion::Ender;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Mojo::File qw/path/;
use Mojo::Util qw/dumper/;

use Config;
use Try::Tiny;

my $app;

has app => sub { Mojo::Server->new->build_app('Mojo::HelloWorld') };

has workers => sub { [] };

has root_process => 0;

my @workers;

my @servers_ok = qw/Mojo::Server::Prefork Mojo::Server::Daemon/;

sub register {
    my $self = shift;
    $app = shift;
    my $config = shift;
    $self->app($app);
    $app->log->info('Started ' . __PACKAGE__);
    $app->hook(before_server_start => $self->before_server_start_hook($config));
}

sub before_server_start_hook{
    my $self = shift;
    my $spawn = (shift() || {})->{spawn};

    $spawn //= 1; $spawn = $spawn <= 0 ? 1 : $spawn;

    sub {
	my ($server, $app) = @_;

	$app->log->info(sprintf "Server type is %s, process %d", ref $server, $$);
	$app->log->info(sprintf "Pid of parent of server process is %d", getppid());

	# Mojo::Server::PSGI + plackup: parent is shell, server is plackup
	# Mojo::Server::PSGI + starman: parent is starman
	# Mojo::Server::Daemon morbo: parent is not shell

	my $msg_done;
	if (ref $server eq 'Mojo::Server::Daemon') {
	} elsif (ref $server eq 'Mojo::Server::Prefork') {
	    $app->log->info(sprintf "Warning: %s does not support daemonized server type %s", __PACKAGE__, ref $server) unless $msg_done++;
	} else {
	    $app->log->info(sprintf "%s does not support server type %s", __PACKAGE__, ref $server) unless $msg_done++;
	    return;
	}

	$self->root_process($$);
	$self->spawn_worker for (0..($spawn - 1));
    }
}

sub spawn_worker {
    my $self = shift;
    if (my $pid = fork) {
	push @{$self->workers}, $pid;
	push @workers, $pid;
	return;
    } else {
	$app->log->info("Starting minion worker $$ inside " . getppid());
	$app->minion->worker->run;
    }
}

sub DESTROY {
    my $self = shift;

    for (grep { (kill 0 => $_) && ($$ != $_ ) } @{$self->workers}) {
	if (kill HUP => $_) {
	} else {
	}
    }
}

1;
