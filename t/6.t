#!/usr/bin/perl

use Test::More tests => 1;
require 't/auxfunctions.pl';

my $out = `perl -Mblib ./ngrams.pl --n=2 --type=word t/5.in`;

is(getfile('t/3.out'), $out);
