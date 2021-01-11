package Minion::Job::Role::Alerter;

use Role::Tiny;
use Mojo::Util qw/dumper/;

sub alert {
    my $job = shift;
    my $url = shift;

    my $package = __PACKAGE__;

    my %alert_ok;

    for (@{ ($job->opts && $job->opts->{alert_on})
      ||
      ($job->opts->{$package} && $job->opts->{$package}->{alert_on})
      ||
      [] }) { $alert_ok{$_}++ }

    $job->app->log->info((dumper $job->opts), (dumper ));
    if ($alert_ok{$job->info->{state}}) {
	return $job->app->ua->post('http://127.0.0.1:3000/status' => json => $job->info );
    }
}

my @subs = qw/
execute
fail
finish
kill
perform
remove
retry
run
start
stop
/;

for (qw/finish fail/) {
    after $_ => sub {
	my $job = shift;
	$job->alert();
    };
}

1;
