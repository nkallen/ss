#!/usr/bin/env perl

use Getopt::Std;
use strict;
use warnings;

my %options = ();
my %calculations = ();

getopts("c:r:s", \%options);

my ($hasColumnProjections, @columnProjections) = parseProjections($options{c});	
my ($hasRowProjections, @rowProjections) = parseProjections($options{r});	

my $row = 0;
while (<STDIN>) {
	$row++;
	my @columns = split(/\s+/);
	my @output = ();

	if ($hasRowProjections) {
		last if (!@rowProjections);
		next if ($rowProjections[0][1] != $row);
		shift @rowProjections;
	}
	
	if ($hasColumnProjections) {
		my $projection;
		for $projection (@columnProjections) {
			my ($calculation, $columns) = @$projection;
			my $column;
			for $column (@$columns) {
				print $column, "\n";
				my $normalizedColumn = $column % @columns + ($column < 0 ? 0 : -1);
				my $datum = $columns[$normalizedColumn];
				push(@output, calc($calculation, $normalizedColumn, $datum));
			}
		}
	} else {
		@output = @columns;
	}
	# print(join("\t", @output), "\n");
}

sub parseProjections {
	my $specString = shift;
	return (0, ()) if !defined($specString);
	
	my @projections = ();
	my @projectionSpecifications = split(/,\s*/, $specString);
	my $projectionSpecification;

	foreach $projectionSpecification (@projectionSpecifications) {
		if ($projectionSpecification =~ /^-?\d+$/) { # e.g.: 5, -1
			push @projections, ['id', [$projectionSpecification, $projectionSpecification]];
		} elsif ($projectionSpecification =~ /^(-?\d+)\.\.(-?\d+)/) { # e.g.: 1..2
			push @projections, ['id', [$1, $2]];
		} elsif ($projectionSpecification =~ /(\w+)\((-?\d+)\)/) { # e.g.: sum(1), avg(2)
			push @projections, [$1, [$2, $2]];
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