#!/bin/sh

if [ $# -ne 2 ]; then
    echo "missing arguments"
    exit 1
elif [ ! -d $1 ]; then
    echo "argument 1 must be a directory"
    exit 1
else
    MFILES=$(grep -rl $2 $1 | wc -l)
    MLINES=$(grep -r $2 $1 | wc -l)
    echo "The number of files are $MFILES and the number of matching lines are $MLINES"
    exit 0
fi
