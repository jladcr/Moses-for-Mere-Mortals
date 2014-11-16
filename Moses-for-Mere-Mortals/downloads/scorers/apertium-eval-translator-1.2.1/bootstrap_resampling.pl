#!/usr/bin/perl -w 

# (c) 2007 Felipe Sánchez Martínez
# (c) 2007 Universitat d'Alacant
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

use Math::Random::OO::Bootstrap;

#use locale;
#use POSIX qw(locale_h);
#setlocale(LC_ALL,"");

my($source, $test, $ref, $help, $times, $evalscript);

# Command line arguments
GetOptions( 'source|s=s'         => \$source,
            'test|t=s'           => \$test,
            'ref|r=s'            => \$ref,
            'times|n=n'          => \$times,
            'eval|e=s'           => \$evalscript,
            'help|h'             => \$help,
          ) || pod2usage(2);


pod2usage(2) if $help;
pod2usage(2) unless ($source);
pod2usage(2) unless ($test);
pod2usage(2) unless ($ref);
pod2usage(2) unless ($times);
pod2usage(2) unless ($evalscript);

open(SRC, "<$source") or die "Error: Cannot open source file \'$source\': $!\n";
open(TEST, "<$test") or die "Error: Cannot open test file \'$test\': $!\n";
open(REF, "<$ref") or die "Error: Cannot open reference file \'$ref\': $!\n";

print "Source file: '$source'\n";
print "Test file: '$test'\n";
print "Reference file '$ref'\n";
print "Eval script '$evalscript'\n";
print "Number of times '$times'\n\n";

my(@src_corpus, @test_corpus, @ref_corpus);

while(<TEST>) {
  &preprocess;
#  s/[*](\w+)/$1/g;
  push @test_corpus, $_;

  $_=<REF>;
  &preprocess;
#  s/[*](\w+)/$1/g;
  push @ref_corpus, $_;

  $_=<SRC>;
  &preprocess;
#  s/[*](\w+)/$1/g;
  push @src_corpus, $_;

}
close(SRC);
close(TEST);
close(REF);

if ($#test_corpus != $#ref_corpus) {
  print STDERR "Error: Test file has ", $#test_corpus+1, " sentences while reference file has ", $#ref_corpus+1, "\n";
  exit(1);
}

if ($#test_corpus != $#src_corpus) {
  print STDERR "Error: Test file has ", $#test_corpus+1, " sentences while source file has ", $#src_corpus+1, "\n";
  exit(1);
}

print "Number of samples (sentences): ",  $#test_corpus+1, "\n";

#Initialize the bootstrap resampling with replacement random numbers generator
my @sample=(0..$#test_corpus);
my $boots = Math::Random::OO::Bootstrap->new(@sample);
$boots->seed(0.42);

my @scores;
print "Perfoming bootstrap resampling ";
foreach (1..$times) {
  print ".";
  my @sampleset=&next_sample_set;  
  push @scores, &eval_sample_set(@sampleset);
  #print "Test $_: ",$scores[$#scores], "\n";
}
print " done.\n";

my @sorted_scores = sort { $a <=> $b } @scores; 

#foreach(0..$#sorted_scores) {
#print $sorted_scores[$_], "\n";
#}

&confidence(0.95, @sorted_scores);
&confidence(0.85, @sorted_scores);
&confidence(0.75, @sorted_scores);
&confidence(0.65, @sorted_scores);
&confidence(0.50, @sorted_scores);

##########################################################################

sub confidence {
  my ($conf, @scores)=@_;

  #foreach(0..$#scores) {
  #  print $scores[$_], "\n";
  #}

  my $drop=&round((1.0-$conf)/2.0*$times);

  print "\n--- Confidence: $conf ---\n";
  print "Removing the top $drop and bottom $drop scores ... ";
  foreach (1..$drop) {
    shift @scores;
  }

  foreach (1..$drop) {
    pop @scores;
  }
  print " done.\n";

  my($min,$max);
  $min=$scores[0];
  $max=$scores[$#scores];

  print &mean(@scores), " in [ ", $min, " , ",  $max, " ]\n";

  print "Score: ", ($min+(($max-$min)/2.0)), " +/- ", (($max-$min)/2.0), "\n";
}

sub next_sample_set {
  my @sampleset;

  foreach (0..$#sample) {
    push @sampleset, $boots->next();
  }
  return @sampleset;
}

sub eval_sample_set {
  my (@sampleset)=@_;

  #Prepare source file
  open(TMP, ">/tmp/source_file-$$") or die "Error: Cannot open file \'/tmp/source_file-$$\': $!\n";  
  foreach (@sampleset) {
    print TMP $src_corpus[$_], "\n";
  }
  close(TMP);

  #Prepare test file
  open(TMP, ">/tmp/test_file-$$") or die "Error: Cannot open file \'/tmp/test_file-$$\': $!\n";  
  foreach (@sampleset) {
    print TMP $test_corpus[$_], "\n";
  }
  close(TMP);

  #Prepare reference file
  open(TMP, ">/tmp/reference_file-$$") or die "Error: Cannot open file \'/tmp/reference_file-$$\': $!\n";  
  foreach (@sampleset) {
    print TMP $ref_corpus[$_], "\n";
  }
  close(TMP);

  #Execution of the evaluation script
  my $output=`$evalscript /tmp/source_file-$$ /tmp/reference_file-$$ /tmp/test_file-$$`;
  chomp $output;

  $output =~ tr/,/./;
  #print STDERR $output, "\n";

  `rm /tmp/source_file-$$ /tmp/reference_file-$$ /tmp/test_file-$$`;
  
  return $output;
}

sub round {
  my($number) = @_;
  return int($number + 0.5 * ($number <=> 0));
}

sub mean {
  my(@v) = @_;
  my $sum=0.0;

  foreach (@v) {
    $sum+=$_;
  }

  return $sum/($#v+1);
}


sub preprocess {
  chomp;
  #Insert spaces before and after  punctuation marks 
  #s/([.,;:%¿?¡!()\[\]{}<>])/ $1 /g;
}


__END__

=head1 NAME

=head1 SYNOPSIS

mteval_by_bootstrap_resampling.pl -source srcfile -test testfile -ref
reffile -times <n> -eval /full/path/to/eval/script

Options:

  -source|-s   Specify the file with the source file
  -test|-t     Specify the file with the translations to evaluate 
  -ref|-r      Specify the file with the reference translations
  -times|-n    Specify how many times the resampling should be done
  -eval|-e     Specify the full path to the MT evaluation script
  -help|-h     Show this help message
  
Note: Reference translation MUST have no unknown-word marks, even if
      they are free rides.

(c) 2007 Felipe Sánchez Martínez
(c) 2007 Universitat d'Alacant

This software is licensed under the GNU GENERAL PUBLIC LICENSE version
2, or at your option any latter version. See
http://www.gnu.org/copyleft/gpl.html for a complete version of the
license.
