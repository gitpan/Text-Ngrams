#!/usr/bin/perl

sub getfile($) {
    my $f = shift;
    local *F;
    open(F, "<$f") or die "getfile:cannot open $f:$!";
    my @r = <F>;
    close(F);
    return wantarray ? @r : join ('', @r);
}

sub putfile($@) {
    my $f = shift;
    local *F;
    open(F, ">$f") or die "putfile:cannot open $f:$!";
    print F '' unless @_;
    while (@_) { print F shift(@_) }
    close(F);
}

sub normalize {
    my $r = shift;
    $r =~ s/(BEGIN OUTPUT BY Text::Ngrams version )[\d.]+/$1/;
    $r =~ s/(\s\d\.\d\d\d\d\d\d\d\d\d\d\d\d\d\d)\d*/$1/g;
    return $r;
}

1;
