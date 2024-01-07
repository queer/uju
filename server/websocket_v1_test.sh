#!/usr/bin/env bash

function log() {
  echo -e ">> $@"
}

# url, max_tries, sleep_time
function _poll() {
  local url=$1
  local max_tries=$2
  local sleep_time=$3
  local i=0
  while [ $i -lt $max_tries ]; do
    log "connecting to server at ${url}..."
    curl -s "$url" > /dev/null
    if [ $? -eq 0 ]; then
      log "success!"
      return 0
    fi
    sleep $sleep_time
    i=$((i+1))
  done
  log "failed after ${max_tries} tries!"
  return 1
}

log "starting server!"
mix run --no-halt 2>&1 1>/dev/null &
server_pid=$!
log "server pid: $server_pid"
output="websocket_v1_actual.txt"
_poll "http://localhost:8080" 20 1
log "running ws tests!"
deno run --allow-net "test/support/websocket_v1_client.ts" > $output
log "finished testing!"
kill $server_pid
log "diffing outputs..."
diff $output "test/support/websocket_v1_expected.txt"
worked=$?
rm -v $output
if [ $worked -eq 0 ]; then
  log "tests passed!"
else
  log "tests failed!"
fi
exit $worked
