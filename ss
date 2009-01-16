#!/usr/bin/env perl

use Getopt::Std;
use strict;
use warnings;

my %options = (
	c => '',
);

getopts("c:r:", \%options);

my ($hasColumnProjections, @columnProjections) = parseProjections($options{c});	
my ($hasRowProjections, @rowProjections) = parseProjections($options{r});	

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
		foreach $projection (@columnProjections) {
			push(@output, $columns[$projection - 1]);
		}
	} else {
		@output = @columns;
	}
	print(join("\t", @output), "\n");
}

sub parseProjections {
	my $specString = shift;
	return (0, ()) if !defined($specString);
	
	my @projections = ();
	
	my @projectionSpecifications = split(/,\s*/, $specString);
	my $projectionSpecification;

	foreach $projectionSpecification (@projectionSpecifications) {
		if ($projectionSpecification =~ /^\d+$/) {
			push @projections, $projectionSpecification;
		} elsif ($projectionSpecification =~ /^(\d+)\.\.(\d+)/) {
			my $projection;
			foreach $projection ($1 .. $2) {
				push @projections, $projection;
			}
		}
	}
	return (1, @projections);
}