#!/usr/bin/env perl

use Getopt::Std;
use strict;
use warnings;

my %options = ();
my %calculations = ();

getopts("c:r:s", \%options);

my ($hasColumnProjections, @columnProjections) = parseColumnProjections($options{c});   
my ($hasRowProjections, @rowProjections) = parseRowProjections($options{r});    

my $row = 0;
while (<STDIN>) {
    $row++;
    my @columns = split(/\s+/);
    my @output = ();

    if ($hasColumnProjections) {
        my $projection;
        for $projection (@columnProjections) {
            my ($calculation, $columnIds) = @$projection;
            my $columnId;
            for $columnId (normalizeColumnId(@$columnIds[0], scalar @columns) .. normalizeColumnId(@$columnIds[1], scalar @columns)) {
                my $datum = $columns[$columnId];
                push(@output, calc($calculation, $columnId, $datum, $row));
            }
        }
    } else {
        @output = @columns;
    }

    if ($hasRowProjections) {
        last if (!@rowProjections);
        next if ($rowProjections[0] != $row);
        shift @rowProjections;
    }

    print(join("\t", @output), "\n") if @output > 0;
}

sub parseColumnProjections {
    my $specString = shift;
    return (0, ()) if !defined($specString);
    
    my @projections = ();
    my @projectionSpecifications = split(/,\s*/, $specString);
    my $projectionSpecification;

    foreach $projectionSpecification (@projectionSpecifications) {
        if ($projectionSpecification =~ /^-?\d+$/) { # e.g.: 5, -1
            push @projections, ['id', [$projectionSpecification, $projectionSpecification]];
        } elsif ($projectionSpecification =~ /^(-?\d+)\.\.(-?\d+)/) { # e.g.: 1..2, 1..-1
            push @projections, ['id', [$1, $2]];
        } elsif ($projectionSpecification =~ /(\w+)\((-?\d+)\)/) { # e.g.: sum(1), avg(2)
            push @projections, [$1, [$2, $2]];
        } else {
            usage(); exit(1);
        }
    }
    return (1, @projections);
}

sub parseRowProjections {
    my $specString = shift;
    return (0, ()) if !defined($specString);
    
    my @projections = ();
    my @projectionSpecifications = split(/,\s*/, $specString);
    my $projectionSpecification;

    foreach $projectionSpecification (@projectionSpecifications) {
        if ($projectionSpecification =~ /^\d+$/) { # e.g.: 5, 9
            push @projections, $projectionSpecification;
        } elsif ($projectionSpecification =~ /^(\d+)\.\.(\d+)/) { # e.g.: 1..2
            my $projection;
            for $projection ($1 .. $2) {
                push @projections, $projection;
            }
        } else {
            usage(); exit(1);
        }
    }
    return (1, @projections);
}

sub calc {
    my $calculation = shift;
    my $column = shift;
    my $datum = shift;
    my $i = shift;
    if ($calculation =~ /^id$/) {
        return $datum;
    } elsif ($calculation =~ /^sum$/) {
        my $oldSum = $calculations{$column}{sum}[$i-1] ||= 0;
        return $calculations{$column}{sum}[$i] ||= $oldSum + $datum;
    } elsif ($calculation =~ /^count$/) {
        my $oldCount = $calculations{$column}{count}[$i-1] ||= 0;
        return $calculations{$column}{count}[$i] ||= $oldCount + 1;
    } elsif ($calculation =~ /^avg$/) {
        my $oldAverage = $calculations{$column}{avg}[$i-1] ||= $datum;
        return $calculations{$column}{avg}[$i] ||= $oldAverage + ($datum - $oldAverage) / calc('count', $column, $datum, $i);
    } elsif ($calculation =~ /^max$/) {
        my $oldMax = $calculations{$column}{max}[$i-1] ||= $datum;
        return $calculations{$column}{max}[$i] ||= $oldMax > $datum ? $oldMax : $datum;
    } elsif ($calculation =~ /^min$/) {
        my $oldMin = $calculations{$column}{min}[$i-1] ||= $datum;
        return $calculations{$column}{min}[$i] ||= $oldMin < $datum ? $oldMin : $datum;
    } elsif ($calculation =~ /^stddev$/) {
        calc('count', $column, $datum, $i);
        calc('q', $column, $datum, $i);
        return $i == 1 ? 0 : ((calc('q', $column, $datum, $i) / (calc('count', $column, $datum, $i) - 1)) ** 0.5);
    } elsif ($calculation =~ /^q$/) {
        calc('avg', $column, $datum, $i);
        my $oldQ = $calculations{$column}{q}[$i-1] ||= 0;
        my $oldAvg = calc('avg', $column, $datum, $i-1);
        my $count = calc('count', $column, $datum, $i);
        return $calculations{$column}{q}[$i] ||= $oldQ + ($count - 1) * (($datum - $oldAvg) ** 2) / $count;
    } else {
        usage(); exit(1);
    }
}

sub normalizeColumnId {
    my $columnId = shift;
    my $columns = shift;
    return ($columnId + ($columnId < 0 ? 0 : -1)) % $columns;
}

sub usage {
    print "usage: ss [-c <column_projections>] [-r <row_projections>] [-s] [file]\n\n";
    print "\tcolumn_projections ::= column_projection [, column_projections]\n";
    print "\tcolumn_projection  ::= number..number|number\n";
    print "\tfunctions          ::= avg|med|stddev|sum|count|max|min\n";
}