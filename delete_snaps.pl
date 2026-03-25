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
my $days = 21;
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

my @daily = sort { lc($a) cmp lc($b) } map { (split)[0] } grep { /^\d{8}-/ } @stdout;
my @global = sort { $a cmp $b } map { (split)[0] } grep { /^\Q$filesystem\E\./ } @stdout;

my $date = UnixDate( DateCalc('today', "-$days days"), "%Y%m%d");

system('mmlspool', '--block-size', 'auto', $filesystem);

printf "Days is %s\n", $days;
printf "Cutoff date is %s\n", $date;

print "Deleting daily snapshots\n";
my $daily_deleted = 0;
my $daily_failed = 0;

my $daily_total = 0;

foreach my $snap (@daily) {

    my ($snapdate, $fileset) = split /-/, $snap, 2;

    if ($snapdate lt $date) {
        $daily_total++;

        if ($notreally) {
            printf "Skipping %s\n", $snap;
        }
        else {
            printf "Deleting %s\n", $snap;
            system('mmdelsnapshot', $filesystem, sprintf("%s:%s", $fileset, $snap));
            my $rc = $? >> 8;
            printf "RC=%s\n", $rc;
            if ($rc == 0) {
              $daily_deleted++;
            }
            else {
              $daily_failed++;
            }
        }
    }
}
printf "Deleted %s daily snapshots\n", $daily_deleted;

print "Deleting global snapshots\n";
my $global_deleted = 0;
my $global_failed = 0;

# save the last global by removing it from the end of the list
if (@global) {
    printf "Found %s global snapshots.\n", scalar @global;

    my $saving_global = pop @global;

    printf "Removed %s from global list to save.\n", $saving_global;
}

my $global_total = scalar @global;

foreach my $snap (@global) {
    if ($notreally) {
        printf "Skipping %s\n", $snap;
    }
    else {
        printf "Deleting %s\n", $snap;
        system('mmdelsnapshot', $filesystem, $snap);
        my $rc = $? >> 8;
        printf "RC=%s\n", $rc;
        if ($rc == 0) {
          $global_deleted++;
        }
        else {
          $global_failed++;
        }
    }
}
printf "Deleted %s global snapshots\n", $global_deleted;

system('mmlspool', '--block-size', 'auto', $filesystem);

my $free_space = `mmlspool $filesystem --block-size auto | awk '\$1=="SAS7K" {print \$8}'`;
chomp $free_space;

printf "BUILDMSG: Deleted %s/%s daily (%s failed), %s/%s global snapshots (%s failed).  %s free.\n",
    $daily_deleted, $daily_total, $daily_failed, $global_deleted, $global_total, $global_failed, $free_space;

exit_with_code(0) if ( ($daily_total + $global_total) == 0 );      # there wasn't anything to delete
exit_with_code(9) if ( ($daily_deleted + $global_deleted) == 0 );  # nothing got deleted
exit_with_code(1) if $daily_total && ! $daily_deleted;             # no dailies got deleted
exit_with_code(2) if $global_total && ! $global_deleted;           # no globals got deleted

exit 0;

sub exit_with_code {
    my $rc = shift;
    printf "Exiting RC=%s\n", $rc;
    exit $rc;
}

