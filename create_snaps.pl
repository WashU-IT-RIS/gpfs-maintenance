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
my $tries = 3;
GetOptions (
    "filesystem=s" => \$filesystem,
    "tries=i"      => \$tries,
    "verbose"      => \$verbose,
    "notreally"    => \$notreally,
    ) or die("Error in command line arguments\n");

die "Specify filesystem with --filesystem" unless $filesystem;

my $date = UnixDate('today', "%Y%m%d");

printf "Today's date is %s\n", $date;

my $err;

my $pid = open3(my $chld_in, my $chld_out, my $chld_err = gensym,
    'mmlsfileset', $filesystem);

my @stdout = <$chld_out>;
my @stderr = <$chld_err>;

waitpid($pid, 0);

my @filesets = sort { lc($a) cmp lc($b) } grep { /_active$/ } map { (split)[0] } @stdout;

#print Dumper(\@filesets);
print "Found %s filesets.\n", scalar @filesets;

#my @daily = sort { lc($a) cmp lc($b) } map { (split)[0] } grep { /^\d{8}-/ } @stdout;
#my @global = sort { $a cmp $b } map { (split)[0] } grep { /^\Q$filesystem\E\./ } @stdout;

system('mmlspool', '--block-size', 'auto', $filesystem);

print "Creating daily snapshots\n";
my $created = 0;
my $failed = 0;

foreach my $fileset (@filesets) {

    my $snap = "${date}-${fileset}";

    if ($notreally) {
        printf "Skipping %s\n", $snap;
    }
    else {

        my $expiration = UnixDate( DateCalc('now', '+ 7 days'), '%Y-%m-%d-%H:%M');

        printf "Creating %s to expire at %s\n", $snap, $expiration;

# [root@rdcw-5-12-nsd1 ~]# mmcrsnapshot
# mmcrsnapshot: Missing arguments.
# Usage:
# mmcrsnapshot Device [[Fileset]:]Snapshot[,[[Fileset]:]Snapshot]...
# [-j FilesetName[,FilesetName...]]
# [--expiration-time yyyy-mm-dd-hh:mm[:ss]]

        TRY:
        foreach my $try ( 1 .. $tries )
        {
            printf "Try #%s on %s...\n", $try, $fileset if $try > 1;

            system('mmcrsnapshot', $filesystem, sprintf("%s:%s", $fileset, $snap));
            my $rc = $? >> 8;
            printf "RC=%s\n", $rc;
            if ($rc == 0) {
                $created++;
                last TRY;
            }
            elsif ($rc == 17) {
                # Already a snapshot by that name, don't try again.
                # Not failed, but not created either.
                last TRY;
            }
            else {
                $failed++;
            }
        }
    }
}
printf "Created %s daily snapshots\n", $created;

system('mmlspool', '--block-size', 'auto', $filesystem);

printf "BUILDMSG: Created %s/%s snapshots (%s failed).\n",
    $created, scalar @filesets, $failed;

exit_with_code(1) if ! $created;  # no snapshots got deleted

exit 0;

sub exit_with_code {
    my $rc = shift;
    printf "Exiting RC=%s\n", $rc;
    exit $rc;
}

