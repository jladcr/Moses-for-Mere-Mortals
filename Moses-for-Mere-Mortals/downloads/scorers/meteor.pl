#!/usr/local/bin/perl

# The METEOR automatic MT evaluation metric. See README.txt for more information.

# License Start:
#                    Carnegie Mellon University
#                      Copyright (c) 2004
#                       All Rights Reserved.
#
# Permission is hereby granted, free of charge, to use and distribute
# this software and its documentation without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of this work, and to
# permit persons to whom this work is furnished to do so, subject to
# the following conditions:
#  1. The code must retain the above copyright notice, this list of
#     conditions and the following disclaimer.
#  2. Any modifications must be clearly marked as such.
#  3. Original authors' names are not deleted.
#  4. The authors' names are not used to endorse or promote products
#     derived from this software without specific prior written
#     permission.
#
# CARNEGIE MELLON UNIVERSITY AND THE CONTRIBUTORS TO THIS WORK
# DISCLAIM ALL WARRANTIES WITH REGARD TO THIS SOFTWARE, INCLUDING
# ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO EVENT
# SHALL CARNEGIE MELLON UNIVERSITY NOR THE CONTRIBUTORS BE LIABLE
# FOR ANY SPECIAL, INDIRECT OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN
# AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION,
# ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF
# THIS SOFTWARE.
#
# Author: Satanjeev "Bano" Banerjee satanjeev@cmu.edu
# Author: Alon Lavie alavie@cs.cmu.edu
# Author: Abhaya Agarwal abhayaa@cs.cmu.edu
#
# License End.

# - Changed the --noStop behaviour
# - Added the ref tag to ref systems while storing
# - Store the normalized input in the allData thus
# saving on normalization function calls
# - Reorganize the readSGMLFile function to avoid the
# repeated code

use strict;
use Benchmark;
use mStageMatcher;    # multi stage matcher algorithm
use Getopt::Long;     # for processing the command line

use vars qw($alpha $beta $gamma);
use vars qw(%wnValidForms %wnSynsetOffsetHashes $wn);
use vars qw($opt_lang $opt_t $opt_r $opt_s $opt_noStop $opt_stop $opt_modules $opt_nBest $opt_outFile $opt_plainOutput $opt_keepPunctuation);

my %params = ();
$params{'en'} = '.8 .83 .28';
$params{'cs'} = '.8 .83 .28';
$params{'fr'} = '.76 .5 1';
$params{'es'} = '.95 .5 .75';
$params{'de'} = '.95 1 .98';

# If no options have been provided provide the usage notes
printUsage() if ( $#ARGV == -1 );

# If options have been provided, read them in
GetOptions( "lang=s", "t=s", "r=s", "s=s", "noStop", "stop=s", "modules=s", "nBest", "outFile=s", "plainOutput", "keepPunctuation");

######################################################################################
#####  Main routine to first handle the command line options, then drive the rest of
#####  the program.
######################################################################################

# What language are we working with
unless(defined $opt_lang){
	print "Assuming language to be English by default\n";
	$opt_lang = 'en';
}

# Check that we are only using modules available for the language and set the meteor parameters
if(lc($opt_lang) =~ /cs|czech/){
	$opt_modules = 'exact' unless(defined $opt_modules);
	if(($opt_modules =~ /\bwn_/ || $opt_modules =~ /\bporter_stem/)){
		die('wn_* and porter_stem modules not available for czech !');
	}
}
elsif(lc($opt_lang) =~ /^(fr|es|de|german|spanish|french)$/){
	$opt_modules = 'exact porter_stem' unless(defined $opt_modules);
	if($opt_modules =~ /\bwn_/){
		die('wn_* modules not available for French,German and Spanish !');
	}
}
elsif(lc($opt_lang) =~ /^(en|english)$/){
	$opt_modules = 'exact porter_stem' unless(defined $opt_modules);
}
else{
	die("$opt_lang is not supported !\n")
}

# Which modules are going to be run?
my @modules = ();
@modules = split /\s+/, $opt_modules;

($alpha, $beta, $gamma) = split /\s+/,$params{$opt_lang};

# Check that output options are consistent
die("plainOutput option used without providing output file name !")
  if ( ( defined $opt_plainOutput ) && ( !defined $opt_outFile ) );

# Do we have to use a stop word list?
my %stopHash     = ();
my $stopListFile = "";

if ( defined $opt_noStop ) {
    print
"--noStop switch is only present for backward compatibility. It has no effect whatsoever. The default behaviour of METEOR is now to use no stoplist. Please update your scripts as this option may be removed in future releases.";
}

if ( defined $opt_stop ) {
    $stopListFile = $opt_stop;
    print "Using $stopListFile as the stop list.\n";
}
# else {
#     print
# "\nWarning: The default behaviour of METEOR has changed. No stoplist is used by default now. If you want to use a stoplist, please use --stop switch.\n";
# }

if ( $stopListFile ne "" ) {
    open( STOP, $stopListFile ) || die "Couldn't open stop file $opt_stop - aborting.\n";
    while (<STOP>) {
        chomp;
        s/\s//g;    # get rid of all the random \n, \r stuff that chomp didn't get rid of
        $stopHash{$_} = 1;
    }
    close(STOP);
}

# Check the list of modules to see if we need to initialize WordNet
foreach (@modules) {
    if (/^wn_/) {    # WordNet based modules are assumed to start with "wn_"
                     # include Jason Rennie's perl module that will interface with WordNet
        require WordNet::QueryData;

        # create a WordNet object, this will later be put in the input hash
        $wn = WordNet::QueryData->new;

        #Let us also create wn caches
        %wnValidForms         = ();
        %wnSynsetOffsetHashes = ();
        last;
    }
}

# Initialize data structures that will hold all reference and hypothesis files
# Data structure for references and hypotheses:
#
# Outer hash: key = "docid::segid", value = inner hash
# Inner hash: key = "ref-name/hyp-name", value = ref/hyp
# This should be able to handle any number of references as well as any number of hypotheses!

my %allData = ();    # all the hypothesis and reference strings
my %systemIDs   = ();    # all the automatic system ids (found in the testing file)
my %humanRefIDs = ();    # all the reference ids (found in the reference file)

# Next read in the test and reference files, abort if not supplied
# The second last parameter is to indicate if the nbest tag is present in
# the file or not. Last parameter is a string that is attached to the
# system names thus avoiding confusion between test and ref systems.
# print "Going to read test file\n";
if ( defined $opt_t ) {
    if ( defined $opt_nBest ) {
        readSGMfile( $opt_t, \%allData, \%systemIDs, 1, "" );
    }
    else {
        readSGMfile( $opt_t, \%allData, \%systemIDs, 0, "" );
    }
}
else {
    print "Please specify a test file using the -t option.\n";
    printUsage();
}

# print "Going to read ref file\n";
if ( defined $opt_r ) {
    readSGMfile( $opt_r, \%allData, \%humanRefIDs, 0, "ref" );
}
else {
    print "Please specify a reference file using the -r option.\n";
    printUsage();
}

# Check if provided system id belongs to the list of system ids found
my $givenSystemID = "";
if ( defined $opt_s ) {
    $givenSystemID = $opt_s;
}
else {
    print "Please specify a system id using the -s option.\n";
    printUsage();
}

die "Input system id not found in given test file\n"
  unless ( defined $systemIDs{$givenSystemID} );

# Check the data for holes. That is, check to ensure that every
# document::seg-id pair has exactly one sentence from each of the
# system ids as well as the human ids
if ( !( dataComplete( \%allData, \%systemIDs, \%humanRefIDs ) ) ) {
    print "Data looks incomplete - aborting.\n";
}

# Print out the options being used
print STDERR "Language: $opt_lang\n";
print STDERR "modules: $opt_modules\n";

# # debug printing
# print "The system ids are:\n";
# foreach my $systemID (sort keys %systemIDs) {
#   print "    $systemID\n";
# }
# print "The human reference ids are:\n";
# foreach my $humanRefID (sort keys %humanRefIDs) {
#   print "    $humanRefID\n";
# }

# now score each hypothesis
my $numSegmentsScored = 0;
# print "\nProcessing:\n";

# Let us time outselves
my $start_time = new Benchmark;
# print "Going to compute scores\n";
my %aggregateScoresHash = getSystemWideScore( \$numSegmentsScored, %allData);

my $end_time = new Benchmark;
print "Time taken was ", timestr( timediff( $end_time, $start_time ), 'all' ), " seconds.\n";

# print overall output
unless ( defined $opt_nBest ) {
    print "Overall system score:\n";
    print getLogString(%aggregateScoresHash);
    print "Number of segments scored: $numSegmentsScored\n\n";
}

# done!!

######################################################################################
#####  Sub: getSystemWideScore(%allData)
#####
#####  Subroutine to compute hypothesis by hypothesis score, and from those, the
#####  overall system score
######################################################################################

sub getSystemWideScore {
    my $numSegmentsScoredRef = shift;
    my %allData              = @_;
    
    # initialize necessary overall (system wide) metrics
    my %aggregateScoresHash = ();
    unless ( defined $opt_nBest ) {
        $aggregateScoresHash{"totalMatches"} = 0;
        $aggregateScoresHash{"numChunks"}    = 0;
        $aggregateScoresHash{"hypLength"}    = 0;
        $aggregateScoresHash{"refLength"}    = 0;
    }
    ${$numSegmentsScoredRef} = 0;
    
    # print matcher output to log file
#      open(OFILE,">$givenSystemID-output") or die("Could not open output file !");

    my @sortedkeys = sort {    # This function sorts the segments of a doc in correct order
        my @akey = split /::/, $a;
        my @bkey = split /::/, $b;
        if ( $akey[0] eq $bkey[0] ) {
            return $akey[1] <=> $bkey[1];
        }
        else {
            return $akey[0] cmp $bkey[0];
        }
    } keys %allData;

    # now go through every segment in every document.
    foreach my $outerKey (@sortedkeys) {
        die "Internal error during scoring hypothesis\n"
          unless ( $outerKey =~ /(.*)::(.*)/ );
        my $documentID = $1;
        my $segmentID  = $2;

#         print "Document: $documentID, Segment: $segmentID\n";

        my @hyps = "";
        if ( defined ${ $allData{$outerKey} }{$givenSystemID} ) {
            @hyps = @{ ${ $allData{$outerKey} }{$givenSystemID} };
        }
        else {
            die "Could not find hypothesis translation for document $documentID, segment $segmentID\n";
        }
        @{ ${ $allData{$outerKey} }{"score"} } = ();
        foreach my $hypothesis (@hyps) {

            # now compute the best score for this hypothesis, across all the references
            my %bestScore = ();
            my %bestFeatures = ();

            # compare the hypothesis translation with each reference translation.
            foreach my $referenceID ( sort keys %humanRefIDs ) {

                # we will compute a whole bunch of metrics after comparing the
                # hyp witth this particular reference. We'll put them all into the
                # "scoresHash"
                my %scoresHash = ();

                my $reference = "";
                if ( defined ${ $allData{$outerKey} }{$referenceID} ) {
                    $reference = ${ $allData{$outerKey} }{$referenceID}[0];
                }
                else {
                    die
"Could not find reference translation with reference ID $referenceID in document $documentID, segment $segmentID\n";
                }

                # use mStageMatcher.pm to do the string matching
                # mStageMatcher.pm takes a hash as input. Construct the hash.
                my %inputHash = ();

		# Set the language
		$inputHash{"language"}  = $opt_lang;
		
                # put in the two strings
                $inputHash{"firstString"}  = $hypothesis;
                $inputHash{"secondString"} = $reference;
		
                # set maxComputations
                $inputHash{"maxComputations"} = 10000;

                # put in the modules array
                @{ $inputHash{"modules"} } = @modules;    # this array comes from the commandline

                # pass in stop hash (maybe an empty one!)
                %{ $inputHash{"stop"} } = %stopHash;

                # Make sure pruning is set to "on"
                $inputHash{"prune"} = 1;

                # put in the detail flag to find out number of computations being done
                $inputHash{"details"} = 0;

                # if $wn is defined, send the WordNet object along
                if ( defined $wn ) {
                    $inputHash{"wn"}                   = $wn;
                    $inputHash{"wnValidForms"}         = \%wnValidForms;
                    $inputHash{"wnSynsetOffsetHashes"} = \%wnSynsetOffsetHashes;
                }

                # Now call the actual matching function (this is defined in mStageMatcher.pm
                match( \%inputHash );

                # Count up the total number of matches across all the stages
                $scoresHash{"totalMatches"} = 0;
                for ( my $i = 0 ; $i <= $#{ $inputHash{"matchScore"} } ; $i++ ) {
                    my $numMatches = ${ $inputHash{"matchScore"} }[$i][0];
                    my $numFlips   = ${ $inputHash{"matchScore"} }[$i][1];
                    $scoresHash{"totalMatches"} += $numMatches;
                }

                # print the num chunks and avg chunk lengh
                $scoresHash{"numChunks"} = $inputHash{"numChunks"};

                #       print "  Reference: $referenceID, ";
                #       print "Matches found: " . $scoresHash{"totalMatches"} . ", ";
                #       print "Chunks found: " . $scoresHash{"numChunks"} . "\n";

                # get the lengths of the two strings
                $scoresHash{"hypLength"} = $inputHash{"sizeOfFirstString"};
                $scoresHash{"refLength"} = $inputHash{"sizeOfSecondString"};

                # compute the score and all the other metrics for this scores hash
                # for this hypothesis - reference pair
                # When total matches == 0, then score is defined to be 0, and all
                # other measures are undefined.
                computeMetrics( \%scoresHash );

                # update info for best score, if need be
                if ( ( !( defined $scoresHash{"score"} ) ) || ( $scoresHash{"score"} >= $bestScore{"score"} ) ) {
                    %bestScore = %scoresHash;
                    $bestScore{"bestRef"} = $referenceID;
                    $bestScore{"detailString"} = $inputHash{"detailString"};
# 		print "$hypothesis\n$reference\nScore: $bestScore{'score'}\n";
# 		my $wait = <STDIN>;
		}
            }

            # Collect the score
            push @{ ${ $allData{$outerKey} }{"score"} }, $bestScore{"score"};
            push @{ ${ $allData{$outerKey} }{"precision"} }, $bestScore{"precision"};
            push @{ ${ $allData{$outerKey} }{"recall"} }, $bestScore{"recall"};
            push @{ ${ $allData{$outerKey} }{"frag"} }, $bestScore{"frag"};
            push @{ ${ $allData{$outerKey} }{"hypLength"} }, $bestScore{"hypLength"};

	    # Remove the prefix and store the ref id
            $bestScore{"bestRef"} =~ /ref(.*)/;
            push @{ ${ $allData{$outerKey} }{"bestRef"} }, $1;

            unless ( defined $opt_nBest ) {

                # update aggregate statistics
                $aggregateScoresHash{"totalMatches"} += $bestScore{"totalMatches"};
                $aggregateScoresHash{"numChunks"}    += $bestScore{"numChunks"};
                $aggregateScoresHash{"hypLength"}    += $bestScore{"hypLength"};
                $aggregateScoresHash{"refLength"}    += $bestScore{"refLength"};
            }
            ${$numSegmentsScoredRef}++;
        }
    }

    if ( defined $opt_outFile ) {
        unless ( defined $opt_plainOutput ) {
            writeResultsInFile( $opt_t, $opt_outFile, $givenSystemID, \%allData, 0 ) unless defined $opt_nBest;
            writeResultsInFile( $opt_t, $opt_outFile, $givenSystemID, \%allData, 1 ) if defined $opt_nBest;
        }
        else {
            open( resfile, ">$opt_outFile" );
            foreach my $outerKey (@sortedkeys) {
                my @scores = @{ ${ $allData{$outerKey} }{"score"} };
                if ( defined $opt_nBest ) {
                    my $nBestCount = 0;
                    foreach my $score (@scores) {
                        $nBestCount += 1;
                        print resfile "$outerKey\:\:$nBestCount ${${$allData{$outerKey}}{\"score\"}}[$nBestCount-1]\n";
                    }
                }
                else {
                    print resfile "$outerKey ${${$allData{$outerKey}}{\"score\"}}[0]\n";
                }
            }
        }
    }

    # unless the input is n-best format, compute metrics over the aggregate scores
    computeMetrics( \%aggregateScoresHash ) unless defined($opt_nBest);
    return (%aggregateScoresHash);
}

# subroutine to compute all score metrics, given totalMatches, chunks,
# hypLength and refLength
sub computeMetrics {
    my $scoresHashRef = shift;

    if ( ${$scoresHashRef}{"totalMatches"} == 0 ) {
        ${$scoresHashRef}{"score"} = 0;
    }
    else {

        # compute precision, recall, f1 and fmean
        ${$scoresHashRef}{"precision"} = ${$scoresHashRef}{"totalMatches"} / ${$scoresHashRef}{"hypLength"};
        ${$scoresHashRef}{"recall"}    = ${$scoresHashRef}{"totalMatches"} / ${$scoresHashRef}{"refLength"};
        ${$scoresHashRef}{"f1"}        = 2 * ${$scoresHashRef}{"precision"} * ${$scoresHashRef}{"recall"} /
          ( ${$scoresHashRef}{"precision"} + ${$scoresHashRef}{"recall"} );
	
	${$scoresHashRef}{"fmean"} = 1 / ( ( (1 - $alpha) / ${$scoresHashRef}{"precision"} ) + ( $alpha / ${$scoresHashRef}{"recall"} ) );
        # compute fragmentation and penalty
        if ( ${$scoresHashRef}{"totalMatches"} ==  ${$scoresHashRef}{"hypLength"} && 
		${$scoresHashRef}{"totalMatches"} ==  ${$scoresHashRef}{"refLength"} &&
		${$scoresHashRef}{"numChunks"} == 1) {
	# Special check to handle the case when the hypothesis and reference are identical.
            ${$scoresHashRef}{"frag"}    = 0;
        }
        else {
            ${$scoresHashRef}{"frag"} = ${$scoresHashRef}{"numChunks"} / ${$scoresHashRef}{"totalMatches"};
        }
        
        ${$scoresHashRef}{"penalty"} = $gamma * ( ${$scoresHashRef}{"frag"}**$beta );

        # compute score based on fmean fragmentation and pentaly.
        ${$scoresHashRef}{"score"} = ${$scoresHashRef}{"fmean"} * ( 1 - ${$scoresHashRef}{"penalty"} );
    }
}

# Write the sgm file populated with scores and ref ids
sub writeResultsInFile {
    my $testFile      = shift;
    my $outFile       = shift;
    my $givenSystemID = shift;
    my $allDataRef    = shift;
    my $isNBest       = shift;

    open( resfile, ">$outFile" );

    # Let us read the test file again and insert the scores whereever available
    open( FILE, $testFile ) || die "Couldn't open $testFile\n";
    my $currentDocID  = "";
    my $currentSysID  = "";
    my $lastAutoSegID = "";

    while ( my $line = <FILE> ) {
        if ( $line =~ /<DOC/i ) {
            if ( $line =~ /docid=\"(.*?)\"/i ) {
                $currentDocID = $1;
            }
            else {
                die "Couldn't read document id from line: $line\n";
            }
            if ( $line =~ /sysid=\"([^\"]*)/i ) {
                $currentSysID = $1;
            }
            else {
                die "Couldn't read system id from line: $line\n";
            }

            $lastAutoSegID = 0;
            print resfile $line;
            next;
        }

        if ( $line =~ /<\/DOC>/i ) {
            print resfile $line;
            next;
        }

        my $currentSegID = 0;
        if ( $line =~ /<\s*seg\s*id\s*=\s*\"?\s*(\d+)\s*\"?\s*>/i ) {
            $currentSegID = $1;
        }
        elsif ( $line =~ /<\s*seg\s*>/i ) {
            $currentSegID = $lastAutoSegID + 1;
            $lastAutoSegID++;
        }
        else {
            print resfile $line;
            next;
        }

        # Collect all the data of this seg
        while ( ( $line !~ /<\s*\/seg\s*>/i ) && ( my $nextLine = <FILE> ) ) {
            $line .= $nextLine;
        }
        my $string = "";
        my $lineToMatch = $line;
        $lineToMatch =~ s/\s/ /g;

        # Extract the text
        if ( $lineToMatch =~ /<\s*seg.*?>(.*)<\s*\/seg\s*>/i ) {
            $string = $1;
        }
        else {
            die "Having trouble reading in the segment information from:\n$line\n";
        }

        # if not inside a document, something's gone wrong
        if ( $currentDocID eq "" ) {
            die "The following segment line in file $testFile seems to be outside a DOC block!: [$line]\n";
        }

        my $outerHashKey = $currentDocID . "::" . $currentSegID;

        # check if this system has been scored
        unless ( defined @{ ${$allDataRef}{$outerHashKey} }{$currentSysID} ) {
            print resfile $line . "\n";
            next;
        }

        # If the data was in n-best format, extract all the hyps for
        # this seg and push them seperately
        if ( $isNBest == 1 ) {

            # So now that we have allowed people to put in their nbest lists here,
            # let's parse them
            print resfile "<seg id=\"$currentSegID\">";
            my @hyps = split /<\/nbest>/, $string;

            foreach my $hyp (@hyps) {
                next if ( $hyp =~ /^\s*$/ );
                die("Input file is not in nBest format !")
                  unless ( $hyp =~ /<\s*nbest\s*rank\s*=\s*"?(\d+)"?\s*>(.*)/i );

                print resfile "<nbest rank=$1 score="
                  . ${ ${ ${$allDataRef}{$outerHashKey} }{"score"} }[ $1 - 1 ]
                  . " refID=\""
                  . ${ ${ ${$allDataRef}{$outerHashKey} }{"bestRef"} }[ $1 - 1 ]
                  . "\" >$2</nbest>\n";
            }
        }
        else {
            print resfile "<seg id=\"$currentSegID\" score="
              . ${ ${ ${$allDataRef}{$outerHashKey} }{"score"} }[0]
              . " ref=\""
              . ${ ${ ${$allDataRef}{$outerHashKey} }{"bestRef"} }[0]
              . "\" >$string";
        }
        print resfile "</seg>\n";
        next;
    }

    close(FILE);
    close resfile;
}

# subroutine to take a scoresHash as an input, and to return a string
# suitable for printing out to the log output
sub getLogString {
    my %scoresHash = @_;

    my @labels = (
        { "Score"         => "score" },
        { "Matches"       => "totalMatches" },
        { "Chunks"        => "numChunks" },
        { "HypLength"     => "hypLength" },
        { "RefLength"     => "refLength" },
        { "Precision"     => "precision" },
        { "Recall"        => "recall" },
        { "1-Factor"      => "f1" },
        { "Fmean"         => "fmean" },
        { "Penalty"       => "penalty" },
        { "Fragmentation" => "frag" }
    );

    my $outputString = "";
    foreach my $hash (@labels) {
        foreach my $label ( keys %{$hash} ) {
            my $value = ${$hash}{$label};
            $outputString .= $label;
            $outputString .= ": ";
            $outputString .=
              ( ( defined $scoresHash{$value} ) ? ( sprintf "%.7f", $scoresHash{$value} ) : "undefined" );
            $outputString .= "\n";
        }
    }

    return $outputString;
}

######################################################################################
#####  Sub: readSGMfile($fileName, $allDataRef, $idRef)
#####
#####  Subroutine to read in all the hypothesis/references in the file with the given
#####  "filename". Hypothesis data will be filled into the hash with the given reference
#####  "allDataRef" and all the system ids or human ids that are found in this file will
#####  be pushed into the hash with the given reference $idRef
#####
######################################################################################

sub readSGMfile {
    my $fileName   = shift;
    my $allDataRef = shift;
    my $idRef      = shift;
    my $isNBest    = shift;
    my $prefix     = shift;

    open(FILE, "<$fileName" ) || die "Couldn't open $fileName\n";
    my $currentDocID  = "";
    my $currentSysID  = "";
    my $lastAutoSegID = "";

    while ( my $line = <FILE> ) {
        # Example: <DOC docid="AFA20030101.5900" sysid="ahd">
        # Note: In Tides 2002 data, different systems had tags with different cases (docid vs
        # docID), so in all regexes below, do case insensitive matching (using the "i" flag)
        if ( $line =~ /<DOC/i ) {
            if ( $line =~ /docid=\"([^\"]*)\"/i ) {
                $currentDocID = $1;
            }
            else {
                die "Couldn't read document id from line: $line\n";
            }
            if ( $line =~ /sysid=\"([^\"]*)/i ) {
                $currentSysID = $prefix . $1;
            }
            else {
                die "Couldn't read system id from line: $line\n";
            }

            $lastAutoSegID = 0;

            # save the system id
            ${$idRef}{$currentSysID} = 1;
            next;
        }

        if ( $line =~ /<\/DOC>/i ) {
            $currentDocID  = "";
            $currentSysID  = "";
            $lastAutoSegID = 0;    # redundant with re-initialization within the if (/<DOC... block, but what the heck!
            next;
        }

        my $currentSegID = 0;

        # Example: <seg id=1> Izzet Ibrahim Meets Saudi Trade Official in Baghdad </seg>
        # note that it is possible that the opening and closing seg tags are on separate lines
        if ( $line =~ /<\s*seg\s*id\s*=\s*\"?\s*(\d+)\s*\"?\s*>/i ) {
            $currentSegID = $1;
        }
        elsif ( $line =~ /<\s*seg\s*>/i ) {

            # Example: <seg> Izzet Ibrahimi Meets </seg>
            # this is the situation when the files don't have seg-ids. In
            # this case, assume seg-ids start with 1 for a new document,
            # and then increase by 1 until the end of that document
            $currentSegID = $lastAutoSegID + 1;
            $lastAutoSegID++;
        }
        else {

            # Ignore everything else
            next;
        }

        # Collect all the data of this seg
        while ( ( $line !~ /<\s*\/seg\s*>/i ) && ( my $nextLine = <FILE> ) ) {
            $line .= $nextLine;
        }
        my $string = "";
        my $lineToMatch = $line;
        $lineToMatch =~ s/\s/ /g;

        # Extract the text
        if ( $lineToMatch =~ /<\s*seg.*?>(.*)<\s*\/seg\s*>/i ) {
            $string = $1;
        }
        else {
            die "Having trouble reading in the segment information from:\n$line\n";
        }

        # if not inside a document, something's gone wrong
        if ( $currentDocID eq "" ) {
            die "The following segment line in file $fileName seems to be outside a DOC block!: [$line]\n";
        }

        # otherwise, create the key, and push the data in!
        my $outerHashKey = $currentDocID . "::" . $currentSegID;
        @{ ${$allDataRef}{$outerHashKey} }{$currentSysID} = ()
          unless ( defined @{ ${$allDataRef}{$outerHashKey} }{$currentSysID} );

        # If the data was in n-best format, extract all the hyps for
        # this seg and push them seperately
        if ( $isNBest == 1 ) {

            # So now that we have allowed people to put in their nbest lists here,
            # let's parse them

            my @hyps = split /<\/nbest>/, $string;

            foreach my $hyp (@hyps) {
                next if ( $hyp =~ /^\s*$/ );
                die("Input file is not in nBest format !")
                  unless ( $hyp =~ /<\s*nbest\s*rank\s*=\s*"?(\d+)"?\s*>(.*)/i );
		my $normalizedString = normalizeText($2);
                push @{ ${ ${$allDataRef}{$outerHashKey} }{$currentSysID} }, $normalizedString;
            }
        }
        else {
            my $normalizedString = normalizeText($string);
            push @{ ${ ${$allDataRef}{$outerHashKey} }{$currentSysID} }, $normalizedString;
        }

        next;
    }
    close(FILE);
    close(PFILE);
}

# subroutine to go through the allData data structure to ensure that
# every document::segment-id pair has exactly one sentence for each of
# the system and human ref ids
sub dataComplete {
    my $allDataRef     = shift;
    my $systemIDsRef   = shift;
    my $humanRefIDsRef = shift;

    foreach my $outerKey ( sort keys %{$allDataRef} ) {
        die "Internal error during checking for data completeness\n"
          unless ( $outerKey =~ /(.*)::(.*)/ );
        my $documentID = $1;
        my $segmentID  = $2;

        foreach my $systemID ( keys %{$systemIDsRef} ) {
            if ( !( defined ${ ${$allDataRef}{$outerKey} }{$systemID} ) ) {
                die "No translation found from system $systemID for segment $segmentID in document $documentID\n";
            }
        }
    }

    return 1;
}

sub normalizeText {
    my ($norm_text) = @_;

    # language-independent part:
    $norm_text =~ s/<skipped>//g;    # strip "skipped" tags
    $norm_text =~ s/-\n//g;          # strip end-of-line hyphenation and join lines
    $norm_text =~ s/\n/ /g;          # join lines
    $norm_text =~ s/&quot;/"/g;      # convert SGML tag for quote to "
    $norm_text =~ s/&amp;/&/g;       # convert SGML tag for ampersand to &
    $norm_text =~ s/&lt;/</g;        # convert SGML tag for less-than to >
    $norm_text =~ s/&gt;/>/g;        # convert SGML tag for greater-than to <

    # language-dependent part (assuming Western languages):
    $norm_text = " $norm_text ";
    $norm_text =~ tr/[A-Z]/[a-z]/;
    
    if(defined $opt_keepPunctuation){
      $norm_text =~ s/([\{-\~\[-\` -\&\(-\+\:-\@\/])/ $1 /g;    # tokenize punctuation
      $norm_text =~ s/([^0-9])([\.,])/$1 $2 /g;                 # tokenize period and comma unless preceded by a digit
      $norm_text =~ s/([\.,])([^0-9])/ $1 $2/g;                 # tokenize period and comma unless followed by a digit
      $norm_text =~ s/([0-9])(-)/$1 $2 /g;                      # tokenize dash when preceded by a digit
      $norm_text =~ s/[_#]/ /g;                                 # We remove _ & # since wn is not able to handle them.
    }
    else{
      if($opt_lang eq 'en'){
      	$norm_text =~ s/[^a-z0-9 ]/ /g; #KS 200204		# only keep the alpha-numeric parts
      }
      else{
      	$norm_text =~ tr/[A-Z]/[a-z]/;
	$norm_text =~ s/[^a-z0-9\x{00C0}-\x{00FF}' ]/ /g;
	$norm_text =~ s/(\s+)'(\s+)/ /g;
      }
    }
    $norm_text =~ s/\s+/ /g;                                  # one space only between words
    $norm_text =~ s/^\s+/ /;                                   # no leading space
    $norm_text =~ s/\s+$/ /;                                   # no trailing space

    return $norm_text;
}

# Subroutine to look for the default stop list file in the directories in the @INC.
sub findStopListFile {
    my $stopListFileName = shift;
    foreach my $dir (@INC) {
        if ( -e "$dir/$stopListFileName" ) {
            return "$dir/$stopListFileName";
        }
    }
    return "";
}

# Subroutine to print the usage notes for this program.
sub printUsage {
    print
"\nUSAGE: perl meteor.pl -s <system2test> -t <test_file> -r <reference_file> [-lang <language>] [--modules module1 [module2...]] [--stop FILE] [--nBest] [-o <output_file>] [--plainOutput]\n\n";
    print "Supported Languages:\n";
    print "English(en), French(fr), German(de), Spanish(es), Czech(cs)\n\n";
    print "Modules can be any combination of (Not all modules are available for every language):\n";
    print "exact\t\tmatching using surface forms\t\t\t\tall\n";
    print "porter_stem\tmatching using stems obtained from porter stemmer\tall but czech\n";
    print "wn_stem\t\tmatching using stems obtained from WordNet stemmer\tonly en\n";
    print "wn_synonymy\tmatching based on synonyms obtained from WordNet\tonly en\n\n";
    print "Input/Output Format Options:\n";
    print "nBest\t\tIndicates that input file is in n-best format.\n";
    print
"plainOutput\tOutput file contains no sgml but only scores, one per line. Without this option,\n\t\tthe output is a sgm file like the input, with scores attached to each segment.\n\n";
    print
"Warning: Starting with version 0.6, parameters of Meteor have changed. So scores obtained with versions 0.6 and onward are not comparable to older scores.\n\n";
    print
"Warning: Starting with version 0.5, default behaviour for stoplists have changed. Default now is to use no stoplist. --noStop option is redundant.\n\n";
    exit;
}
