#!/usr/bin/perl
# $Id: 5.t,v 1.3 2003/06/09 10:44:48 vlado Exp $

use Test::More tests => 2;
use_ok("Text::Ngrams");
require 't/auxfunctions.pl';

my $ng = Text::Ngrams->new(windowsize=>2, type=>'word');
$ng->process_files('t/5.in');

is(normalize(scalar(getfile('t/3.out'))),
   normalize($ng->to_string));
