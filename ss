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

    if ($hasRowProjections) {
        last if (!@rowProjections);
        next if ($rowProjections[0] != $row);
        shift @rowProjections;
    }

    if ($hasColumnProjections) {
        my $projection;
        for $projection (@columnProjections) {
            my ($calculation, $columnIds) = @$projection;
            my $columnId;
            for $columnId (normalizeColumnId(@$columnIds[0], scalar @columns) .. normalizeColumnId(@$columnIds[1], scalar @columns)) {
                my $datum = $columns[$columnId];
                push(@output, calc($calculation, $columnId, $datum));
            }
        }
    } else {
        @output = @columns;
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
            usage();
            exit(1);
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
            usage();
            exit(1);
        }
    }
    return (1, @projections);
}

sub calc {
    my $calculation = shift;
    my $column = shift;
    my $datum = shift;
    if ($calculation =~ /^id$/) {
        return $datum;
    } elsif ($calculation =~ /^sum$/) {
        $calculations{$column}{sum} ||= 0;
        return $calculations{$column}{sum} += $datum;
    } elsif ($calculation =~ /^count$/) {
        $calculations{$column}{count} ||= 0;
        return ++$calculations{$column}{count};
    } elsif ($calculation =~ /^avg$/) {
        calc('sum', $column, $datum);
        calc('count', $column, $datum);
        return $calculations{$column}{sum} / $calculations{$column}{count};
    } elsif ($calculation =~ /^max$/) {
        $calculations{$column}{max} ||= $datum;
        return $calculations{$column}{max} = $calculations{$column}{max} > $datum ? $calculations{$column}{max} : $datum;
    } elsif ($calculation =~ /^min$/) {
        $calculations{$column}{min} ||= $datum;
        return $calculations{$column}{min} = $calculations{$column}{min} < $datum ? $calculations{$column}{min} : $datum;
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
}