#!/usr/bin/perl -w

use strict;
use vars qw($VERSION);
use Text::Ngrams;

$VERSION = sprintf "%d.%d", q$Revision: 1.3 $ =~ /(\d+)/g;

use Getopt::Long;

my ($help, $version, $orderbyfrequency);
my $n = 3;
my $type = 'character';

sub help {
    print <<EOF;
Usage: $0 [options] [files]
Compute the ngram frequencies and produce tables to the stdout.
Options:
--n=N		The default is 3-grams.
--type=T        The default is character.  For more types see
                Text::Ngrams module.
--help		Show this help.
--version	Show version.
--orderbyfrequency To order the output by frequency.

The options can be shortened to their unique prefixes and
the two dashes to one dash.  No files means using STDIN.
EOF
    exit(1);
}

help()
    unless
      GetOptions('n=i'        => \$n,
		 'type=s'     => \$type,
		 'help'       => \$help,
		 'version'    => \$version,
                 'orderbyfrequency' => \$orderbyfrequency);

help() if $n < 1 || int($n) != $n;

sub version {
    print $VERSION, "\n";
    exit(1);
}

help()    if $help;
version() if $version;

my $ng = Text::Ngrams->new( windowsize=>$n, type=>$type);

if ($#ARGV > -1) { $ng->process_files(@ARGV) }
else { $ng->process_files(\*STDIN) }

print $orderbyfrequency ? $ng->to_string( orderby=>'frequency' )
    : $ng->to_string();
exit(0);

__END__
=head1 NAME

ngrams - Compute the ngram frequencies and produce tables to the stdout.

=head1 SYNOPIS

  ngram [--version] [--help] [--n=3] [--type=character] [--orderbyfrequency] [input files]

=head1 DESCRIPTION

This script produces n-grams tables of the input files to the standard
ouput.

Options:
=over 4
=item --version

Prints version.

=item --help

Prints help.

=item --n=NUMBER

N-gram size, produces 3-grams by default.

=item --type=character|byte|word

Type of n-grams produces. See Text::Ngrams module.

=item --orderbyfrequency

By default, the n-grams are ordered lexicographically.  If this option
is specified, then they are ordered by frequency in descending order.

=head1 PREREQUISITES

Text::Ngrams,
Getopt::Long

=head1 SCRIPT CATEGORIES

Text::Statistics

=head1 SEE ALSO

Text::Ngrams module.

=head1 COPYRIGHT

Copyright 2003 Vlado Keselj F<http://www.cs.dal.ca/~vlado>

This module is provided "as is" without expressed or implied warranty.
This is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

The latest version can be found at F<http://www.cs.dal.ca/~vlado/srcperl/>.

=cut
