#!/usr/bin/perl

use Test::More tests => 2;
use_ok("Text::Ngrams");
require 't/auxfunctions.pl';

my $ng3 = Text::Ngrams->new;
$ng3->process_text('abcdefg1235678hijklmnop');

is(getfile('t/2.out'), $ng3->to_string, 'test 2');
