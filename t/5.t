#!/usr/bin/perl

use Test::More tests => 2;
use_ok("Text::Ngrams");
require 't/auxfunctions.pl';

my $ng = Text::Ngrams->new(windowsize=>2, type=>word);
$ng->process_files('t/5.in');

is(getfile('t/3.out'), $ng->to_string);
