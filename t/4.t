#!/usr/bin/perl

use Test::More tests => 2;
use_ok("Text::Ngrams");
require 't/auxfunctions.pl';

my $ng = Text::Ngrams->new(type=>'byte');
$ng->process_text(
'	The brown quick fox,
	brown fox,
	      brown fox ...
');

is(getfile('t/4.out'), $ng->to_string);
