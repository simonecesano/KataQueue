#!/usr/bin/env perl
use FindBin;
use lib "$FindBin::Bin/./lib";

use Mojolicious::Lite -signatures;
use Mojo::Util qw(dumper md5_sum);
use Mojo::SQLite;
use Mojo::File qw/path/;
use Mojo::Promise;

use Minion::Job::Dirty;
use Minion::Job::Flexy;
use Minion::Job::Generator qw/job/;

use Minion::Job::RunScript qw/script/;
use Minion::Job::Object;

use Encode;
use Hash::Merge qw/merge/;
use Time::Out qw(timeout) ;

plugin Minion => { SQLite => 'sqlite:queue.db' };
plugin 'Minion::Admin';

plugin 'Minion::Starter' => { timeout => 3, spawn => 4, log => 1 };

plugin 'Config';

# app->minion->add_task(flexy => job(sub {
# 				       my $job = shift;
# 				       sleep 5;
# 				       $job->app->log->info('I am FLEXY');
# 				       sleep 5;
# 				       return 'FLEXY wins';
# 				   },
# 				   {
# 				    roles => { '+Alerter' => { 'alert_on' => [qw/finished failed/ ] } }
# 				   }));

app->minion->add_task(some_task => job(sub {
				       my $job = shift;
				       sleep 5;
				       $job->app->log->info('I am a task');
				       sleep 5;
				       return 'Done!';
				   },
				   {
				    roles => {
					      '+Alerter' => { 'alert_on' => [qw/finished failed/ ], url => 'http://127.0.0.1:3000/status' },
					      '+Timeout' => { timeout => 6 }
					     }
				   }));

app->minion->add_task(negate => script('scripts/negate.sh'));
# app->minion->add_task(some_script => script('convert -negate'));


app->minion->add_task
    (thing => sub ($job, $c, $sub, @args) {
	 my $id   = $job->id;
	 my $task = $job->task;
	 $job->app->log->info(qq{Job "$id" was performed with task "$task"});
     });

app->minion->add_task(object => Minion::Job::Object->new({ task => sub {
							my $self = shift;
							print STDERR "doing something\n";
						    }}));




get '/' => sub {
    my $c = shift;
    # $c->minion->enqueue('negate',  [ 'temp/Wilhelmhallen.jpeg', 'temp/Wilhelmhallen-negate.jpeg' ], { priority => 1});
    $c->minion->enqueue('some_task',  [ 'temp/Wilhelmhallen.jpeg', 'temp/Wilhelmhallen-negate.jpeg' ], { priority => 1});

    $c->render(template => 'index');
};

get '/scripts' => sub {

};

get '/tasks' => sub {
    my $c = shift;
    $c->app->log->info('here');
    $c->res->headers->content_type('text/plain');
    $c->render(text => dumper $c->app->minion->tasks);
};

post '/status' => sub {
    my $c = shift;
    $c->app->log->info('here');

    my $json = $c->req->json;
    # $c->log->info(dumper $json);
    $c->render(json => $json);
};

post '/upload' => sub {
    my $c = shift;
    $c->app->log->info('here');

    my $json = $c->req->json;

    my $file = $json->{file};
    my $path = $json->{path};
    my $host = $json->{host};
    my $md5  = md5_sum($file);

    # possible conflict here
    # also need to fix suffix
    my $tempfile = path('./temp/', $md5 . '.jpg');

    $tempfile->spurt($file);

    my $id = $c->minion->enqueue('straighten_image', [ $md5, $tempfile, $path, $host ]);
    $c->render(json => { length => length $file, md5 => $md5, id => $id });
};

app->log->info('process id is ' . $$);

app->log->info('this is the app: ' . app);

use Mojo::IOLoop::ReadWriteFork;

get '/fork' => sub {
    my $c = shift;
    $c->render(json => { length => 12 });
};


my $pid;

app->start;

# Mojo::IOLoop->start unless Mojo::IOLoop->is_running;


__DATA__

@@ index.html.ep
% layout 'default';
% title 'Welcome';
<h1>Welcome to the Mojolicious real-time web framework!</h1>

@@ layouts/default.html.ep
<!DOCTYPE html>
<html>
  <head><title><%= title %></title></head>
  <body><%= content %></body>
</html>
