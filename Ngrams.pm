# (c) 2003-2004 Vlado Keselj www.cs.dal.ca/~vlado

package Text::Ngrams;

use strict;
require Exporter;
use Carp;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
@ISA = qw(Exporter);
%EXPORT_TAGS = ( 'all' => [ qw(new encode_S decode_S) ] );
@EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
@EXPORT = qw(new);
$VERSION = '1.7';

use vars qw($Version $Revision);
$Version = $VERSION;
($Revision = substr(q$Revision: 1.33 $, 10)) =~ s/\s+$//;

use vars @EXPORT_OK;
use vars qw();			# non-exported package globals go here

sub new {
  my $package = shift;
  $package = ref($package) || $package;
  my $self = {};

  my (%params) = @_;

  $self->{windowsize} = exists($params{windowsize}) ?
      $params{windowsize} : 3;
  die "nonpositive window size: $self->{windowsize}" unless $self->{windowsize} > 0;
  delete($params{windowsize});

  if (! exists($params{type}) or $params{type} eq 'character') {
      $self->{tokenseparator} = '';
      $self->{skiprex} = '';
      $self->{tokenrex} = qr/([a-zA-Z]|[^a-zA-Z]+)/;
      $self->{processtoken} =  sub { s/[^a-zA-Z]+/ /; $_ = uc $_ };
      $self->{allow_iproc} = 1;
  }
  elsif ($params{type} eq 'utf8') {
      $self->{tokenseparator} = '';
      $self->{skiprex} = '';
      $self->{tokenrex} = qr/([\xF0-\xF4][\x80-\xBF][\x80-\xBF][\x80-\xBF]
                             |[\xE0-\xEF][\x80-\xBF][\x80-\xBF]
                             |[\xC2-\xDF][\x80-\xBF]
                             |[\x00-\xFF])/x;
      $self->{processtoken} = '';
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
      $self->{skipinsert} = ' ';
      $self->{tokenrex} = qr/([a-zA-Z]+|(\d+(\.\d+)?|\d*\.\d+)([eE][-+]?\d+)?)/;
      $self->{processtoken} = sub { s/(\d+(\.\d+)?|\d*\.\d+)([eE][-+]?\d+)?/<NUMBER>/ }
  }
  else { die "unknown type: $params{type}" }
  delete($params{type});

  $self->{'table'} = [ ];
  $self->{'total'} = [ ];
  $self->{'total_distinct_count'} = 0;
  $self->{'lastngram'} = [ ];

  foreach my $i ( 1 .. $self->{windowsize} ) {
      $self->{table}[$i] = { };
      $self->{total}[$i] = 0;
      $self->{firstngram}[$i] = '';
      $self->{lastngram}[$i] = '';
  }

  if (exists($params{'limit'})) {
      die "limit=$params{'limit'}" if $params{'limit'} < 1;
      $self->{'limit'} = $params{'limit'};
  }
  delete($params{'limit'});

  die "unknown parameters:".join(' ', %params) if %params;

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

	    if ( ($self->{table}[$n]{$self->{lastngram}[$n]} += 1)==1)
	    { $self->{'total_distinct_count'} += 1 }

	    $self->{'total'}[$n] += 1;
	    if ($self->{'firstngram'}[$n] eq '')
	    { $self->{'firstngram'}[$n] = $self->{lastngram}[$n] }
	}
    }
    if (exists($self->{'limit'}) and
	$self->{'total_distinct_count'} > 2 * $self->{'limit'})
    { $self->_reduce_to_limit }
}

sub process_text {
    my $self = shift;
    $self->_process_text(0, @_);
    if (exists($self->{'limit'})) { $self->_reduce_to_limit }
}    

sub _process_text {
    my $self = shift;
    my $cont = shift; # the minimal number of chars left for
                      # continuation (the new-line problem, and the
                      # problem with too long lines)
                      # The remainder of unprocessed string is
                      # returned.
    if ($cont < 0) { $cont = 0 }
    my (@tokens);
    my $text;
    while (@_) {
	$text .= shift @_;
	while (length($text) > 0) {
	    my $textl = $text;
	    my $skip = '';
	    if ($self->{skiprex} ne '' && $textl =~ /^$self->{skiprex}/)
	    { $skip = $&; $textl = $'; }
	    if (defined($self->{skipinsert})) {
		$skip = $self->{skipinsert};
		$text = $skip.$textl;
	    }
	    if (length($textl) < $cont) { last }
	    if (length($textl)==0) { $text=$textl; last; }

	    local $_;
	    if ($self->{tokenrex} ne '') {
		if ($textl =~ /^$self->{tokenrex}/)
		{ $_ = $&; $textl = $'; }
	    }
	    else
	    { $_ = substr($textl, 0, 1); $textl = substr($textl, 1) }
	    last if $_ eq '';

	    if (length($textl) < $cont) {
		if (defined($self->{allow_iproc}) && $self->{allow_iproc}
		    && ref($self->{processtoken}) eq 'CODE')
		{ &{$self->{processtoken}} }
		$text = $skip.$_.$textl;
		last;
	    }
	    if (ref($self->{processtoken}) eq 'CODE')
	    { &{$self->{processtoken}} }
	    push @tokens, $_;
	    $text = $textl;
	}
    }
    $self->feed_tokens(@tokens);
    return $text;
}

sub process_files {
    my $self = shift;
    foreach my $f (@_) {
	my $f1;
	if (not ref($f))
	{ open($f1, "$f") or die "cannot open $f:$!" }
	else { $f1 = $f }

	my ($text, $text_l) = ('', 0);
	while (1) {
	    $text_l = length($text);
	    read($f1, $text, 1024, length($text));
	    #$text.= <$f1>;
	    last if length($text) <= $text_l;
	    $text = $self->_process_text(1, $text);
	}
	$text = $self->_process_text(0, $text);

	close($f1) if not ref($f);
	if (exists($self->{'limit'})) { $self->_reduce_to_limit }
    }
}

sub _reduce_to_limit {
    my $self = shift;
    return unless exists($self->{'limit'}) and
	$self->{'limit'} > 0;

    while ($self->{'total_distinct_count'} > $self->{'limit'}) {
	my $nextprunefrequency = 0;
	for (my $prunefrequency=1;; $prunefrequency = $nextprunefrequency) {
	    $nextprunefrequency = $self->{'total'}[1];

	    foreach my $n (1 .. $self->{'windowsize'}) {

		my @keys = keys(%{$self->{table}[$n]});
		foreach my $ngram (@keys) {
		    my $f = $self->{table}[$n]{$ngram};
		    if ($f <= $prunefrequency) {
			delete $self->{'table'}[$n]{$ngram};
			$self->{'total'}[$n] -= $prunefrequency;
			$self->{'total_distinct_count'} -= 1;
		    }
		    elsif ($nextprunefrequency > $f)
		    { $nextprunefrequency = $f }
		}

		return if $self->{'total_distinct_count'} <= $self->{'limit'};
		die if $nextprunefrequency <= $prunefrequency;
}   }   }   }

sub to_string {
    my $self = shift;
    my (%params) = @_;
   
    my $onlyfirst = exists($params{'onlyfirst'}) ?
	$params{'onlyfirst'} : '';
    delete $params{'onlyfirst'};

    my $out =  exists($params{'out'}) ? $params{'out'} : '';
    delete $params{'out'};
    my $outh = $out;
    if ($out and (not ref($out))) 
    { open($outh, ">$out") or die "cannot open $out:$!" }

    my $opt_normalize = $params{'normalize'};
    delete $params{'normalize'};

    my $ret = "BEGIN OUTPUT BY Text::Ngrams version $VERSION\n\n";

    foreach my $n (1 .. $self->{windowsize}) {
	{ my $tmp = "$n-GRAMS (total count: $self->{total}[$n])";
	  $ret .= "$tmp\n" .
	      "FIRST N-GRAM: ".&encode_S($self->{firstngram}[$n]).
	      "\n LAST N-GRAM: ".&encode_S($self->{lastngram}[$n])."\n".
	      ('-' x length($tmp)) . "\n";
        }
	my $total = $self->{total}[$n];

	my @keys;
	if (!exists($params{'orderby'}) or $params{'orderby'} eq 'ngram')
	{ @keys = sort(keys(%{$self->{table}[$n]})) }
	elsif ($params{'orderby'} eq 'none') {
	    die "onlyfirst requires order" if $onlyfirst;
	    @keys = keys(%{$self->{table}[$n]})
	    }
	elsif ($params{'orderby'} eq 'frequency') {
	    @keys = sort { $self->{table}[$n]{$b} <=>
			   $self->{table}[$n]{$a} }
	            keys(%{$self->{table}[$n]});
	}
	else { die }

	@keys = splice(@keys,0,$onlyfirst) if $onlyfirst;

	foreach my $ngram (@keys) {
	    my $count = $self->{table}[$n]{$ngram};
	    $ret .= &encode_S($ngram) . "\t" .
		($opt_normalize ? ($count / $total ) : $count) ."\n";
	    if ($out) { print $outh $ret; $ret = '' }

	}

	$ret .= "\n";
    }

    $ret .= "END OUTPUT BY Text::Ngrams\n";

    if ($out) {
	print $outh $ret; $ret = '';
	close($outh) if not ref($out);
    }

    return $ret;
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
        elsif (/^\^(\S)/) { $_ = $'; $out .= pack('C',ord($1)+128); }
        elsif (/^\`(\S)/) {
            $_ = $'; my $tmp = $1;
            $tmp =~ tr/0-5Aabtnvfroil6-9NSTcEseFGRUd/\x00-\x1F\x7F/;
            $out .= pack('C', ord($tmp)+128);
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
  $ng3->process_text('abcdefg1235678hijklmnop');
  print $ng3->to_string;

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
  my $ng = Text::Ngrams->new( type => utf8 );

To process a list of files:

  $ng->process_files('somefile.txt', 'otherfile.txt');

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
C<ngrams.pl> provided with the package.

=head1 OUTPUT FORMAT

The output looks like this (version number may be different):

  BEGIN OUTPUT BY Text::Ngrams version 1.1

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

  BEGIN OUTPUT BY Text::Ngrams version 1.1

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

  BEGIN OUTPUT BY Text::Ngrams version 1.1

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

=head2 new ( windowsize => POS_INTEGER, type => character|byte|word|utf8, limit => POS_INTEGER )

  my $ng = Text::Ngrams->new;
  my $ng = Text::Ngrams->new( windowsize=>10 );
  my $ng = Text::Ngrams->new( type=>'word' );
  my $ng = Text::Ngrams->new( limit=>10000 );
  and similar.

Creates a new C<Text::Ngrams> object and returns it.
Parameters:

=over 4

=item limit

Limit the number of distinct n-grams.  Processing large files may be
slow, so you can limit the total number of distinct n-grams which are
counted to speed up processing.
Less-frequent ones will be deleted.

B<BEWARE:> If a limit is set, the n-gram counts at the end may not be
correct due to periodical pruning of n-grams.

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

=item utf8

UTF8 characters: Variable length encoding.

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

$o->{skipinsert} - string to be replace a skiprex match that makes
    string too short (efficiency issue)

$o->{tokenrex} - regular expression for recognizing a token.  If it is
empty, it means chopping off one character.

$o->{processtoken} - routine for token preprocessing.  Token is given and returned in $_.

$o->{allow_iproc} - boolean, if set to true (1) allows for incomplete
    tokens to be preprocessed and put back (efficiency motivation)

For example, the types character, byte, and word are defined in the
foolowing way:

  if ($params{type} eq 'character') {
      $self->{tokenseparator} = '';
      $self->{skiprex} = '';
      $self->{tokenrex} = qr/([a-zA-Z]|[^a-zA-Z]+)/;
      $self->{processtoken} =  sub { s/[^a-zA-Z]+/ /; $_ = uc $_ }
      $self->{allow_iproc} = 1;
  }
  elsif ($params{type} eq 'byte') {
      $self->{tokenseparator} = '';
      $self->{skiprex} = '';
      $self->{tokenrex} = '';
      $self->{processtoken} = '';
  }
  elsif ($params{type} eq 'utf8') {
      $self->{tokenseparator} = '';
      $self->{skiprex} = '';
      $self->{tokenrex} = qr/([\xF0-\xF4][\x80-\xBF][\x80-\xBF][\x80-\xBF]
                             |[\xE0-\xEF][\x80-\xBF][\x80-\xBF]
                             |[\xC2-\xDF][\x80-\xBF]
                             |[\x00-\xFF])/x;
      $self->{processtoken} = '';
  }
  elsif ($params{type} eq 'word') {
      $self->{tokenseparator} = ' ';
      $self->{skiprex} = qr/[^a-zA-Z0-9]+/;
      $self->{skipinsert} = ' ';
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

=head2 to_string ( orderby => 'ngram|frequency|none', onlyfirst => NUMBER, out => filename|handle, normalize => 1 )

  print $ng3->to_string;
  print $ng->to_string( orderby=>'frequency' );
  print $ng->to_string( orderby=>'frequency', onlyfirst=>10000 );
  print $ng->to_string( orderby=>'frequency', onlyfirst=>10000, normalize=>1 );

Produce string representation of the n-gram tables.

Parameters:

=over 4

=item C<orderby>

The parameter C<orderby> specifies the order of n-grams.  The default
value is 'ngram'.

=item C<onlyfirst>

The parameter C<onlyfirst> causes printing only this many first n-grams
for each n.  It is incompatible with C<orderby=>'none'>.

=item C<out>

The method C<to_string> produces n-gram tables.  However, if those
tables are large and we know that we will write them to a file
right after processing, it may save memory and time to provide the
parameter C<out>, which is a filename or reference to a file handle.
(Experiments on my machine do not show significant improvement nor degradation.)
Filename will be opened and closed, while the file handle will not.

=item C<normalize>

This is a boolean parameter.  By default, it is false (''), in which
case n-gram counts are produced.  If it is true (e.g., 1), the output
will contain normalized frequencies; i.e., n-gram counts divided by
the total number of n-grams of the same size.

=back

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

=head1 PERFORMANCE

The preformance can vary a lot depending on the type of file, in
particular on the content entropy.  For example a file in English is
processed faster than a file in Chinese, due to a larger number of
distinct n-grams.

The following tests are preformed on a Pentium-III 550MHz, 512MB
memory, Linux Red Hat 6 platform.  (See C<ngrams.pl> - the script is
included in this package.)

  ngrams.pl --n=10 --type=byte 1Mfile

The 1Mfile is a 1MB file of Chinese text.  The program spent
consistently 20 sec per 100KB, giving 200 seconds (3min and 20sec) for
the whole file.  However, after 4 minutes I gave up on waiting for
n-grams to be printed.  The bottleneck seems to be encode_S function,
so after:

  ngrams.pl -n=10 --type=byte --orderby=frequency --onlyfirst=5000 1Mfile

it took about 3:24 + 5 =~ 9 minutes to print.  After changing
C<ngrams.pl> so that it provides parameter C<out> to C<to_string> in
module C<Ngrams.pm> (see Text::Ngrams), it still took:
3:09+1:28+4:40=9.17.

=head1 LIMITATIONS

If a user customizes a type, it is possible that a resulting n-gram
will be ambiguous.  In this way, to different n-grams may be counted
as one.  With predefined types of n-grams, this should not happen.
For example, if a user chooses that a token can contain a space, and
uses space as an n-gram separator, then a trigram like this "x x x x"
is ambiguous.

Method process_file does not handle multi-line tokens by default.
This can be fixed, but it does not seem to be worth the code
complication.  There are various ways around this if one really needs
such tokens:  One way is to preprocess them.  Another way is to read
as much text as necessary at a time then to use process_text, which
does handle multi-line tokens.

=head1 THANKS

I would like to thank cpan-testers, Jost Kriege, Shlomo Yona, David
Allen (for localizing and reporting and efficiency issue with ngram
prunning), Andrija, Roger Zhang, Jeremy Moses, and Kevin J. Ziese for
bug reports and comments.

I will be grateful for comments, bug reports, or just letting me know
that you used the module.

=head1 AUTHOR

Copyright 2003-2004 Vlado Keselj www.cs.dal.ca/~vlado

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
# $Id: Ngrams.pm,v 1.33 2004/12/08 13:15:00 vlado Exp $
