#!/usr/bin/perl

use Test::More tests => 4;
BEGIN { use_ok("Text::Ngrams", qw(encode_S decode_S)) }
require 't/auxfunctions.pl';

my $ng3 = Text::Ngrams->new;
$ng3->process_text('abcdefg1235678hijklmnop');

is(normalize(scalar(getfile('t/2.out'))),
   normalize($ng3->to_string));

is(encode_S("abc\n\t\xF6lado"),
   'abc\\n\\t^vlado');

is(decode_S('abc\\n\\t^vlado'),
   "abc\n\t\xF6lado");
