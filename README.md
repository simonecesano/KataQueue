# KataQueue

This is a test ground for Minion experiments- README.md

- lib/Minion/Job/Generator.pm - a job generator for Minion queues 
- lib/Minion/Job/Role/Alerter.pm - a role that alert on finish/fail
- lib/Minion/Job/Role/Timeout.pm - a role that limits the running time of a job
- lib/Minion/Job/RunScript.pm - a role that runs shells scripts
- lib/Mojolicious/Plugin/Minion/Starter.pm - a plugin that starts and stops minion workers together with the server
- lib/Mojolicious/Plugin/Server/MoreHooks.pm - a plugin that allows adding custom hooks to servers 