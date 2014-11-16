#!/bin/sh

SRC=$1
REF=$2
TEST=$3

if [[ $# -ne 3 ]]
then
  echo "Error: Wrong number of parameters"
  echo "USAGE: ter.sh source reference test"
  exit 1
fi

cat $REF  | gawk '{id++; print $0" (SYS."id")"}' > $REF"-ter-"$$
cat $TEST | gawk '{id++; print $0" (SYS."id")"}' > $TEST"-ter-"$$

java -jar tercom.jar -r $REF"-ter-"$$ -h $TEST"-ter-"$$ | grep "TER" | awk '{print $3}'

rm -f $REF"-ter-"$$ $TEST"-ter-"$$
