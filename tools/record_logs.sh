#!/bin/bash

# Predicate: capture messages from com.amr.englishsubtitles subsystem with "subtitles" category
#PREDICATE='subsystem == "com.amr.englishsubtitles" && category == "subtitles"'
PREDICATE='eventMessage CONTAINS "#subtitles"'

# Optional log level
LOG_LEVEL="--level debug"   # leave "" to disable

# Optional cleanup
CLEANUP=true  # set false to disable sed cleanup

./stop_record_logs.sh

# Build the pipeline
if [[ "$CLEANUP" == true ]]; then
    PIPELINE="sed 's/([^)]*) \[[^]]*\] //g; s/0x0//g; s/-0700//g'"
else
    PIPELINE="cat"
fi

# Start log stream
eval "log stream --predicate '$PREDICATE' $LOG_LEVEL | $PIPELINE > log.txt &"

echo $! > record_logs.pid
echo "New log stream started with predicate: $PREDICATE $LOG_LEVEL, cleanup: $CLEANUP. PID saved in record_logs.pid"

