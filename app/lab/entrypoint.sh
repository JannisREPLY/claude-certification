#!/bin/sh
python3 /opt/grader/grader.py &
exec /usr/bin/entrypoint.sh --bind-addr 0.0.0.0:8080 --auth none --disable-telemetry --extensions-dir /opt/code-server-ext /home/coder/lab
