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
GetOptions (
    "days=i"       => \$days,
    "filesystem=s" => \$filesystem,
    "verbose"      => \$verbose,
    ) or die("Error in command line arguments\n");

die "Specify filesystem with --filesystem" unless $filesystem;

my $err;

my $pid = open3(my $chld_in, my $chld_out, my $chld_err = gensym,
    'mmlssnapshot', $filesystem);

my @stdout = <$chld_out>;
my @stderr = <$chld_err>;

waitpid($pid, 0);

#print Dumper(\@stdout);

my @daily = map { (split)[0] } grep { /^\d{8}-/ } @stdout;
my @global = map { (split)[0] } grep { /^\Q$filesystem\E\./ } @stdout;

#print Dumper({ daily => \@daily, global => \@global });

my $date = UnixDate( DateCalc('today', "-$days days"), "%Y%m%d");

printf "Days is %s\n", $days;
printf "Cutoff date is %s\n", $date;

foreach my $snap (@daily) {

    my ($snapdate, $fileset) = split /-/, $snap, 2;

    if ($snapdate lt $date) {
        printf "Want to delete %s\n", $snap;
        system('mmdelsnapshot', $filesystem, sprintf("%s:%s", $fileset, $snap));
    }
}

# remove the last global
pop @global;

foreach my $snap (@global) {
    printf "Want to delete %s\n", $snap;
}


