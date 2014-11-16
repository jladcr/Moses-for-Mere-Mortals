#!/usr/bin/perl -w 

# (c) 2006-2010 Felipe Sánchez Martínez
# (c) 2006-2010 Universitat d'Alacant
#
# This software calculates the word error rate (WER) between an 
# automatic translation and a reference translation.
#
# The edit_distance procedure used in this script is based on 
# the Levenshtein distance implementation by Jorge Mas Trullenque 
# that can be found in http://www.mgilleland.com/ld/ldperl2.htm
#
# This software is licensed under the GPL license version 3, or at
# your option any later version 

use strict; 
use warnings;

# Getting command line arguments:
use Getopt::Long;
# Documentation:
use Pod::Usage;
# I/O Handler
use IO::Handle;

my($test, $ref, $help, $seg, $version);

# Command line arguments
GetOptions( 'test|t=s'           => \$test,
            'ref|r=s'            => \$ref,
            'seg|s'              => \$seg,
            'help|h'             => \$help,
	    'version|v'          => \$version,
          ) || pod2usage(2);

if ($version) {
   print "WER.pl 1.0\n";
   exit 0;
}

pod2usage(2) if $help;
pod2usage(2) unless ($test);
pod2usage(2) unless ($ref);

open(TEST, "<$test") or die "Error: Cannot open test file \'$test\': $!\n";
open(REF, "<$ref") or die "Error: Cannot open reference file \'$ref\': $!\n";

my($ntest, $nref, $distance) = (0, 0, 0);
my(@words_test, @words_ref);

my $line = 0;

while(<TEST>) {
  chomp;
  s/^\s+//g; 
  s/\s+$//g;
  @words_test = split /\s+/;

  $_=<REF>;
  chomp;
  s/^\s+//g; 
  s/\s+$//g;
  @words_ref = split /\s+/;

  $line++;

  my $this_distance = &edit_distance;
  print "LINE $line ", $this_distance/@words_ref, "\n" if ($seg);

  $distance += $this_distance; 
  $ntest += @words_test;
  $nref += @words_ref;
}

close(TEST);
close(REF);

print $distance/$nref, "\n";

sub edit_distance {
  my @W=(0..@words_ref);
  my ($i, $j, $cur, $next);

  return scalar(@words_ref) if (scalar(@words_test) == 0);
  return scalar(@words_test) if (scalar(@words_ref) == 0);

  for $i (0..$#words_test) {
    $cur=$i+1;

    for $j (0..$#words_ref){
      my $cost=($words_test[$i] ne $words_ref[$j]);
      $next=min($W[$j+1]+1, $cur+1, $cost+$W[$j]);
      $W[$j]=$cur;

      $cur=$next;
    }
    $W[@words_ref]=$next;
  }
  return $next;
}

sub min {
  my @list = @_;
  my $min = $list[0];

  foreach my $i (@list) {
    $min = $i if ($i < $min);
  }
   return $min;
}

__END__


=head1 NAME

=head1 SYNOPSIS

WER.pl -test testfile -ref reffile 

Options:

  -test|-t     Specify the file with the translation to evaluate 
  -ref|-r      Specify the file with the reference translation (only one)
  -seg|-s      Report WER also at segment level
  -help|-h     Show this help message
  -version|-v  Show version information and exit
  
This software calculates (at segment level and document level) 
the word error rate (WER) between an automatic translation
and a reference translation. 

(c) 2006-2010 Felipe Sánchez-Martínez
(c) 2006-2010 Universitat d'Alacant

This software is licensed under the GNU GENERAL PUBLIC LICENSE version
3, or at your option any latter version. See
http://www.gnu.org/copyleft/gpl.html for a complete version of the
license.
