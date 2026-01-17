#!/usr/bin/env perl

use Data::Dumper;
use Date::Manip;
use Getopt::Long;
use IPC::Open3;
use Symbol 'gensym';

use strict;

# parse command-line options
my $filesystem;
my $verbose;
my $days = 8;
my $notreally = 0;
GetOptions (
    "days=i"       => \$days,
    "filesystem=s" => \$filesystem,
    "verbose"      => \$verbose,
    "notreally"    => \$notreally,
    ) or die("Error in command line arguments\n");

die "Specify filesystem with --filesystem" unless $filesystem;

my $err;

my $pid = open3(my $chld_in, my $chld_out, my $chld_err = gensym,
    'mmlssnapshot', $filesystem);

my @stdout = <$chld_out>;
my @stderr = <$chld_err>;

waitpid($pid, 0);

my @daily = map { (split)[0] } grep { /^\d{8}-/ } @stdout;
my @global = map { (split)[0] } grep { /^\Q$filesystem\E\./ } @stdout;

my $date = UnixDate( DateCalc('today', "-$days days"), "%Y%m%d");

printf "Days is %s\n", $days;
printf "Cutoff date is %s\n", $date;

print "Deleting daily snapshots\n";
my $daily_deleted = 0;

foreach my $snap (@daily) {

    my ($snapdate, $fileset) = split /-/, $snap, 2;

    if ($snapdate lt $date) {
        if ($notreally) {
            printf "Skipping %s\n", $snap;
        }
        else {
            printf "Deleting %s\n", $snap;
            system('mmdelsnapshot', $filesystem, sprintf("%s:%s", $fileset, $snap));
            my $rc = $? >> 8;
            printf "RC=%s\n", $rc;
            $daily_deleted++;
        }
    }
}
printf "Deleted %s daily snapshots\n", $daily_deleted;

print "Deleting global snapshots\n";
my $global_deleted = 0;

# remove the last global
pop @global;

foreach my $snap (@global) {
    if ($notreally) {
        printf "Skipping %s\n", $snap;
    }
    else {
        printf "Want to delete %s\n", $snap;
        $global_deleted++;
    }
}
printf "Deleted %s global snapshots\n", $global_deleted;

