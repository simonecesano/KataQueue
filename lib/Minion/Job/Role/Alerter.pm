package Minion::Job::Role::Alerter;

use Role::Tiny;
use Mojo::Util qw/dumper/;

sub alert {
    my $job = shift;
    my $event = shift;

    my $package = __PACKAGE__;

    my %alert_ok;

    for (@{ ($job->opts && $job->opts->{alert_on})
      ||
      ($job->opts->{$package} && $job->opts->{$package}->{alert_on})
      ||
      [] }) { $alert_ok{$_}++ }

    my $url = $job->opts && $job->opts->{url}
	|| $job->opts->{$package} && $job->opts->{$package}->{url}
	|| 'http://127.0.0.1:3000/status';

    $job->app->log->info(join ': ', $event, $alert_ok{$event});

    my $info = $job->info;

    $info->{event} = $event;

    if ($alert_ok{$event}) {
	return $job->app->ua->post($url => json => $info );
    }
}

my @after_subs = qw/
fail
finish
/;

my @before_subs = qw/
execute
kill
perform
remove
retry
run
start
stop
/;

for my $sub (@after_subs) {
    after $sub => sub {
	my $job = shift;
	$job->alert($sub);
    };
}

for my $sub (@before_subs) {
    before $sub => sub {
	my $job = shift;
	$job->alert($sub);
    };
}

1;
