package Makefile;
use strict;
use warnings;
use v5.10;

our %CALLER;

sub import {
    no strict 'refs';
    shift;
    my $caller = caller;

    *{"$caller\::rule"}         = \&{"Makefile::rule::rule"};
    *{"$caller\::source_files"} = \&{"Makefile::rule::source_files"};
}

sub croak { 
    my $msg = shift;
    my ($file, $line, $func) = (caller(1))[1..3];
    say STDERR "$func: $msg at $file line $line";
    exit 1;
}

sub new {
    my $class = shift;
    no strict 'refs';
    my $makefile_name = shift
        // croak("needs package variable name for the makefile object");

    my $caller = caller;
    my $makefile = bless {
        RULES => {},
        verbose => 0,
    }, $class;
    $Makefile::CALLER{$caller} = ${"$caller\::$makefile_name"} = $makefile;
}

sub dfs_check_cycle {
    my ($rule, $stack) = @_;

    # check if cycle
    for my $need ($rule->needs) {
        if (grep { $_ eq $need->name } $stack->@*) {
            push $stack->@*, $need->name;
            return 1;
        }
    }

    # dfs + propagating positive search result + maintaining external stack
    for my $need ($rule->needs) {
        push $stack->@*, $need->name;
        if (dfs_check_cycle($need, $stack)) {
            return 1;
        }
        pop $stack->@*;
    }
    return 0;
}

sub detect_cycle {
    my ($RULES, $stack) = @_;
    for my $rule (sort values $RULES->%*) {
        if (dfs_check_cycle($rule, $stack)) {
            return 1;
        }
    }
}

sub make {
    my $makefile = shift;
    my $rule = shift // croak("no rule given");
    my $RULES = $makefile->{RULES};

    my $stack = [];
    if (detect_cycle($RULES, $stack)) {
        say STDERR "cycle detected";
        say STDERR join " -> ", $stack->@*;
        exit 1;
    }

    $RULES->{$rule}->make;
}

package Makefile::rule;
use strict;
use warnings;
use v5.10;
use Time::HiRes "stat"; # subsecond resolution

sub max { $_[0] > $_[1] ? $_[0] : $_[1]  }

sub name        { $_[0]{name} }
sub code        { $_[0]{code} }
sub satisfied   { $_[0]{satisfied}   }
sub most_recent { $_[0]{most_recent} }
sub source_file { $_[0]{source_file} }

sub date {
    my $rule = shift;
    -e $rule->name ? (stat $rule->name)[9] : 1
}

sub needs {
    my $rule = shift;
    $rule->{needs} ? (map { $rule->{RULES}{$_} } $rule->{needs}->@*) : ()
}

sub string {
    my $rule = shift;
    my $name = $rule->name;
    if ($rule->source_file) {
        "[$name]"
    }
    else {
        sprintf("%-12s <- ", "[$name]")
        . "[" . join(", ", map { $_->name } $rule->needs). "]";
    }
}

sub source_files {
    my $caller = caller;
    my $makefile = $Makefile::CALLER{$caller};
    my $RULES = $makefile->{RULES};

    for my $file (@_) {
        if (!-e $file) {
            say STDERR "source file '$file' does not exist";
            exit 1;
        }
        $RULES->{$file} = bless {
            source_file => 1,
            name        => $file,
            RULES       => $RULES,
            makefile    => $makefile,
        }, "Makefile::rule";
    }
}

sub rule {
    my $caller = caller;
    my $makefile = $Makefile::CALLER{$caller};
    my $RULES = $makefile->{RULES};

    my $rule = shift;
    $RULES->{$rule} = bless {
        @_,
        name        => $rule,
        RULES       => $RULES,
        makefile    => $makefile,
    }, "Makefile::rule";
}

sub make {
    my $rule = shift;
    my $makefile = $rule->{makefile};
    my $most_recent = 0;    # most recent dependency modification date, recursively

    if ($rule->satisfied) {
        return $rule->most_recent;
    }
    elsif ($rule->source_file) {
        $rule->{satisfied} = 1;
        $rule->{most_recent} //= $rule->date;
        return $rule->most_recent;
    }

    for my $need ($rule->needs) {
        my $res = $need->make;
        if ($res == 0) {
            say STDERR $rule->string, " ERROR: couldn't satisfy ", $need->name;
            return 0;
        }
        $most_recent = max($most_recent, $res);
    }

    if ($rule->date > $most_recent) {
        $rule->{satisfied} = 1;
        $rule->{most_recent} = $rule->date;
        say STDERR $rule->string if $makefile->{verbose};
        return $rule->most_recent;
    }

    my $code = $rule->{make} // sub { 1 };
    
    if ($code->($rule)) {
        $rule->{satisfied} = 1;
        $rule->{most_recent} = max($most_recent, $rule->date);
        say STDERR $rule->string if $makefile->{verbose};
        return $rule->most_recent;
    }
    else {
        say STDERR $rule->string, " FAILED";
        return 0;
    }
}

1;
