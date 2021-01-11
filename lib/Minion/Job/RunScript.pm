package Minion::Job::RunScript;

use Exporter 'import';
our @EXPORT_OK = qw(script);

use Mojo::Base qw(Minion::Job::Generator);

use Class::Method::Modifiers;
use Mojo::Util qw/dumper/;

around 'new' => sub {
    my $orig = shift;
    my $self = shift;

    my $script = 
	ref $_[0] ?
	$_[0]->{script} :
	shift();

    my $sub = sub {
	my (undef, $if, $of) = @_;
	system($script, $if, $of);
	# qx($script "$if" "$of");
    };

    $_[0]->{sub} = $sub;

    my $p = ref $self || $self;

    $self = $orig->($p, @_);
    return $self;
};

sub script {
    Minion::Job::RunScript->new(@_)
}

around 'run' => sub {
    my $orig = shift;
    my $self = shift;
    $self->app->log->info('in around run', dumper \@_);
    return $orig->($self, @_);
};

# -1 is fail in system

# sub run {
#     my $job = shift;
#     my $sub = shift;
#     $job->app->log->info('in around run', dumper @_);

#     $job->finish($sub->($job, @_));

# }

1;
