#!/bin/bash

if [[ -f record_logs.pid ]]; then
    pid=$(cat record_logs.pid)
    if kill -0 "$pid" 2>/dev/null; then
        echo "Stopping log stream with PID $pid"
        kill "$pid"
        rm -f record_logs.pid
    else
        echo "No running process found for PID $pid, cleaning up."
        rm -f record_logs.pid
    fi
else
    echo "No record_logs.pid file found. Log stream may not be running."
fi
