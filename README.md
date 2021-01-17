# KataQueue

This is a test ground for Minion experiments

- lib/Minion/Task/Generator.pm - a job generator for Minion queues 
- lib/Minion/Job/Role/Alerter.pm - a role that alert on finish/fail
- lib/Minion/Job/Role/Timeout.pm - a role that limits the running time of a job
- lib/Minion/Task/RunScript.pm - a role that runs shells scripts
- lib/Mojolicious/Plugin/Minion/Starter.pm - a plugin that starts and stops minion workers together with the server
- lib/Mojolicious/Plugin/Server/MoreHooks.pm - a plugin that allows adding custom hooks to servers

## Minion::Task::Generator - a plugin for generating Minion tasks and jobs 

### Description

### Synopsis

    use Minion::Task::Generator qw/task/;

    app->minion->add_task(some_task => task(sub {
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


### Description

Allows flexible creation of tasks with pluggable and configurable roles. 

### Methods

#### new

    my $task = Minion::Task::Generator->new(sub {}, { roles => {} })

Creates a new task that executes the subref passed as the first argument, and the options as the second.

The "roles" option defines which roles will be applied to the job on execution; if a role begins with "+", "Minion::Job::Role" gets prepended to the role name in place of the plus sign.

The hashref values of the roles option get passed to the role on job execution. 

## Minion::Job::Role::Alerter

## Minion::Job::Role::Timeout

## Minion::Job::RunScript