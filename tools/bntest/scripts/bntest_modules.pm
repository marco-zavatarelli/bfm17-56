#!/usr/bin/perl -w

# DESCRIPTION
#   Extract and check configuration file and execute tests
#
# AUTHORS
#   Esteban Gutierrez esteban.gutierrez@cmcc.it
#
# COPYING
#  
#   Copyright (C) 2013 BFM System Team ( bfm_st@lists.cmcc.it )
#
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation;
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTEABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
# -----------------------------------------------------

package bntest_modules;

use 5.008_002;

use strict;
use warnings;
use Exporter;
use Data::Dumper;

use classes;

########### VARIABLES ##########################
our @ISA = qw(Exporter);
our @EXPORT= qw(get_configuration generate_test);
########### VARIABLES ##########################

########### FIX VALUES ##########################
my @OPTIONS= Test->get_options();
########### FIX VALUES ##########################

########### DEFAULT ##########################
my $VERBOSE = 0;
########### DEFAULT ##########################

########### FUNCTIONS ##########################
sub get_configuration{
    my ($conf_file, $verbose) = @_;
    my %user_conf;
    $VERBOSE = $verbose;

    open CONFIG, "<$conf_file" or die "Could not open configuration file for ${conf_file}: $!";
    while (<CONFIG>) {
        chomp;                  # no newline
        s/#.*//;                # no comments
        s/^\s+//;               # no leading white
        s/\s+$//;               # no trailing white
        next unless length;     # anything left?
        my ($var, $value) = split(/\s*=\s*/, $_, 2);
        my @comasep = split(/,/, "$value");
        $user_conf{$var} = \@comasep;
    }
    close(CONFIG);
    check_conf(\%user_conf);
    return fill_conf(\%user_conf);
}

sub check_conf{
    my ($user_conf) = @_;

    #if($VERBOSE){ print Dumper($user_conf) . "\n"; }
    if( ! exists $$user_conf{NAME} ){ 
        print "ERROR: Configuration file must contain \"NAME\" variable\n"; 
        exit; 
    }
    my $num_tests = scalar(@{$$user_conf{NAME}});
    foreach my $opt (@OPTIONS){
        if( exists $$user_conf{$opt} && scalar(@{$$user_conf{$opt}}) != $num_tests ){ 
            print "ERROR: \"$opt\" var must have same number of elements as \"NAME\" var ($num_tests elements)\n"; 
            exit; 
        }
    }
}

sub fill_conf{
    my($user_conf) = @_;
    my @lst_test;

    my $num_tests = $#{$$user_conf{NAME}};
    #foreach name create a test
    foreach my $test (0..$num_tests){
        my @lst_opt;
        my $name = ${$$user_conf{NAME}}[$test];
        $name =~ s/^\s+|\s+$//g; #remove leading and trailing spaces
        foreach my $opt (@OPTIONS){
            my $value = '';
            #if exists the option in configuration file, replace the empty value
            if( exists $$user_conf{$opt} ){ 
                $value = ${$$user_conf{$opt}}[$test];
                $value =~ s/^\s+|\s+$//g; #remove leading and trailing spaces
            }
            push(@lst_opt, $value);
        }
        #create test object
        push(@lst_test, new Test($name, @lst_opt ) );
    }
    if($VERBOSE){ Test->printAll(\@lst_test); }
 
    return \@lst_test;
}

sub generate_test{
    my ($bfm_exe, $temp_dir, $test) = @_;
    my $cmd = "export BFMDIR_RUN=$temp_dir; ";
    $cmd   .= "cd ${ENV{'BFMDIR'}}/build; ";
    $cmd   .= "$bfm_exe -gcd ";
    $cmd   .= $test->generate_opt();
    if($VERBOSE){ print "\tCommand: $cmd\n"; }
    my $out=`$cmd`;
    #check for errors and warnings in generation and compilation time
    if($VERBOSE){
        my @out_warning = $out =~ m/WARNING(?::| )(.*)/ig;
        if(@out_warning){ print "\tWARNING in ". $test->getName() . ":\n\t\t-" . join("\n\t\t-",@out_warning) . "\n"; }
    }
    my @out_error   = $out =~ m/ERROR(?::| )(.*)/ig;
    if(@out_error)  { print "\tERROR in "  . $test->getName() . ":\n\t\t-" . join("\n\t\t-",@out_error)   . "\n"; return 0; }
    my ($out_exit)  = $out =~ m/EXITING\.\.\./ig;
    if($out_exit)   { print "\tERROR in "  . $test->getName() . ": Compiler not exists\n"; return 0; }
    return 1;
}

1;
