#!/usr/bin/perl -w 

# $Id$
# $URL$

# Modified by Stephen Marquard <stephen.marquard@uct.ac.za> from:
#
# apertium-eval-translator-line.pl
#
# (c) 2006 Felipe Sánchez Martínez
# (c) 2006 Universitat d'Alacant
#
# This software calculates the word error rate (WER) and the
# position-independent word error rate (PER) between the translation
# performed by the apertium MT system an a reference translation
# obtained by post-editing the system ouput.
# 
# The edit_distance procedure used in this script is based on 
# the Levenshtein distance implementation by Jorge Mas Trullenque 
# that can be found in http://www.merriampark.com/ldperl2.htm 
#
# This software is licensed under the GPL license version 2, or at
# your option any later version 
#

use strict; 
use warnings;

# Getting command line arguments:
use Getopt::Long;
# Documentation:
use Pod::Usage;
# I/O Handler
use IO::Handle;

use locale;
use POSIX qw(locale_h);
setlocale(LC_ALL,"");

my($test, $ref, $help, $version, $verbose, $beam);

my($nunknown, $ntest, $nref, $distance_nounk, $per_nounk);

my($test_corpus, $ref_corpus);

my(@words_test, @words_ref);

# Command line arguments
GetOptions( 'test|t=s'           => \$test,
            'ref|r=s'            => \$ref,
            'beam|b=n'           => \$beam,
            'verbose'            => \$verbose,
            'help|h'             => \$help,
	    'version|v'          => \$version,
          ) || pod2usage(2);

if ($version) {
   print "apertium-wer 1.2.1\n";
   exit 0;
}

pod2usage(2) if $help;
pod2usage(2) unless ($test);
pod2usage(2) unless ($ref);

# Default beam size of 50

$beam=50 unless ($beam);
$beam=0 if ($beam<0);

undef $/; #To read whole files at one step

open(TEST, "<$test") or die "Error: Cannot open test file \'$test\': $!\n";
open(REF, "<$ref") or die "Error: Cannot open reference file \'$ref\': $!\n";

#print "Test file: '$test'\n";
#print "Reference file '$ref'\n\n";


while(<TEST>) {
  &preprocess;
  $test_corpus=lc($_);

  $nunknown+=s/[*](\w+)/$1/g;
  @words_test = split(/[\s\n]+/, $test_corpus);
    
  if (defined($verbose)) {
        print "TESTCORPUS:\n";

        foreach(@words_test) {
            print "$_ ";
        }
        print "\n\n";
  }
    
  $ntest+=@words_test;

  $_=<REF>;
  &preprocess;
  $ref_corpus=lc($_);
    
  @words_ref = split(/[\s\n]+/, $ref_corpus);

  if (defined($verbose)) {
        print "REFCORPUS:\n";
        
        foreach(@words_ref) {
            print "$_ ";
        }
        print "\n\n";
  }
    
  $nref+=@words_ref;

  $distance_nounk+=&edit_distance; 
  $per_nounk+=&position_independent_correct_words;
}

close(TEST);
close(REF);


print "Statistics about input files\n";
print "-------------------------------------------------------\n";
print "Number of words in reference: $nref\n";
print "Number of words in test: $ntest\n";
#print "Number of unknown words (marked with a star) in test: $nunknown\n";
#print "Percentage of unknown words: ", sprintf("%.2f",($nunknown/$ntest)*100), " %\n";
print "\n";

#print "Results when removing unknown-word marks (stars)\n";
#print "-------------------------------------------------------\n";
print "Edit distance: $distance_nounk\n";
print "Word error rate (WER): ", sprintf("%.2f",($distance_nounk/$nref)*100), " %\n";
#print "Number of position-independent correct words: ",  $per_nounk, "\n";
#print "Position-independent word error rate (PER): ", sprintf("%.2f",(1 - (($per_nounk - max(0, $ntest - $nref)) / $nref))*100), " %\n";

print "\n";


sub position_independent_correct_words {
  my (%hash_test, %hash_ref);

  foreach (@words_test) {
    $hash_test{$_}++;
  }

  foreach (@words_ref) {
    $hash_ref{$_}++;
  }

  my $correct=0;

  foreach (keys %hash_test) {
    if(defined($hash_ref{$_})) {
      $correct += min($hash_test{$_}, $hash_ref{$_});
    }
  }
  
  return $correct;
}

sub edit_distance {
  my @W=(0..@words_ref);
  my ($i, $j, $cur, $next);

  my ($lim_inf, $lim_sup, $best_j);
  $best_j=0;
  for $i (0..$#words_test) {
    $cur=$i+1;

    if($beam>0) {
          $lim_inf=$best_j-$beam; 
          $lim_inf=0 if ($lim_inf<0);
          
          $lim_sup=$best_j+$beam;
          $lim_sup=$#words_ref if ($lim_sup>$#words_ref);
    } else {
          $lim_inf=0;
          $lim_sup=$#words_ref;
    }
      
      
    for $j ($lim_inf..$lim_sup){
      my $cost=($words_test[$i] ne $words_ref[$j]);
      $next=min($W[$j+1]+1, $cur+1, $cost+$W[$j]);
      $W[$j]=$cur;

      $best_j=$j+1 if ($cur > $next);

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

sub max {
  my @list = @_;
  my $max = $list[0];

  foreach my $i (@list) {
    $max = $i if ($i > $max);
  }
   return $max;
}

sub preprocess {
  chomp;
  
    # Remove some punctuation
    
    # Remove double-dashes
    s/\-\-/ /g;
    
    # Remove quotes
    s/\"//g;
    
    # Remove commas, semi-colons, colon, full-stop, question mark
    s/[,;:\.\?]/ /g;
    
    s/  / /g;
    
  # Insert spaces before and after  punctuation marks 
  #s/([.,;:%¿?¡!()\[\]{}<>])/ $1 /g;
}


__END__


=head1 NAME

=head1 SYNOPSIS

apertium-wer -test testfile -ref reffile 

Options:

  -test|-t     Specify the file with the hypothesis
  -ref|-r      Specify the file with the reference transcript
  -beam|-b     Specify the search beam size for word matching
  -help|-h     Show this help message
  -version|-v  Show version information and exit
  
This software calculates (at document level) the word error rate (WER)
between a transcript and a recognition hypothesis.

(c) 2011 Stephen Marquard, University of Cape Town

(c) 2006 Felipe Sánchez-Martínez
(c) 2006 Universitat d'Alacant

This software is licensed under the GNU GENERAL PUBLIC LICENSE version
2, or at your option any latter version. See
http://www.gnu.org/copyleft/gpl.html for a complete version of the
license.
