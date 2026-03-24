
A place to keep GPFS maintenance scripts, mostly run by Jenkins.

Initially this will be snapshot deletions, but it will also eventually
include snapshot creation, backups, and reports.

cpanfile contains a list of Perl modules required for the scripts
here.  The ```run_perl.sh``` wrapper will make sure the modules are
installed and checked out before running a Perl script:

```
./run_perl.sh myscript.pl --and --more --parameters
```


