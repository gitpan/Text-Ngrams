# (c) 2003 Vlado Keselj www.cs.dal.ca/~vlado
#
# $Id: Ngrams.pm,v 1.7 2003/06/07 03:16:02 vlado Exp $

package Text::Ngrams;

use strict;
require Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS); # Exporter vars
our @ISA = qw(Exporter);

our %EXPORT_TAGS = ( 'all' => [ qw(new encode_S decode_S) ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw(new);
our $VERSION = '0.03';

use vars qw($Version $Revision);
$Version = $VERSION;
($Revision = substr(q$Revision: 1.7 $, 10)) =~ s/\s+$//;

use vars @EXPORT_OK;

# non-exported package globals go here
use vars qw();

sub new {
  my $package = shift;
  $package = ref($package) || $package;
  my $self = {};

  my (%params) = @_;

  $self->{windowsize} = exists($params{windowsize}) ?
      $params{windowsize} : 3;

  die "nonpositive window size: $self->{windowsize}" unless $self->{windowsize} > 0;

  if (! exists($params{type}) or $params{type} eq 'character') {
      $self->{tokenseparator} = '';
      $self->{skiprex} = '';
      $self->{tokenrex} = qr/([a-zA-Z]|[^a-zA-Z]+)/;
      $self->{processtoken} =  sub { s/[^a-zA-Z]+/ /; $_ = uc $_ }
  }
  elsif ($params{type} eq 'byte') {
      $self->{tokenseparator} = '';
      $self->{skiprex} = '';
      $self->{tokenrex} = '';
      $self->{processtoken} = '';
  }
  elsif ($params{type} eq 'word') {
      $self->{tokenseparator} = ' ';
      $self->{skiprex} = qr/[^a-zA-Z0-9]+/;
      $self->{tokenrex} = qr/([a-zA-Z]+|(\d+(\.\d+)?|\d*\.\d+)([eE][-+]?\d+)?)/;
      $self->{processtoken} = sub { s/(\d+(\.\d+)?|\d*\.\d+)([eE][-+]?\d+)?/<NUMBER>/ }
  }
  else { die "unknown type $params{type}" }

  $self->{table} = [ ];
  $self->{total} = [ ];
  $self->{lastngram} = [ ];

  foreach my $i ( 1 .. $self->{windowsize} ) {
      $self->{table}[$i] = { };
      $self->{total}[$i] = 0;
      $self->{lastngram}[$i] = '';
  }

  bless($self, $package);
  return $self;
}

sub feed_tokens {
    my $self = shift;
    # count all n-grams sizes starting from max to 1
    foreach my $t (@_) {
	for (my $n=$self->{windowsize}; $n > 0; $n--) {
	    if ($n > 1) {
		next unless $self->{lastngram}[$n-1];
		$self->{lastngram}[$n] = $self->{lastngram}[$n-1] .
		    $self->{tokenseparator} . $t;
	    } else { $self->{lastngram}[$n] = $t }
	    $self->{table}[$n]{$self->{lastngram}[$n]} += 1;
	    $self->{total}[$n] += 1;
	}
    }
}

sub process_text {
    my $self = shift;
    my (@tokens);
    while (@_) {
	my $text = shift @_;
	while (length($text) > 0) {
	    if ($self->{skiprex} ne '') { $text =~ s/^$self->{skiprex}// }
	    last if length($text) == 0;
	    local $_;
	    if ($self->{tokenrex} ne '') {
		$text =~ /^$self->{tokenrex}/ or die;
		$_ = $&; $text = $'; die unless length($_) > 0;
	    }
	    else
	    { $_ = substr($text, 0, 1); $text = substr($text, 1) }
	    if (ref($self->{processtoken}) eq 'CODE')
	    { &{$self->{processtoken}} }
	    push @tokens, $_;
	}
    }
    $self->feed_tokens(@tokens);
}

sub process_files {
    my $self = shift;
    foreach my $f (@_) {
	my $f1;
	if (not ref($f))
	{ open($f1, "$f") or die "cannot open $f:$!" }
	else { $f1 = $f }

	while (<$f1>) { $self->process_text($_) }

	close($f1);
    }
}

sub to_string {
    my $self = shift;
    my (%params) = @_;
    my $ret = "BEGIN OUTPUT BY Text::Ngrams version $VERSION\n\n";

    foreach my $n (1 .. $self->{windowsize}) {
	{ my $tmp = "$n-GRAMS (total count: $self->{total}[$n])";
	  $ret .= "$tmp\n" . ('-' x length($tmp)) . "\n";
        }

	my @keys;
	if (!exists($params{'orderby'}))
	{ @keys = sort(keys(%{$self->{table}[$n]})) }
	elsif ($params{'orderby'} eq 'frequency') {
	    @keys = sort { $self->{table}[$n]{$b} <=>
			   $self->{table}[$n]{$a} }
	            keys(%{$self->{table}[$n]});
	}
	else { @keys = sort(keys(%{$self->{table}[$n]})) }
	
	foreach my $ngram (@keys) {
	    $ret .= &encode_S($ngram) . "\t"
		. $self->{table}[$n]{$ngram} . "\n";
	}

	$ret .= "\n";
    }

    return $ret . "END OUTPUT BY Text::Ngrams\n";
}

# http://www.cs.dal.ca/~vlado/srcperl/snip/decode_S
sub decode_S ( $ ) {
    local $_ = shift;
    my $out;

    while (length($_) > 0) {
        if (/^\\(\S)/) {
            $_ = $'; my $tmp = $1;
            $tmp =~ tr/0-5Aabtnvfroil6-9NSTcEseFGRUd/\x00-\x1F\x7F/;
            $out .= $tmp;
        }
        elsif (/^\^_/) { $_ = $'; $out .= "\240" }
        elsif (/^\^(\S)/) { $_ = $'; $out .= pack('c',ord($1)+128); }
        elsif (/^\`(\S)/) {
            $_ = $'; my $tmp = $1;
            $tmp =~ tr/0-5Aabtnvfroil6-9NSTcEseFGRUd/\x00-\x1F\x7F/;
            $out .= pack('c', ord($tmp)+128);
        }
        elsif (/^_+/) { $_ = $'; my $tmp = $&; $tmp =~ tr/_/ /; $out .= $tmp; }
        elsif (/^[^\\^\`\s_]+/) { $_ = $'; $out .= $&; }
        else { die "decode_S unexpected:$_" }
    }

    return $out;
}

# http://www.cs.dal.ca/~vlado/srcperl/snip/encode_S
sub encode_S( $ ) {
    local $_ = shift;

    s/=/=0/g;    # first hide a special character (=)
    s/\\/=b/g;			# encode backslashes

    s/([\x80-\xFF])/=x$1/g; # replace >127 with 127
    tr/\x80-\xFF/\x00-\x7F/;
    s/=x=/=X/g;			# hide again =

    s/([\x00-\x1F\x5C\x5E-\x60\x7F])/=B$1/g;
    tr/\x20\x00-\x1F\x7F/_0-5Aabtnvfroil6-9NSTcEseFGRUd/;

    s/=x=B(\S)/`$1/g;		# hex backslash
    s/=x(\S)/^$1/g;		# hex other
    s/=B(\S)/\\$1/g;		# backslashed
    s/=b/\\\\/g;		# original backslashes
    s/=X/^=0/g;
    s/=0/=/g;			# put back =

    return $_;
}

1;
__END__

=head1 NAME

Text::Ngrams - Flexible Ngram analysis (for characters, words, and more)

=head1 SYNOPSIS

For default character n-gram analysis of string:

  use Text::Ngrams;
  my $ng3 = Text::Ngrams->new;
  ng3->process_text('abcdefg1235678hijklmnop');
  print ng3->to_string;

One can also feed tokens manually:

  use Text::Ngrams;
  my $ng3 = Text::Ngrams->new;
  $ng3->feed_tokens('a');
  $ng3->feed_tokens('b');
  $ng3->feed_tokens('c');
  $ng3->feed_tokens('d');
  $ng3->feed_tokens('e');
  $ng3->feed_tokens('f');
  $ng3->feed_tokens('g');
  $ng3->feed_tokens('h');

We can choose n-grams of various sizes, e.g.:

  my $ng = Text::Ngrams->new( windowsize => 6 );

or different types of n-grams, e.g.:

  my $ng = Text::Ngrams->new( type => byte );
  my $ng = Text::Ngrams->new( type => word );


=head1 DESCRIPTION

This module implement text n-gram analysis, supporting several types of
analysis, including character and word n-grams.

The module Text::Ngrams is very flexible.  For example, it allows a user
to manually feed a sequence of any tokens.  It handles several types of tokens
(character, word), and also allows a lot of flexibility in automatic
recognition and feed of tokens and the way they are combined in an n-gram.
It counts all n-gram frequencies up to the maximal specified length.
The output format is meant to be pretty much human-readable, while also
loadable by the module.

The module can be used from the command line through the script
L<ngrams.pl> provided with the package.

=head1 OUTPUT FORMAT

The output looks like this:

  BEGIN OUTPUT BY Text::Ngrams version 0.01

  1-GRAMS (total count: 8)
  ------------------------
  a	1
  b	1
  c	1
  d	1
  e	1
  f	1
  g	1
  h	1

  2-GRAMS (total count: 7)
  ------------------------
  ab	1
  bc	1
  cd	1
  de	1
  ef	1
  fg	1
  gh	1

  3-GRAMS (total count: 6)
  ------------------------
  abc	1
  bcd	1
  cde	1
  def	1
  efg	1
  fgh	1

  END OUTPUT BY Text::Ngrams

N-grams are encoded using encode_S
(F<www.cs.dal.ca/~vlado/srcperl/snip/encode_S>), so that they can
always be recognized as \S+.  This encoding does not change strings
"too much", e.g., letters, digits, and most punctuation characters
will remail unchanged, and space is replaced by underscore (_).
However, all bytes (even with code greater than 127) are encoded in
unambiguous and relatively compact way.  Two functions, encode_S and
decode_S, are provided for translating arbitrary string into this form
and vice versa.

An example of word n-grams containing space:

  BEGIN OUTPUT BY Text::Ngrams version 0.01

  1-GRAMS (total count: 8)
  ------------------------
  The	1
  brown	3
  fox	3
  quick	1

  2-GRAMS (total count: 7)
  ------------------------
  The_brown	1
  brown_fox	2
  brown_quick	1
  fox_brown	2
  quick_fox	1

  END OUTPUT BY Text::Ngrams

Or, in case of byte type of processing:

  BEGIN OUTPUT BY Text::Ngrams version 0.01

  1-GRAMS (total count: 55)
  -------------------------
  \t	3
  \n	3
  _	12
  ,	2
  .	3
  T	1
  b	3
  c	1
  ... etc

  2-GRAMS (total count: 54)
  -------------------------
  \t_	1
  \tT	1
  \tb	1
  \n\t	2
  __	5
  _.	1
  _b	2
  _f	3
  _q	1
  ,\n	2
  .\n	1
  ..	2
  Th	1
  br	3
  ck	1
  e_	1
  ... etc

  END OUTPUT BY Text::Ngrams

=head1 METHODS

=head2 new ( windowsize => POS_INTEGER, type => character|byte|word )

  my $ng = Text::Ngrams->new;
  my $ng = Text::Ngrams->new( windowsize=>10 );
  my $ng = Text::Ngrams->new( type=>'word' );
  and similar.

Creates a new C<Text::Ngrams> object and returns it.
Parameters:

=over 4

=item windowsize

n-gram size (i.e., `n' itself).  Default is 3
if not given.  It is stored in $object->{windowsize}.

=item type

Specifies a predefined type of n-grams:

=over 4

=item character (default)

Default character n-grams:
Read letters, sequences of all other characters are replaced
by a space, letters are turned uppercase.

=item byte

Raw character n-grams:
Don't ignore any bytes and don't pre-process them.

=item word

Default word n-grams:
One token is a word consisting of letters, digits and decimal digit
are replaced by <NUMBER>, and everything else is ignored.  A space is inserted
when n-grams are formed.       

=back

One can also modify type, creating its own type, by fine-tuning several parameters
(they can be undefined):

$o->{tokenseparator} - string used to be inserted between tokens in n-gram
(for characters it is empty, and for words it is a space).

$o->{skiprex} - regular expression for ignoring stuff between tokens.

$o->{tokenrex} - regular expression for recognizing a token.  If it is
empty, it means chopping off one character.

$o->{processtoken} - routine for token preprocessing.  Token is given and returned in $_.

For example, the types character, byte, and word are defined in the
foolowing way:

  if ($params{type} eq 'character') {
      $self->{tokenseparator} = '';
      $self->{skiprex} = '';
      $self->{tokenrex} = qr/([a-zA-Z]|[^a-zA-Z]+)/;
      $self->{processtoken} =  sub { s/[^a-zA-Z]+/ /; $_ = uc $_ }
  }
  elsif ($params{type} eq 'byte') {
      $self->{tokenseparator} = '';
      $self->{skiprex} = '';
      $self->{tokenrex} = '';
      $self->{processtoken} = '';
  }
  elsif ($params{type} eq 'word') {
      $self->{tokenseparator} = ' ';
      $self->{skiprex} = qr/[^a-zA-Z0-9]+/;
      $self->{tokenrex} = qr/([a-zA-Z]+|(\d+(\.\d+)?|\d*\.\d+)([eE][-+]?\d+)?)/;
      $self->{processtoken} = sub { s/(\d+(\.\d+)?|\d*\.\d+)([eE][-+]?\d+)?/<NUMBER>/ }
  }

=back

=head2 feed_tokens ( list of tokens )

  $ng3->feed_tokens('a');

This function manually supplies tokens.

=head2 process_text ( list of strings )

  $ng3->process_text('abcdefg1235678hijklmnop');
  $ng->process_text('The brown quick fox, brown fox, brown fox ...');

Process text, i.e., break each string into tokens and feed them.

=head2 process_files ( file_names or file_handle_references)

  $ng->process_files('somefile.txt');

Process files, similarly to text.
The files are processed line by line, so there should not be any
multi-line tokens.

=head2 to_string ( orderby => 'frequency' )

  print $ng3->to_string;
  print $ng->to_string( orderby=>'frequency' );

Produce string representation of the n-gram tables.
If parameter 'orderyby=>frequency' is specified, each table is ordered
by decreasing frequency.

=head2 encode_S ( string )

  $e = Text::Ngrams::encode_S( $s );

or simply

  $e = encode_S($s);

if encode_S is imported.  Encodes arbitrary string into an \S* form.
See F<http://www.cs.dal.ca/~vlado/srcperl/snip/encode_S> for detailed
explanation.

=head2 decode_S ( string )

  $e = Text::Ngrams::decode_S( $s );

or simply

  $e = decode_S($s);

if decode_S is imported.  Decodes a string encoded in the \S* form.
See F<http://www.cs.dal.ca/~vlado/srcperl/snip/encode_S> for detailed
explanation.


=head1 HISTORY AND RELATED WORK

This code originated in my "monkeys and rhinos" project in 2000, and
is related to authorship attribution project.  Some of the similar
projects are (URLs can be found at my site):

=over 4

=item Ngram Statistics Package in Perl, by T. Pedersen at al. 

This is a package that includes a script for word n-grams.

=item Text::Ngram Perl Package by Simon Cozens

This is a package similar to Text::Ngrams for character n-grams.
As an XS implementation it is supposed to be very efficient.

=item Perl script ngram.pl by Jarkko Hietaniemi

This is a script for analyzing character n-grams.

=item Waterloo Statistical N-Gram Language Modeling Toolkit, in C++ by Fuchun Peng 

A n-gram language modeling package written in C++.

=back

=head1 LIMITATIONS

If a user customizes a type, it is possible that a resulting n-gram will be ambiguous.
In this way, to different n-grams may be counted as one.  With predefined types of n-grams,
this should not happen.

For example, if a user chooses that a token can contain a space, and uses space as an n-gram
separator, then a trigram like this "x x x x" is ambiguous.

Method process_file does not handle multi-line tokens by default.
There are various ways around this.  Probably the best one is to read
text as much text as we want and then to use process_text, which does
handle multi-line tokens.  Otherwise, it does not seem to be worth
changing the code.

=head1 AUTHOR

Copyright 2003 Vlado Keselj www.cs.dal.ca/~vlado

This module is provided "as is" without expressed or implied warranty.
This is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

The latest version can be found at F<http://www.cs.dal.ca/~vlado/srcperl/>.

=head1 SEE ALSO

Ngram Statistics Package in Perl, by T. Pedersen at al.,
Waterloo Statistical N-Gram Language Modeling Toolkit in C++ by Fuchun Peng,
Perl script ngram.pl by Jarkko Hietaniemi,
Simon Cozen's Text::Ngram module in CPAN.

The links should be available at F<http://www.cs.dal.ca/~vlado/nlp>.

=cut
