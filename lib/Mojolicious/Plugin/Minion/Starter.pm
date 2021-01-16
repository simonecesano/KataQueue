package Mojolicious::Plugin::Minion::Starter;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Mojo::File qw/path/;
use Mojo::Util qw/dumper/;
use Mojo::IOLoop::Subprocess;

use Proc::ProcessTable;

has processes => sub { Proc::ProcessTable->new } ;

has table => sub { [] };

has app => has app => sub { Mojo::Server->new->build_app('Mojo::HelloWorld') };
has config => sub { { } };

use Time::HiRes qw/time/;

sub register {
    my ($self, $app, $config) = (@_);
    $self->app($app);

    $self->start_reaper;

    $app->hook(before_server_start => $self->before_server_start_hook($config));
}

sub start_reaper {
    my $self = shift;
    my $config = shift;

    my $tick = $config->{timeout} || 5;
    $self->app->log->info(sprintf("Will reap zombie workers every %.2f seconds", $tick));
    Mojo::IOLoop->recurring($tick => $self->reaper($config));
}

sub reaper {
    my $self = shift;
    my $config = shift;

    my $reaper = sub {
        my $start = time;
        $self->check;
        my $reaped = $self->reap;
        if ($reaped && $config->{log}) {
            $self->app->log->info(sprintf "Reaped %d zombies in %.4f seconds", $reaped, time - $start);
        }
    };
    if ($config->{run}) { $reaper->() } else { $reaper }
}

sub before_server_start_hook {
    my $self = shift;
    my $spawn = (shift() || {})->{spawn};

    $spawn //= 1; $spawn = $spawn <= 0 ? 1 : $spawn;

    sub {
        my $ppid = $$;
        my $server_pid = 0;

        $self->app->log->info(sprintf("Preparing to spawn %d processes", $spawn));
        for (0..($spawn - 1)) {
            my $subprocess = Mojo::IOLoop::Subprocess->new;
            $subprocess->run(
                             sub ($subprocess) { $self->app->minion->worker->run },
                             sub ($subprocess, $err, @results) { $self->app->log->info($err) }
                            );
            $subprocess->on(spawn => sub ($subprocess) {
                                $self->app->log->info(sprintf("Spawned Minion worker with pid %d and ppid %d", $subprocess->pid, $$));
                            });
            $subprocess->on(cleanup => sub ($subprocess) { $self->app->log->info("Process $$ is about to exit") });
        }
	$self->reaper({ log => 1, run => 1 });
    }
}

sub DESTROY {
    my $self = shift;
}

sub check {
    my $self = shift;
    my $all = shift;
    $self->table( [ map { $_ } grep { path($_->cmndline)->basename eq $0 } @{$self->processes->table} ]);
}

sub chain {
    my $self = shift;
    my %chain;
    for (@{$self->table}) {
        $chain{$_->ppid} = [] unless $chain{$_->ppid};
        push @{$chain{$_->ppid}}, $_->pid;
    }
    return \%chain;
}

sub descendants {
    my $self = shift;
    my $pid = shift || $$;
    my $desc = shift;

    my $chain = $self->chain;

    push @$desc, getppid if $pid == $$;
    push @$desc, $pid if $pid == $$;

    for (@{$chain->{$pid}}) {
        push @$desc, $_;
        $self->descendants($_, $desc);
    }
    return $desc;
}

sub zombies {
    my $self = shift;
    my @processes = @{$self->table};
    my %legit;

    @legit{@{$self->descendants}} = @{$self->descendants};

    return [ map { $_->pid } grep { !$legit{$_->pid} } @processes ];
}

sub reap {
    my $self = shift;
    my @zombies = @{$self->zombies};

    return kill 'HUP', @zombies;
}

1
