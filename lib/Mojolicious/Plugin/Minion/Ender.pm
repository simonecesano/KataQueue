package Mojolicious::Plugin::Minion::Ender;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Mojo::File qw/path/;
use Mojo::Util qw/dumper/;

use Config;

my $app;

has app => sub { Mojo::Server->new->build_app('Mojo::HelloWorld') };

has workers => sub { [] };

has root_process => 0;

my @workers;

sub register {
    my $self = shift;
    $app = shift;
    my $config = shift;
    $self->app($app);
    $app->log->info('Started ' . __PACKAGE__);

    $self->catch_sig;
    
    $app->hook(before_server_start => $self->before_server_start_hook($config));
}

sub before_server_start_hook{
    my $self = shift;
    my $spawn = (shift() || {})->{spawn};

    $spawn //= 3; $spawn = $spawn <= 0 ? 1 : $spawn;

    sub {
	my ($server, $app) = @_;

	# Mojo::Server::PSGI + plackup: parent is shell, server is plackup
	# Mojo::Server::PSGI + starman: parent is starman
	# Mojo::Server::Daemon morbo: parent is not shell

	$app->log->info("server type is " . ref $server);
	$app->log->info("server process is $$");
	$app->log->info(sprintf "parent of server process is %d", getppid());

	$self->root_process($$);
	$self->start_reaper;
	$self->spawn_worker for (0..($spawn - 1));
    }
}

sub reaper {
    my $self = shift;
    my $config = shift;

    my $reaper = sub {
	$self->app->log->info(sprintf "root process is %d and it's %s", $self->root_process, (kill 0 => $self->root_process) ? 'alive' : 'dead');
	$self->app->log->info(sprintf "these are worker processes %s", join ', ', @{$self->workers});
    };
    if ($config->{run}) { $reaper->() } else { $reaper }
}

sub catch_sig {
    my $self = shift;
    defined $Config{sig_name} or die "No sigs?";
    $self->app->log->info($Config{sig_name});

    # foreach $name (split(' ', $Config{sig_name})) {
    # 	$signo{$name} = $i;
    # 	$signame[$i] = $name;
    # 	$i++;
    # }
}

sub start_reaper {
    my $self = shift;
    my $config = shift;

    my $tick = $config->{timeout} || 5;
    $self->app->log->info(sprintf("Will reap zombie workers every %.2f seconds", $tick));

    Mojo::IOLoop->recurring($tick => $self->reaper($config));
}

sub spawn_worker {
    my $self = shift;
    if (my $pid = fork) {
	push @{$self->workers}, $pid;
    } else {
	$app->log->info("Starting minion worker $$ inside " . getppid());
	$app->minion->worker->run;
    }
}

sub END {
    print STDERR ('-' x 80) . "\n";
}

sub DESTROY {
    my $self = shift;

    @workers = @{$self->workers};

    $app->log->info(sprintf "Ending %d worker(s)", scalar @{$self->workers});

    for (@{$self->workers}) {
	if (kill HUP => $_) {
	    $app->log->info(sprintf "Ending worker %d", $_);
	} else {
	    $app->log->info(sprintf "Could not end worker %d", $_);
	}
    }
}

1;
