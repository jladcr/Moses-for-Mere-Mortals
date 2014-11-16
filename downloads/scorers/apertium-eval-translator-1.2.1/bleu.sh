#!/bin/sh

SRC=$1
REF=$2
TEST=$3

if [[ $# -ne 3 ]]
then
  echo "Error: Wrong number of parameters"
  echo "USAGE: bleu.sh source reference test"
  exit 1
fi

function gen_xml_file {
  # $1=infile
  # $2=tstset|srcset|refset
  # $3=outfile
  # $4=sysid

  echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" > $3
  echo "<!DOCTYPE mteval SYSTEM \"ftp://jaguar.ncsl.nist.gov/mt/resources/mteval-xml-v1.3.dtd\">" >> $3
  echo "<mteval>" >> $3

  echo "<"$2" setid=\"mteval-01\" srclang=\"Source\" trglang=\"Target\" refid=\""$4"\" sysid=\""$4"\">" >> $3
  
  echo "<doc docid=\"01\" genre=\"genre\">" >> $3
  cat  $1 | gawk 'BEGIN{id=1}{print "<p><seg id=\""id"\">"$0"</seg></p>"; id++}' >> $3
  echo "</doc>" >> $3
  echo "</"$2">" >> $3
  
  echo "</mteval>" >> $3
}


gen_xml_file $SRC "srcset" $SRC"-"$$".xml" "SYS"
gen_xml_file $TEST "tstset" $TEST"-"$$".xml" "SYS"
gen_xml_file $REF "refset" $REF"-"$$".xml" "SYS"

mteval-v13a.pl -r $REF-$$.xml -s $SRC-$$.xml -t $TEST-$$.xml | grep "BLEU score" | gawk '{print $8}'

rm -f $SRC"-"$$".xml" $TEST"-"$$".xml" $REF"-"$$".xml"
