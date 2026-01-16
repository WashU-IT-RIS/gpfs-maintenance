#!/usr/bin/env perl

use Data::Dumper;
use Date::Manip;
use Getopt::Long;
use IPC::Open3;
use Symbol 'gensym';

# parse command-line options
my $filesystem;
my $verbose;
GetOptions (
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

print Dumper(\@stdout);

