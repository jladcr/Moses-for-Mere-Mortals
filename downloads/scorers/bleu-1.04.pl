#!/usr/bin/perl

# (C) Copyright IBM Corp. 2001 All Rights Reserved.
#
# This script has only been tested with English language references and candidates.  Unpredictable results
# may occur with other single byte target languages, and they will occur with multi-byte target languages.
#
# This script has only been tested with Perl 5.6.  Although there is no intentional incompatibility with generic
# Perl 5 stable releases, we include this test to forcibly call your attention to the lack of testing for
# such releases.
#require 5.6.0;
#
# Author: Kishore Papineni
#
# version history:
# 04/27/2005:  Adapted NIST's tokenization
# 03/09/2004:  Smoothing of ngram counts at the segment level (merged 4c nbest and 4d)
# 08/22/2002:  Confidence interval and Case-sensitivity added
# 06/12/2002:  -from and -to for document range reinstated
# 04/12/2002:  Optional attribs in <segment> tag allowed;
#              Removed $ from $1 in (my $j = $1; $j <= $ngrSize; $j++)..
# 03/23/2002:  handles light-weight sgml markup
# 06/10/2001:  first version 
#
# Implements the baseline BLEU as described in
# K.A. Papineni, S. Roukos, R.T. Ward, and W.-J. Zhu, 
# "BLEU: a method for Automatic Evaluation of Machine
# Translation," Proceedings of ACL-02, Philadelphia, July 2002, pp. 311-318.

#########################################
##             Usage                   ##
#########################################
$scriptName = $0;
$scriptName =~ s,^.*/,,;
$scriptName =~ s,^.*\\,,;

&PrintUsage if (@ARGV < 4);

#########################################
##         Process Arguments           ##
#########################################
# Stand-alone script; no require's and no use's
$argstr = " @ARGV ";
print STDOUT "$scriptName $argstr\n";
$dbgLevel = 0;
if ($argstr =~ /\s*-d\s+(.*?)\s+/) {
    $dbgLevel = $1;
}

$ngrSize = 4;
if ($argstr =~ /\s*-n\s+(.*?)\s+/) {
    $ngrSize = $1;
}

$casesensitive = 1;
if ($argstr =~ /\s*-ci\s+/) {
    $casesensitive = 0;
}

if ($argstr =~ /\s*-t\s+(.*?)\s+/) {
    $testsgmFileName = $1;
} else {
    print STDERR "test file is not specified.\n";
    &PrintUsage();
}

if ($argstr =~ /\s*-r\s+(.*?)\s+/) {
    $refsgmFileName = $1;
} else {
    print STDERR "reference file is not specified.\n";
    &PrintUsage();
}

if ($argstr =~ /\s*-s\s+(.*?)\s+/) {
    $srcsgmFileName = $1;
}

if ($argstr =~ /\s*-ignore\s+(.*?)\s+/) {
    $ignoreFileName = $1;
}

if ($argstr =~ /\s*-sys\s+(.*?)\s+/) {
    $evalSysId = $1;
}

$fromDoc = 0;
if ($argstr =~ /\s*-from\s+(\d+)\s+/) {
    $fromDoc = $1;
} 

if ($argstr =~ /\s*-to\s+(\d+)\s+/) {
    $toDoc = $1;
}

$html = "";
if ($argstr =~ /\s*-html\s+(.*?)\s+/) {
    $html = $1;
    open(HTMOUT, ">$html") or die "Cannot open file to write the best choices: $html\n";
}

$bestn = 1;
if ($argstr =~ /\s*-nbest\s+(\d+)\s+/) {
    $bestn = $1;
}

$worstNbest = 0;
if ($argstr =~ /\s*-worst\s+/) {
    $worstNbest = 1;
    print STDERR "Performing worst nbest sent selection\n";
}

$bestout = "";
if ($argstr =~ /\s*-bestout\s+(.*?)\s+/) {
    $bestout = $1;
    open(BESTOUT, ">$bestout") or die "Cannot open file to write the best choices: $bestout\n";
}

$nbestscores = "";
if ($argstr =~ /\s*-nbestscores\s+(.*?)\s+/) {
    $nbestscores = $1;
    open(NBESTOUT, ">$nbestscores") or die "Cannot open file to write bleu scores of top-n: $nbestscores\n";
}


#########################################
##     Initialization of variables     ##
#########################################
# Programming notes: ref means reference translation; not a Perl reference.
#                    hypothesis means test-translation that is being evaluated against refs.
#   Confidence Interval calculation:
#      Say the current test set has mn segments. Compute bleu on m blocks of size n, to get m 
#      samples of bleu. Compute sample mean, standard error, and the confidence interval around the
#      mean bleu. We also compute the global BLEU across all documents of the test set. Technically, 
#      we cannot transfer the confidence interval to the global BLEU, which is just one sample point with
#      a much bigger sample size (>= mn). But we will, with the justification that the sample variance 
#      we obtained is an upper bound on the sample variance if we were to compute BLEU on many random
#      test sets of the same size.
#########

my $srcObj;       # source unit, if a source file is supplied
my $hypObj;       # a candidate translation unit (corresponds a *source* unit)
my @refObjs;      # reference translations parallel to the candidate translation unit

# block-level stats
my @blcNgrMatches;   # how many ngrams of each size match across all units in the current block?
my @blcNumNgrams;    # number of ngrams in the translation in the current block.
my @blcNgrPrecision; # block ngrMatches element-wise divided by the number of ngrams proposed
my $blcHypWords = 0;      # number of hypothesis words in the current block
my $blcClosestRefWords = 0;  # same as above, but in the closest-in-length reference
my @blcBleus;     # bleu on each block
my $blcId = 0;    # ID of the current block
my $blockSz;      # Size of each block
my $sampleSz;     # Number of bleu samples

# document-level stats
my @docNgrMatches;   # how many ngrams of each size match across all units in the current doc?
my @docNumNgrams;    # number of ngrams in the translation in the current doc.
my @docNgrPrecision; # doc ngrMatches element-wise divided by the number of ngrams proposed
my $docHypWords = 0;      # number of hypothesis words in the current doc
my $docClosestRefWords = 0;  # same as above, but in the closest-in-length reference

# corpus-level stats (across all docs)
my @ngrMatches;   # how many ngrams of each size match across all units in the test corpus?
my @numNgrams;    # number of ngrams in the translation across the entire test corpus
my @ngrPrecision; # ngrMatches element-wise divided by the number of ngrams proposed
my $totHypWords = 0;      # number of hypothesis words across all units in the test corpus
my $closestRefWords = 0;  # same as above, but in the closest-in-length reference
my @rankstats;            # rank of the best scoring hypothesis out of nbest

my %ignoreList;

my $hypNum = 0;   # ID of the hypothesis unit; sequential for now. sgml markup should have this?
my $score = 0;

my $docId;        # ID of the current doc
my $lineNum = 0;  # Unit number of the current hypothesis unit within the current doc
my @srclines;     # "lines" or segments in the current document of the optional source file
my @hyplines;
my @reflines;

my @refids;     # names of all references
my @testids;    # names of all test systems; only one of these will be scored.
my @srcids;     # dummy
my @hypdocids;  
my @srcdocids;  # names or ids of documents in the optional source file

my %evalDoc;
my %hypDoc;
my %refDoc;
my %srcDoc; 

my $startNgr  = 1;   # By default we consider ngrams of size 1 to $ngrSize. 
my $totR2H;  # across all units, ratio of the length of the closest-in-length ref to that of the hyp.

# Student t-distribution table for 95% confidence interval as a function of degrees of freedom:
my @ttable = (1000, 12, 4.3027, 3.1824, 2.7765, 2.5706, 2.4469, 2.3646, 2.3060, 2.2622, 2.2281, 2.2010, 2.1788, 2.1604, 2.1448, 2.1315, 2.1199, 2.1098, 2.1009, 2.0930, 2.0860, 2.0796, 2.0739, 2.0687, 2.0639, 2.0595, 2.0555, 2.0518, 2.0484, 2.0452, 2.0423, 2.0395, 2.0369, 2.0345, 2.0322, 2.0301, 2.0281, 2.0262, 2.0244, 2.0227, 2.0211, 2.0195, 2.0181, 2.0167, 2.0154, 2.0141, 2.0129, 2.0117, 2.0106, 2.0096, 2.0086, 2.0076, 2.0066, 2.0057, 2.0049, 2.0040, 2.0032, 2.0025, 2.0017, 2.0010, 2.0003, 1.9996, 1.9990, 1.9983, 1.9977, 1.9971, 1.9966, 1.9960, 1.9955, 1.9949, 1.9944, 1.9939, 1.9935, 1.9930, 1.9925, 1.9921, 1.9917, 1.9913, 1.9908, 1.9905, 1.9901, 1.9897, 1.9893, 1.9890, 1.9886, 1.9883, 1.9879, 1.9876, 1.9873, 1.9870, 1.9867, 1.9864, 1.9861, 1.9858, 1.9855, 1.9852, 1.9850, 1.9847, 1.9845, 1.9842, 1.9840);

my @colormap = ("red", "black", "black_bold", "blue", "blue_bold");
# set weights (nonnegative weights that sum to 1.) 
my @wt;
&GetWeights(); # sets the weights array @wt

##############################################
##           The Main Loop:                 ##
##############################################
&ReadAllSGMFiles();
&ReadIgnoreWordList() if $ignoreFileName;
print HTMOUT "<html>\n<head>\n<meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\" >\n </head>\n<body> \n" if $html;
while (&GetHypRefs()) {
    &ScoreHyp();
}

&PrintRankStats();
&CalcConfidenceInterval();

print STDOUT "\n\nSystem,$evalSysId\nSegsScored,$hypNum\nSysWords,$totHypWords\n";
&ReportMetrics(STDOUT, $closestRefWords, $totHypWords, \@ngrPrecision);
print BESTOUT "</DOC>\n" if $bestout;
if ($html) {
    print HTMOUT "<pre>\n";
    &ReportMetrics(HTMOUT, $closestRefWords, $totHypWords, \@ngrPrecision);
    print HTMOUT "</pre></body></html>\n";
}
exit 0;

##############################################
##           Subroutines                    ##
##############################################

# Print a summary of the stats collected so far.
# Comma Separated Value format: [attrib,value\n]+
sub ReportMetrics {
    my ($outref, $reflen, $hyplen, $precArrRef) = @_;
    my $r2hLen = $reflen / $hyplen;
    print $outref "Ref2SysLen,", &Trunc($r2hLen), "\n";
    my $score = 0; 

    #Smooth
    # ngrsz = min($reflen, $ngrSize);
    my $ngrsz = $reflen;
    $ngrsz = $ngrSize if $ngrsz > $ngrSize;
 
    my $smooth = 1;
    for (my $i = 1; $i <= $ngrsz; $i++) {
	next if $$precArrRef[$i];
	$smooth *= 0.5;
	$$precArrRef[$i] = $smooth/($hyplen-$i+1);
    }

    my $wt = 1.0/$ngrsz;
    for (my $i = $startNgr; $i <= $ngrsz; $i++) {
	$score += $wt * log($$precArrRef[$i]);
	print $outref "$i-gPrec,", &Trunc($$precArrRef[$i]), "\n";
    }

    $score = exp($score);
    
    print $outref "PrecScore,", &Trunc($score), "\n";
    my $lpen = &BrevityPenalty($r2hLen);
    print $outref "BrevityPenalty,", &Trunc($lpen), "\n";
    $score *= $lpen;
    
    my $cs = "";
    $cs = "c" if $casesensitive;
    print $outref "BLEUr", 0 + @refids, "n$ngrsz$cs,", &Trunc($score), "\n";
    return $score;
}

# Subroutine to get the next unit of the test and the reference translations.
#
sub GetHypRefs {
    if ($lineNum < @hyplines) {
	$hypObj = $hyplines[$lineNum];
	if ($hypObj =~ /^\s*$/) {
	    $lineNum++;
	    print STDERR "WARNING: blank line, 1-based line number = $lineNum\n"; 
	}

	@refObjs = ();
	for ($i = 0; $i < @reflines; $i++) {
	    push @refObjs, $reflines[$i][$lineNum];
	}

	$srcObj = $srclines[$lineNum] if @srclines > 0;
	$lineNum++;
	$hypNum++;
	return 1;
    }

    return 0 unless &SegmentNextParallelDoc();
    if ($srcsgmFileName && (scalar(@hyplines) != scalar(@srclines))) {
	print STDERR "Mismatch!! src has ", @srclines + 0 , " segments and hyp has ", @hyplines + 0, " segments \n";
    }

    if (@hyplines == &QEveryRowHasSameNumberOfColumns(\@reflines)) {
	return &GetHypRefs();
    } 

    print STDERR "Line number mismatch in files. Will treat each file as a single unit\n";
    $hypObj = join("\n", @hyplines);
    @refObjs = ();
    for ($i = 0; $i < @reflines; $i++) {
	push @refObjs, join("\n", @{$reflines[$i]});
    }

    @hyplines = ();
    @reflines = ();
    $hypNum++;
    return 1;
}

###################################################
##         The Main Subroutine                   ##
###################################################
# Match the ngrams of the hypothesis with the reference translations, keeping
# track of the count of unique ngrams. Update global stats across all units (segments)
# seen so far. The BLEU metric is computed on the aggregate statistics on all units.
sub ScoreHyp {
    my %refNgrams; # for any reference-ngram, remember the max number of times that ngram appears 
                   # in any single reference.

    my @refsz;
    # for each ngram of a reference, we must find the maximum number of times it appears in any single reference
    foreach $reftrans (@refObjs) {
	&NormalizeText(\$reftrans);
	my %thisRefNgrams; # all ngrams in this reference, to be populated by the next call to Str2Ngrams()
	my $thisRefW = &Str2Ngrams(\$reftrans, \%thisRefNgrams); # thisRefW is the number of words in this ref
	push(@refsz, $thisRefW);

	foreach my $phr (keys %thisRefNgrams) {
	    $thisFreq = $thisRefNgrams{$phr};   #number of times this ngram appears in this reference
	    $maxFreqSoFar = 0;                  # max number of times this ngram appears in any single reference
	    $maxFreqSoFar = $refNgrams{$phr} if defined $refNgrams{$phr};
	    $refNgrams{$phr} = $thisFreq if $maxFreqSoFar < $thisFreq;
	}
    }

    if ($dbgLevel > $ngrSize+1) {
#	print STDERR "Hypothesis = $hypObj\n";
	print STDERR "REF: ", join("\nREF: ",@refObjs), "\n";
    }

    &NormalizeText(\$hypObj);  # simple processing such as tokenizing and lower-casing

    my @nbest;
    my $k = 0;
    while ($hypObj =~ s,\s*<nbest.*?>\s*(.*?)\s*</nbest>\s*,,) {
      my $thissent = $1;
      if ($k < $bestn) {
	push(@nbest, $thissent);
      }
      $k++;
    }

    push(@nbest, $hypObj) unless @nbest > 0;

    my $segbleu = 0;
    my $bestid = 0;
    my @counts;
    my $numW;
    my $closestRefW;
    for (my $k = 0; ($k < @nbest) && $k < $bestn; $k++) {
	my @kcounts;
	my ($kbleu, $knumW, $krefw) = &SegBleu($nbest[$k], \%refNgrams, \@refsz, \@kcounts);
	my $tbleu = &Trunc($kbleu);
	print NBESTOUT "$k $tbleu\n" if $nbestscores;
	push(@nbestbleu, $kbleu);
	if ($worstNbest) {
	  if ($segbleu > $kbleu || ($segbleu == 0)) {
	    $segbleu = $kbleu;
	    $bestid = $k;
	    @counts = @kcounts;
	    $numW = $knumW;
	    $closestRefW = $krefw;
	  }
	}
	else {
	  if ($segbleu < $kbleu) {
	    $segbleu = $kbleu;
	    $bestid = $k;
	    @counts = @kcounts;
	    $numW = $knumW;
	    $closestRefW = $krefw;
	  }
	}
    }

    print BESTOUT "<seg> $nbest[$bestid] </seg>\n" if $bestout;
    $rankstats[$bestid]++;
    if ($html) {
	my @words = split(/\s+/, $nbest[0]);
	my @colors;
	for (my $j = $ngrSize-1; $j >= 0; $j--) {
	    for (my $i = 0; $i < @words; $i++) { # go through the hypothesis left to right.
		last unless $i + $j < @words;
		my $phr = join(" ", @words[$i .. $i+$j]) . " "; # the current ngram in the hypothesis
		$numOccurs = 0;  # does this hypothesis-ngram appear in any of the references?
		$numOccurs = $refNgrams{$phr} if defined $refNgrams{$phr};
		if ($numOccurs > 0) {        # if so, 
		    $refNgrams{$phr} = $numOccurs - 1; # decrement the maxFrequency of the reference-ngram
		    for (my $k = $i; $k <= $i + $j; $k++) {
			$colors[$k] = $j+1 if $colors[$k] < $j+1;
		    }
		}
	    }
	}

	print HTMOUT "<p>\n";
	print HTMOUT "Src $lineNum. $srcObj <br>\n" if $srcsgmFileName;
	print HTMOUT "${evalSysId}[0]: ";
	for (my $k = 0; $k < @words; $k++) {
	    ($color, $bold) = split(/_/, $colormap[$colors[$k]]);
	    print HTMOUT "<b> " if $bold;
	    print HTMOUT "<font color=", $color, "> $words[$k] </font> "; 
	    print HTMOUT "</b> " if $bold;
	}
	print HTMOUT "<br>\n";
	print HTMOUT "${evalSysId}[$bestid]: $nbest[$bestid] <br>\n" if $bestid;
	my $refid = 1;
	foreach $reftrans (@refObjs) {
	    print HTMOUT "Ref${refid}. $reftrans <br>\n";
	    $refid++;
	}
    }

    # update block, doc, and global (across all docs) stats:
    $totHypWords          += $numW;
    $closestRefWords      += $closestRefW;
    $docHypWords          += $numW;
    $docClosestRefWords   += $closestRefW; 
    $blcHypWords          += $numW;
    $blcClosestRefWords   += $closestRefW;

    for (my $j = 1; $j <= $ngrSize; $j++) {
	$numNgrams[$j]    += $numW - $j + 1 if $numW >= $j;
	$docNumNgrams[$j] += $numW - $j + 1 if $numW >= $j;
	$blcNumNgrams[$j] += $numW - $j + 1 if $numW >= $j;
    }

    for (my $i = 1; $i < @counts; $i++) {
	$ngrMatches[$i]    += $counts[$i];
	$docNgrMatches[$i] += $counts[$i];
	$blcNgrMatches[$i] += $counts[$i];
    }
    
    print STDERR "doc=$docId, seg=$hypNum, BLEUr", 0 + @refids, " = $segbleu\n" if $dbgLevel;
    for (my $i = $startNgr; $i < @ngrMatches; $i++) {
	if ($numNgrams[$i]) {
	    $ngrPrecision[$i] = $ngrMatches[$i]/$numNgrams[$i];
	} else {
	    $ngrPrecision[$i] = 1; # by convention
	}

	if ($docNumNgrams[$i]) {
	    $docNgrPrecision[$i] = $docNgrMatches[$i]/$docNumNgrams[$i];
	} else {
	    $docNgrPrecision[$i] = 1; # by convention
	}

	if ($blcNumNgrams[$i]) {
	    $blcNgrPrecision[$i] = $blcNgrMatches[$i]/$blcNumNgrams[$i];
	} else {
	    $blcNgrPrecision[$i] = 1; # by convention
	}
    }

    if (($blockSz > 1) && ($hypNum % $blockSz) == 0) {
	$blcId++;
	push(@blcBleus, &ReportBlockStats());
	&ResetBlockStats();
    }

    return 1;
}

# Penalize the mismatch between the candidate's length and the reference length.
# argument is hyp2rLen which is the ratio of the length of the hypothesis to that
# of the reference that is closest in length to the hypothesis.
# The penalty is multiplicative. 
sub BrevityPenalty {
    my $r2hLen = shift;
    # penalize only if hypothesis is less than closest reference in length
    return 1 if $r2hLen < 1.0;
    return exp(1 - $r2hLen);
}

# convert a string to an ngram hash, counting the number of occurrences of each ngram.
# Return the total number of words in the string.
sub Str2Ngrams {
    my ($strPtr, $hashPtr) = @_;
    my @words = split(/\s+/, $$strPtr);
    my $ignored = 0;
    for ($i = 0; $i < @words; $i++) {
	if (defined($ignoreList{$words[$i]})) {
	    $ignored++;
	    next;
	}
	my $phr;
	for ($j = 0; $j < $ngrSize; $j++) {
	    last unless $i + $j < @words;
	    next if defined($ignoreList{$words[$i+$j]});
	    $phr .= $words[$i+$j] . " ";
	    $$hashPtr{$phr}++;	    
	}
    }
    return @words - $ignored;
}

# Some simple processing of the translations. Lowercasing is the main aspect.
# (Are we being too liberal by comparing translations after lowercasing?)
# Numbers in numeric form are rendered differently by some commercial systems, 
# so normalize the spacing conventions in numbers.
# There is no end to text normalization. For example, "1" and "one" are the same,
# aren't they? Before going ballistic, let us recall the "Keep It Simple" Principle.
sub NormalizeText {
    my $strPtr = shift;

# language-independent part:
    $$strPtr =~ s/^\s+//;
    $$strPtr =~ s/\n/ /g; # join lines
    $$strPtr =~ s/(\d)\s+(\d)/$1$2/g;  #join digits

# language-dependent part (assuming Western languages):
    $$strPtr =~ tr/[A-Z]/[a-z]/ unless $casesensitive;
    # $$strPtr =~ s/([^A-Za-z0-9\-\'\.,])/ $1 /g; # tokenize punctuation (except for alphanumerics, "-", "'", ".", ",")
    $$strPtr =~ s/([\{-\~\[-\` -\&\(-\+\:-\@\/])/ $1 /g;   # tokenize punctuation
    $$strPtr =~ s/([^0-9])([\.,])/$1 $2 /g; # tokenize period and comma unless preceded by a digit
    $$strPtr =~ s/([\.,])([^0-9])/ $1 $2/g; # tokenize period and comma unless followed by a digit
    $$strPtr =~ s/([0-9])(-)/$1 $2 /g; # tokenize dash when preceded by a digit
    $$strPtr =~ s/\s+/ /g; # one space only between words
    $$strPtr =~ s/^\s+//;  # no leading space
    $$strPtr =~ s/\s+$//;  # no trailing space
    my $ascii = "\x20-\x7F";
    $$strPtr =~ s/([^$ascii])\s+([^$ascii])/$1$2/g; # combine sequences of non-ASCII characters into single words
    # debug
    # print $$strPtr, "\n";
}

# Given a matrix as an array of arrays, determine if every row has the
# same number of columns or not. Used in this script to check if parallel files
# have the same number of lines.
sub QEveryRowHasSameNumberOfColumns {

    # return the number of columns, if all rows have the same number of columns
    # return 0 else

    my $matPtr   = shift;
    my $numRows  = @$matPtr;
    my $prevNumCols = 0 + @{$$matPtr[0]};
    for ($i = 1; $i < $numRows; $i++) {
	return 0 if ($prevNumCols != 0 + @{$$matPtr[$i]});
    }
    return $prevNumCols;
}

# For pretty printing of numbers.
sub Trunc {
    my $num = shift;
    $num += 0.00005 if $num != int($num);
    $num =~ s/\.(\d{4}).*/.$1/ unless $num =~ /e/;
    return $num;
}

# Prepare weights to be used in the metric. 
# Keep It Simple Principle: equal weights
sub GetWeights {
    my $sum = 0;
    for ($i = $startNgr; $i <= $ngrSize; $i++) {
	$wt[$i] = 1.0;
	$sum += $wt[$i];
    }
# make the weights convex
    for ($i = $startNgr; $i <= $ngrSize; $i++) {
	$wt[$i] /= $sum;
    }
}

# Read all SGM files
# Each sgm file is a sequence of documents. Each document is a
# sequence of units such as "paragraphs".
# A unit is enclosed in <segment> and </segment>
# <segment> can have optional attribute called seg_Id. E.g.
# <segment seg_ID="23"> blahblah </segment>
# If there is a mismatch in the number of lines in parallel files, the unit becomes 
# the whole file. 
# Recommendation while preparing references and test material: 
# Select paragraphs as units. 
# Reason: translators usually honor paragraph boundaries but occasionally break or
# merge sentences within a paragraph. Aligning references by sentences is painful
# and is not worth it since scoring BLEU at the paragraph level is just fine.
sub ReadAllSGMFiles {

    if ($srcsgmFileName) {
	$src_id = &ReadAllDocs($srcsgmFileName, \%srcDoc, \@srcids, \@srcdocids);
    }

    my $sys_Id = &ReadAllDocs($testsgmFileName, \%hypDoc, \@testids, \@hypdocids);
    die "sysid tag missing in document markup in $testsgmFileName\n" unless $sys_Id;
    if ($evalSysId eq "") {
       print STDOUT "Systems seen: @testids. Evaluating $sys_Id\n";
       print STDOUT "If you want to evaluate another system, specify the system by the -sys option\n" if @testids > 1;
       $evalSysId = $sys_Id unless $evalSysId;
    }

    %evalDoc = %{$hypDoc{$evalSysId}};
    $toDoc   = @hypdocids -1 unless $toDoc && $toDoc < @hypdocids;
    $fromDoc = 0 unless $fromDoc && $fromDoc < @hypdocids;
    @tmpids = splice(@hypdocids, $fromDoc, $toDoc-$fromDoc+1);
    @hypdocids = @tmpids;

    my @tmpdoclist;
    &ReadAllDocs($refsgmFileName, \%refDoc, \@refids, \@tmpdoclist);
    print STDERR "Will evaluate docs from (0-based) doc $fromDoc to ";
    if ($toDoc) {
      print STDERR "doc $toDoc\n";
    } else {
      print STDERR "the end\n";
    }

    my $numSegs = &CountSegsToScore();

    print STDERR "Will evaluate $numSegs segments\n" if $dbgLevel;
    my $desiredSampleSz = 50;
    $desiredSampleSz = 20 if $numSegs < 250;
    $sampleSz = $desiredSampleSz;
    $sampleSz = $numSegs if $numSegs < $desiredSampleSz;
    $blockSz = int($numSegs / $sampleSz + 0.5);
    print STDERR "Confidence interval will be computed with a sample size of $sampleSz\n";# if $dbgLevel;
    return;
}

# This function supports sgm-marked up docs in one single file
# The parallel docs are already read in, each doc as a single string.
# Break up the string into units and complain if mismatch in units.
sub SegmentNextParallelDoc {
    &ReportDocStats() if $dbgLevel;
    &ResetDocStats();
    return 0 unless @hypdocids > 0;

    # what does "next" mean?
    $docId = shift(@hypdocids);

    my $hypstr = $evalDoc{$docId};
    @hyplines = &GetUnits($hypstr);
    if ($srcsgmFileName) {
	$srcstr = ${$srcDoc{$srcids[0]}}{$docId};
	@srclines = &GetUnits($srcstr);
    }

    if ($bestout) {
	print BESTOUT "</DOC>\n" if $hypNum;
	print BESTOUT "<DOC docid=\"$docId\" sysid=\"nbest\">\n";
    }

    $refNum = 0;
    @reflines = ();

    foreach $refId (@refids) {
        my %thisrefdocs      = %{$refDoc{$refId}};
	if (defined($thisrefdocs{$docId})) {
	    my $thisrefstr = $thisrefdocs{$docId};
	    my @lines = &GetUnits($thisrefstr);
	    push @reflines, [ @lines ];
	    $refNum++;
	    print STDERR "Mismatched lines for doc $docId: $refId:test = ", 0 + @lines, ":", 0 + @hyplines, "\n" unless @hyplines == @lines;
  	}
    }    
    print STDERR "$refNum reference translations found for doc $docId\n" if $dbgLevel;
    if ($refNum == 0) {
	die "ERROR: No reference translations for doc $docId\n";
    }
    return 1;
}


# Count the segments to be scored. Used in computing the sample size for confidence intervals. 
sub CountSegsToScore {
    my $nsegs = 0;
    my %refdocs = %{$refDoc{$refids[0]}};
    foreach my $docId (@hypdocids) {
	my $refstr = $refdocs{$docId};
	$nsegs += &GetUnits($refstr);
    }
    print STDERR "Will score $nsegs segments\n" if $dbgLevel;
    return $nsegs;
}


sub PrintUsage {
    print "\nUSAGE: perl $scriptName -t <test_file> -r <referece_file> [-s src_file] [-html htmlout] [-d dbglevel] [-n ngram_size] [-sys system2test] [-from docNum] [-to docNum] [-ci] [-nbest n] [-bestout bestout] [-nbestout nbestout] [-ignore wordlistfile]\n";
    print "\t   By default ngram_size is 4 so that 1-, 2-, 3-, and 4-grams are matched.\n";
    print "\t   By default matching will be cAsE-sEnSiTiVe\n";
    exit;
}

sub GetUnits {
    my $str = $_[0];
    my @units;
    while ($str =~ s,<seg.*?>(.*?)</seg.*?>,,i) {  
	push(@units, $1);
    }
    return @units;
}

sub ResetBlockStats {
    $blcHypWords     = 0;
    $blcClosestRefWords = 0;
    for (my $j = 1; $j <= $ngrSize; $j++) {
	$blcNumNgrams[$j] = 0;
    }

    for (my $i = 1; $i < @ngrMatches; $i++) {
	$blcNgrMatches[$i] = 0;
    }
}

sub ResetDocStats {
    $lineNum = 0;
    $docHypWords     = 0;
    $docClosestRefWords = 0;
    for (my $j = 1; $j <= $ngrSize; $j++) {
	$docNumNgrams[$j] = 0;
    }

    for (my $i = 1; $i < @ngrMatches; $i++) {
	$docNgrMatches[$i] = 0;
    }
}

sub ReportBlockStats {
    return unless $blcHypWords;
    $fh = 0;
    $fh = STDOUT if $dbgLevel > 5;
    print $fh "blockNum,$blcId\n";
    print $fh "SegsScored,$blockSz\nSysWords,$blcHypWords\n";
    my $lenRatio = $blcClosestRefWords / $blcHypWords;
    return &ReportMetrics($fh, $blcClosestRefWords, $blcHypWords, \@blcNgrPrecision);
}

sub ReportDocStats {
    return unless $docHypWords;
    print STDOUT "doc_Id,$docId\n";
    print STDOUT "SegsScored,$lineNum\nSysWords,$docHypWords\n";
    my $lenRatio = $docClosestRefWords / $docHypWords;
    &ReportMetrics(STDOUT, $docClosestRefWords, $docHypWords, \@docNgrPrecision);
}

sub ReadAllDocs {
    my ($fn, $hashptr, $arrptr, $doclistptr) = @_;
    open(FIL, $fn) or die "Cannot read file $fn: $!";
    
    #read till the first <DOC"; #"
    while (<FIL>) {
	last if /<DOC /i;
    }
    
    m/doc_?ID=\"(.*?)\".*sys_?ID=\"(.*?)\"/i; #"
    my $doc_Id  = $1;
    my $sys_Id  = $2;
    my $docstr = "";

    # read each doc into a single line and store 
    my $numDocs = 0;
    while (<FIL>) {
	s/[\n\r]+/ /g;  
	if (/<DOC\s+doc_?ID=\"(.*?)\".*sys_?ID=\"(.*?)\"/i) { #"
	    ${$$hashptr{$sys_Id}}{$doc_Id} = $docstr; #
	    push(@$doclistptr, $doc_Id);

	    $doc_Id = $1;
            $sys_Id = $2;
            $docstr = "";
            $numDocs++;
            next;
         }
         $docstr .= "$_ ";
     }
     close(FIL);
     ${$$hashptr{$sys_Id}}{$doc_Id} = $docstr; #
     push(@$doclistptr, $doc_Id);
     $numDocs++;

     @$arrptr = sort keys %$hashptr;
     foreach my $id (@$arrptr) {
        my %thissysdocs      = %{$$hashptr{$id}};
	@thissysdocids = sort keys %thissysdocs;
	print STDERR "$id: Number of docs = ", 0 + @thissysdocids, "\n";
	print STDERR "@thissysdocids\n\n"  if $dbgLevel > $ngrSize + 1;
     }

    return $sys_Id;
}

sub CalcConfidenceInterval() {
    my $m = @blcBleus;
    if ($m < 2) {
	print STDOUT "Test set too small. Zero confidence in the number reported below.\n";
	return;
    }

    my $samplemean =  0;
    for (my $i = 0; $i < $m; $i++) {
	$samplemean += $blcBleus[$i];
	print STDERR "bleu = $blcBleus[$i]\n" if $dbgLevel > 5;
    }
    $samplemean /= $m;

    my $samplevar = 0;
    for (my $i = 0; $i < $m; $i++) {
	$samplevar += ($blcBleus[$i] - $samplemean) * ($blcBleus[$i] - $samplemean);
    }
    
    $samplevar /= ($m - 1);

    my $stderror = sqrt($samplevar / $m);
    my $df = $m-1;  # degrees of freedom
    $df = @ttable - 1 if $df >= @ttable;
    my $t = $ttable[$df];

    print STDERR "AveBleu on blocks = $samplemean, Sample Variance = $samplevar, t=$t\n" if $dbgLevel;
#    print STDERR "Confidence interval = (", $samplemean - $t * $stderror, ", ", $samplemean + $t * $stderror, ")\n";
    my $dev = &Trunc($t * $stderror);
    print STDOUT "Add -$dev and +$dev to BLEU below for 95% confidence level\n";
}

sub SegBleu {
    my ($hypstr, $refngrPtr, $refszPtr, $countsPtr) = @_;
    my @words = split(/\s+/, $hypstr);
    my $ignored = 0;
    for (my $j = $ngrSize-1; $j >= 0; $j--) {
	my %hypngrs;
	for (my $i = 0; $i < @words; $i++) { # go through the hypothesis left to right.
	    if (defined $ignoreList{$words[$i]}) {
		$ignored++ unless $j;
		next;
	    }
	    last unless $i + $j < @words;
	    my $phr; # = join(" ", @words[$i..$i+$j]) . " ";
	    for (my $k = $i; $k <= $i+$j; $k++) {
		$phr .= "$words[$k] " unless defined $ignoreList{$words[$k]};
	    }
	    $hypngrs{$phr}++;
	}
	    
	foreach my $jgram (keys %hypngrs) {
	    my $c    = $hypngrs{$jgram};
	    my $refc = 0;
	    $refc = $$refngrPtr{$jgram} if defined $$refngrPtr{$jgram};
	    my $clip = $c;
	    $clip = $refc if $refc < $c;
	    $$countsPtr[$j+1] += $clip;
	}
    }


    my $numW  = @words - $ignored;        # number of "words" in the hypothesis
    
    my $closestRefW = 0;
    my $minDiffW    = 10000000;

    foreach my $thisRefW (@$refszPtr) {
	if (abs($numW - $thisRefW) <= $minDiffW) {
	    if (abs($numW - $thisRefW) == $minDiffW) { # fix bug found by Gregor Leusch
		$closestRefW = $thisRefW if ($closestRefW > $thisRefW); #compare to the shortest ref.
	    } else {
		$closestRefW = $thisRefW ;
	    }
	    $minDiffW    = abs($numW - $thisRefW);
	}
    }


    my $segNgrsz = $closestRefW;
    my @smoothedcounts = @$countsPtr;
    $segNgrsz = $ngrSize if $segNgrsz > $ngrSize;
    my $smooth = 1;
    for (my $i = 1; $i <= $segNgrsz; $i++) {
	next if $smoothedcounts[$i];
	$smooth *= 0.5;
	$smoothedcounts[$i] = $smooth;
    }

    my $wt = 1.0;
    $wt = 1.0 / $segNgrsz if $segNgrsz;
    my $segPrec = 0;
    for (my $i = 1; $numW && $i <= $segNgrsz; $i++) {
#	print STDERR "count-$i=$smoothedcounts[$i]\n";
	$segPrec += $wt * log($smoothedcounts[$i]/($numW - $i + 1)) if $numW-$i+1 > 0;
    }

    my $lpen = 0;
    $lpen = &BrevityPenalty( $closestRefW / $numW ) if $numW;
    my $segBleu = $lpen * exp($segPrec);
    return ($segBleu, $numW, $closestRefW);
}

sub PrintRankStats {
    print STDERR "rank\tcount\n";
    $averank = 0;
    for (my $i=0; $i < @rankstats; $i++) {
	$averank += $i * $rankstats[$i];
	print STDERR "$i\t$rankstats[$i]\n";
    }
    print STDERR "Average rank = ", $averank/$hypNum, "\n";
    print HTMOUT "<br>Average rank = ", $averank/$hypNum, "<br>\n" if $html;
}

sub ReadIgnoreWordList {
    open (IGN, $ignoreFileName) or return;
    while (<IGN>) {
	s/^\s+//;
	s/\s+$//;
	my @w = split(/\s+/, $_);
	foreach my $wrd (@w) {
	    $ignoreList{$wrd}++;
	}
    }

    if (scalar(keys %ignoreList)) {
	print STDERR "Will ignore the following words: ", join(" ", keys %ignoreList), "\n";
    }
}
