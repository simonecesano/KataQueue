package Mojolicious::Plugin::Server::MoreHooks;

use Mojo::Base 'Mojolicious::Plugin', -signatures;

my $app;

has app => sub { $app = Mojo::Server->new->build_app('Mojo::HelloWorld') };

has config => sub { {} };

use Class::Method::Modifiers qw/fresh install_modifier/;
require Mojo::Server::Prefork;

sub register {
    my $self = shift;
    my $app = shift;
    my $config = shift;

    $self->app($app);
    $self->app->log->info("Started " . __PACKAGE__);

    $self->app($app);
    $self->config($config);

    my @events_ok;
    $app->hook(before_server_start => $self->install_modifiers_hook);
    $app->hook(before_server_start => $self->test_modifiers_hook) if $self->config->{test};
};

sub this_does_not_work_install_hooks {
    my $self = shift;
    my $server = shift;
    my @events = @_;
    my @events_hooked;

    my $class = ref $server;

    for my $event (@events) {
	if ($class->can($event)) {
	    push @events_hooked, $event;

	    $self->app->log->info('can ok ' . $event);

	    install_modifier $class => around => $event => sub {
		my $orig = shift;
		my $server = shift;
		$self->app->plugins->emit_hook("before_$event" => $server );
		$server->emit("before_$event" => 1);

		my $ret = $orig->($server, @_);

		$server->emit("after_$event" => 1);
		$app->plugins->emit_hook("after_$event" => $server );

		return $ret;
	    }
	}
    };
    return @events_hooked;
}

sub install_modifiers_hook{
    my $self = shift;
    sub {
	my ($server, $app) = @_;
	my $class = ref $server;

	$self->app->log->info(sprintf "Installing modifiers on %s", ref $server) if $self->config->{debug};

	my @events_ok;

	for my $event (@{$self->config->{events} || []}) {
	    if ((ref $server)->can($event)) {
		push @events_ok, $event;
		$self->app->log->info(sprintf "%s can %s", (ref $server), $event) if $self->config->{debug};
		install_modifier $class => around => $event => sub {
		    my ($orig, $server) = @_;

		    $self->app->plugins->emit_hook("before_$event" => $server );
		    $server->emit("before_$event" => 1);

		    my $ret = $orig->($server, @_);
		    $server->emit("after_$event" => 1);
		    $app->plugins->emit_hook("after_$event" => $server );
		    return $ret;
		}
	    }
	}
	$self->app->log->info('Installed hooks for: ' . (join ', ', @events_ok))  if $self->config->{debug};
    };
}

sub test_modifiers_hook{
    my $self = shift;
    sub {
	my ($server, $app) = @_;
	$self->app->log->info(sprintf "Testing hooks on %s", ref $server);

	for my $event (@{$self->config->{events} || []}) {
	    if ((ref $server)->can($event)) {
		$server->on("before_$event" => sub { $app->log->info(join ', ', "before_$event", @_) });
		$server->on("after_$event" =>  sub { $app->log->info(join ', ', "after_$event", @_) });
	    }
	}
    }
}

1;
