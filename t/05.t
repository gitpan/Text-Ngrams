#!/usr/bin/perl
# $Id: 05.t,v 1.1 2003/12/18 17:25:23 vlado Exp $

use Test::More tests => 2;
use_ok("Text::Ngrams");
require 't/auxfunctions.pl';

my $ng = Text::Ngrams->new(windowsize=>2, type=>'word');
$ng->process_files('t/05.in');

is(normalize(scalar(getfile('t/03.out'))),
   normalize($ng->to_string('orderby'=>'ngram')));
