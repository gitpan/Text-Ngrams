#!/usr/bin/perl

use Test::More tests => 2;
use_ok("Text::Ngrams");
require 't/auxfunctions.pl';

my $ng = Text::Ngrams->new(windowsize=>2, type=>'word', limit=>4);
$ng->process_files('t/08.in');

putfile('t/tmp-08.out', $ng->to_string( orderby=>'frequency' ));

my $producedout = normalize($ng->to_string( orderby=>'frequency' ));
my $oldout      = normalize(scalar(getfile('t/08.out')));

# ordering may vary, so let us normalize it further
$producedout = &normalize1( $producedout );
$oldout      = &normalize1( $oldout );

is($producedout, $oldout);

sub normalize1 {
    my $s = shift;
    my $r;

    while ($s) {
	if ($s =~ /\n---+\n/) {
	    $r .= "$`$&";
	    $s = $';
	} else { return "$r$s" }

	while ($s =~ /^\S+\t(\d+)\n/) {
	    my $n = $1;
	    my @a;
	    while ($s =~ /^\S+\t$n\n/)
	    { push @a, $&; $s = $'; }
	    $r .= join('',sort(@a));
	}
    }
    return $r;
}
