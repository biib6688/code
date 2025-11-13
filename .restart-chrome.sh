#!/bin/bash
sudo -u $(logname) bash << 'INNER_EOF'
export DISPLAY=:1100
pkill chrome && pkill grass && sleep 10
google-chrome --remote-debugging-port=9222 https://app.gradient.network/dashboard/node about:blank &
sleep 30

DEBUG_URL="http://localhost:9222/json"

for i in {1..3}; do
  TAB_INFO=$(curl -s $DEBUG_URL)
  TAB_ID=$(echo $TAB_INFO | jq -r '.[] | select(.title == "Gradient Network Dashboard") | .id')
  if [ -n "$TAB_ID" ]; then
    curl -X DELETE "$DEBUG_URL/close/$TAB_ID"
    echo "Tab with title 'Gradient Network Dashboard' closed."
    break
  else
    echo "No tab with title 'Gradient Network Dashboard' found. Attempt $i of 3."
    sleep 45
  fi
done
INNER_EOF
