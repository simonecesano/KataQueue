#!/usr/bin/env perl
use FindBin;
use lib "$FindBin::Bin/./lib";

use Mojolicious::Lite -signatures;
use Mojo::Util qw(dumper md5_sum);
use Mojo::SQLite;
use Mojo::File qw/path/;
use Mojo::Promise;

use Minion::Task::Generator qw/task/;
use Minion::Task::RunScript qw/script/;

use Encode;
use Hash::Merge qw/merge/;
use Time::Out qw(timeout) ;

plugin Minion => { SQLite => 'sqlite:queue.db' };
plugin 'Minion::Admin';

plugin 'Minion::Starter' => { spawn => 4, log => 1 };

plugin 'Config';

app->minion->add_task(some_task => task(sub {
				       my $job = shift;
				       sleep 1;
				       $job->app->log->info('I am a task');
				       sleep 1;
				       return 'Done!';
				   },
				   {
				    roles => {
					      '+Alerter' => { 'alert_on' => [qw/start finish fail execute run/ ], url => 'http://127.0.0.1:3000/status' },
					      # '+Timeout' => { timeout => 6 }
					     }
				   }));

app->minion->add_task(negate => script('scripts/negate.sh'));

app->minion->add_task
    (thing => sub ($job, $c, $sub, @args) {
	 my $id   = $job->id;
	 my $task = $job->task;
	 $job->app->log->info(qq{Job "$id" was performed with task "$task"});
     });

get '/' => sub {
    my $c = shift;
    # $c->minion->enqueue('negate',  [ 'temp/Wilhelmhallen.jpg', 'temp/Wilhelmhallen-negate.jpg' ], { priority => 1});
    $c->minion->enqueue('some_task',  [ 'temp/Wilhelmhallen.jpg', 'temp/Wilhelmhallen-negate.jpg' ], { priority => 1});

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
    $c->log->info(dumper $json);
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
