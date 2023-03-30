#!/usr/bin/perl

use strict;
use warnings;
use v5.10;
use lib "../";
use Makefile;

our $makefile;
Makefile->new("makefile");

my $CC = "gcc";
my @CFLAGS = qw(-std=c89 -Wall -Wextra -Werror -pedantic);
my @LDFLAGS;
my @DEFINE;
my @UNDEFINE;
my @CC_ARGS;

# might be useful in another project:
# push @CFLAGS, split /\s+/, qx{pkg-config --cflags sdl2};
# push @LDFLAGS, split /\s+/, qx{pkg-config --libs sdl2};

source_files qw(
    system.c system.h
    file.c file.h
    main.c
);

my $file;
my @objects = qw(file.o system.o);

rule all => needs => ["main"];
rule test => needs => ["all"], make => sub {
    my $rule = shift;
    system("./main", $file); 1;
};

rule main => needs => ["main.c", @objects], make => \&compile_executable;

rule "file.o",   needs => [qw(file.c system.h)],   make => \&compile_object;
rule "system.o", needs => [qw(system.c system.h)], make => \&compile_object;

sub compile_executable {
    my $rule = shift;
    my @C_files = grep { /\.c$|\.o$/ } map { $_->name } $rule->needs;
    my @cmd = ($CC, @CC_ARGS, @C_files, "-o", $rule->name);
    say join " ", @cmd;
    system(@cmd) == 0;
}

sub compile_object {
    my $rule = shift;
    my @C_files = grep { /\.c$/ } map { $_->name } $rule->needs;
    my @cmd = ($CC, "-c", @CC_ARGS, @C_files, "-o", $rule->name);
    say join " ", @cmd;
    system(@cmd) == 0;
}

my $rule;
while (@ARGV) {
    $_ = shift;
    if (exists $makefile->{RULES}->{$_}) {
        $rule = $_;
        if ($rule eq "test") {
            $file = shift;
        }
    }
    elsif (/^-v$|^--?verbose$/) {
        $makefile->{verbose} = 1;
    }
    elsif (/^-D\w+$/) {
        push @DEFINE, $_;
    }
    elsif (/^-U\w+$/) {
        push @UNDEFINE, $_;
    }
    else {
        say STDERR "unrecognized argument '$_'";
        exit 1;
    }
}

$rule //= "all";
$file //= "lines.txt";
@CC_ARGS = (@CFLAGS, @LDFLAGS, @DEFINE, @UNDEFINE);

if (!$makefile->make($rule)) {
    exit 1;
}


