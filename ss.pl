#!/usr/bin/env perl

use strict;
use warnings;

while (<>) {
	my @columns = split(/\s+/);
	print @columns;
}
