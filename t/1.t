#!/usr/bin/perl

use Test::More tests => 2;
use_ok("Text::Ngrams");
require 't/auxfunctions.pl';

my $ng3 = Text::Ngrams->new;
$ng3->feed_tokens('a');
$ng3->feed_tokens('b');
$ng3->feed_tokens('c');
$ng3->feed_tokens('d');
$ng3->feed_tokens('e');
$ng3->feed_tokens('f');
$ng3->feed_tokens('g');
$ng3->feed_tokens('h');

is(getfile('t/1.out'), $ng3->to_string, 'test 1');
