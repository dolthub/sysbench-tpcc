#!/usr/bin/perl

use strict;
use warnings;

use Cwd qw(cwd getcwd);

my @customers = (100, 200, 400, 800, 1600, 3000);
my @items = (100, 200, 400, 800, 1600, 3200);
my @orders = (100, 200, 400, 800, 1600, 3200);
my @stock = (1000, 2000, 4000, 8000, 16000, 32000);

my $bench_dir = '/c/Users/zachmu/dolt-scratch/benchmarks';

my $script_dir = cwd();

my $cmd = $ARGV[0] || "run";

for (my $i = 0; $i < scalar @customers; $i++) {
    chdir($script_dir);
    my $db_name = "sbtest_$i";

    if (my $child = fork()) {
        $SIG{INT} = sub { kill(9, -$child); die "Benchmark killed by interrupt"; };
        
        sleep 5; # wait for server to be ready
        
        my $threads = 1;
        if ($cmd eq 'run') {
            $threads = 10;
        }
        
        my $tpcc = "./tpcc.lua $cmd --mysql-host=127.0.0.1 --mysql-user=root --mysql-password=\"\" --mysql-db=$db_name --tables=1 --scale=9 --threads=$threads --customers=$customers[$i] --items=$items[$i] --orders=$orders[$i] --stock=$stock[$i]";
        print "$tpcc\n";
        system($tpcc); # Don't die here, we need to kill the server below

        kill(9, -$child);

        chdir("$bench_dir/$db_name");

        if ($cmd eq 'prepare') {
            system("dolt commit -am 'Loaded with $tpcc'") and die $!;
        }
    } else {
        setpgrp(0, 0);
        
        chdir($bench_dir);
        if (! -d $db_name) {
            system("mkdir $db_name") and die $!;
        }
        chdir($db_name);

        if ($cmd eq 'prepare') {
            system("dolt init") and die $!;
        } else {
            system("dolt reset --hard") and die $!;
        }
        
        my $server_command = "dolt sql-server";
        system("$server_command");
        exit 0; # should never get here, but to avoid a fork bomb
    }    
}
