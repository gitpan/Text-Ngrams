#!/usr/bin/perl -w

use strict;
use vars qw($VERSION);
#<? read_starfish_conf(); echo "\$VERSION = $ModuleVersion;"; !>
#+
$VERSION = 1.0;
#-
# $Revision: 1.8 $

use Text::Ngrams;
use Getopt::Long;

my ($help, $version, $orderby, $onlyfirst, $limit);
my $n = 3;
my $type = 'character';

sub help {
    print <<EOF;
Usage: $0 [options] [files]
Compute the ngram frequencies and produce tables to the stdout.
Options:
--n=N		The default is 3-grams.
--normalize     Produce normalized frequencies (divided by the total
                number of n-grams of the same size)
--type=T        The default is character.  For more types see
                Text::Ngrams module.
--limit=N       Limit the number of distinct n-grams.
--help		Show this help.
--version	Show version.
--orderby=ARG   ARG can be: frequency or ngram.
--onlyfirst=N   Only first N ngrams are printed for each n.

The options can be shortened to their unique prefixes and
the two dashes to one dash.  No files means using STDIN.
EOF
    exit(1);
}

my ($opt_normalize);

help()
    unless
      GetOptions('n=i'        => \$n,
		 'normalize'  => \$opt_normalize,
		 'type=s'     => \$type,
		 'limit=i'    => \$limit,
		 'help'       => \$help,
		 'version'    => \$version,
                 'orderby=s'  => \$orderby,
                 'onlyfirst=i' => \$onlyfirst);

help() if $n < 1 || int($n) != $n;

sub version {
    print $VERSION, "\n";
    exit(1);
}

help()    if $help;
version() if $version;

my %params = ( windowsize=>$n, type=>$type);

if (defined($limit) and ($limit > 0)) { $params{'limit'} = $limit }

my $ng = Text::Ngrams->new( %params );

if ($#ARGV > -1) { $ng->process_files(@ARGV) }
else { $ng->process_files(\*STDIN) }

%params = ( 'out' => \*STDOUT );
if (defined($orderby) and $orderby) { $params{'orderby'} = $orderby }
if (defined($onlyfirst) and $onlyfirst>0) { $params{'onlyfirst'} = $onlyfirst }
if ($opt_normalize) { $params{'normalize'} = $opt_normalize }

print $ng->to_string( %params );

exit(0);

__END__
=head1 NAME

ngrams - Compute the ngram frequencies and produce tables to the stdout.

=head1 SYNOPIS

  ngram [--version] [--help] [--n=3] [--normalize] [--type=TYPE]
        [--orderby=ORD] [--onlyfirst=N] [input files]

=head1 DESCRIPTION

This script produces n-grams tables of the input files to the standard
ouput.

Options:
=over 4

=item --normalize

Prints normalized n-gram frequencies; i.e., the n-gram counts divided
by the total number of n-grams of the same size.

=item --onlyfirst=NUMBER

Prints only the first NUMBER n-grams for each n.  See Text::Ngrams module.

=item --limit=NUMBER

Limit the total number of distinct n-grams (for efficiency reasons,
the counts may not be correct at the end).

=item --version

Prints version.

=item --help

Prints help.

=item --n=NUMBER

N-gram size, produces 3-grams by default.

=item --orderby=frequency|ngram

The n-gram order.  See Text::Ngrams module.

=item --type=character|byte|word

Type of n-grams produces. See Text::Ngrams module.

=head1 PREREQUISITES

Text::Ngrams,
Getopt::Long

=head1 SCRIPT CATEGORIES

Text::Statistics

=head1 README

N-gram analysis for various kinds of n-grams (character, words, bytes,
and user-defined). Based on Text::Ngrams module.

=head1 SEE ALSO

Text::Ngrams module.

=head1 COPYRIGHT

Copyright 2003 Vlado Keselj F<http://www.cs.dal.ca/~vlado>

This module is provided "as is" without expressed or implied warranty.
This is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

The latest version can be found at F<http://www.cs.dal.ca/~vlado/srcperl/>.

=cut
