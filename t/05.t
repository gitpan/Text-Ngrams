#!/usr/bin/perl
# $Id: 05.t,v 1.2 2005/12/15 15:42:23 vlado Exp $

use Test::More tests => 4;
use_ok("Text::Ngrams");
require 't/auxfunctions.pl';

my $ng = Text::Ngrams->new(windowsize=>2, type=>'word');
$ng->process_files('t/05.in');
isn('t/03.out', $ng->to_string('orderby'=>'ngram'));

$ng = Text::Ngrams->new();
$ng->process_files('t/05-0.in');
my $o = $ng->to_string( 'orderby' => 'ngram' );
#putfile('t/05-0.out', $o);
isn('t/05-0.out', $o);

$ng = Text::Ngrams->new(type=>'byte');
$ng->process_files('t/05-1.in');
my $o = $ng->to_string( 'orderby' => 'ngram');
#putfile('t/05-1.out', $o);
isn('t/05-1.out', $o);
