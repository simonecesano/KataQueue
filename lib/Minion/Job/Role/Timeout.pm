package Minion::Job::Role::Timeout;

use Time::Out qw(timeout);

use Role::Tiny;

sub run {
    my $job = shift;
    my $sub = shift;

    my $package = __PACKAGE__;
    my $timeout = $job->opts && $job->opts->{timeout} || $job->opts->{$package} && $job->opts->{$package}->{timeout};

    # $job->app->log->info("timeout in $timeout");

    my $res = timeout $timeout => $job, @_, $sub;

    if ($@){
    	$job->fail(sprintf "%s at %.2f seconds", $@, $timeout)
    } else {
    	$job->finish($res)
    }
};

1;
