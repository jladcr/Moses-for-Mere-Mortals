#!/usr/bin/perl -w 

# (c) 2006-2010 Felipe Sánchez Martínez
# (c) 2006-2010 Universitat d'Alacant
#
# This software calculates  the position-independent word error 
# rate (PER) between an automatic translation and a reference 
#translation.
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
   print "PER.pl 1.0\n";
   exit 0;
}

pod2usage(2) if $help;
pod2usage(2) unless ($test);
pod2usage(2) unless ($ref);

open(TEST, "<$test") or die "Error: Cannot open test file \'$test\': $!\n";
open(REF, "<$ref") or die "Error: Cannot open reference file \'$ref\': $!\n";

my($ntest, $nref, $correct) = (0, 0, 0);
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

  my $this_correct = &position_independent_correct_words;
  print "LINE $line ", 1 - (($this_correct - max(0, @words_test - @words_ref)) / @words_ref), "\n" if ($seg);

  $correct += $this_correct;
  $ntest += @words_test;
  $nref += @words_ref;
}

close(TEST);
close(REF);

print 1 - (($correct - max(0, $ntest - $nref)) / $nref), "\n";


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

sub max {
  my @list = @_;
  my $max = $list[0];

  foreach my $i (@list) {
    $max = $i if ($i > $max);
  }
   return $max;
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

PER.pl -test testfile -ref reffile 

Options:

  -test|-t     Specify the file with the translation to evaluate 
  -ref|-r      Specify the file with the reference translation (only one)
  -seg|-s      Report PER also at segment level
  -help|-h     Show this help message
  -version|-v  Show version information and exit
  
This software calculates (at segment level and document level) 
the position-independent error rate (PER) between an automatic translation
and a reference translation. 

(c) 2006-2010 Felipe Sánchez-Martínez
(c) 2006-2010 Universitat d'Alacant

This software is licensed under the GNU GENERAL PUBLIC LICENSE version
3, or at your option any latter version. See
http://www.gnu.org/copyleft/gpl.html for a complete version of the
license.

