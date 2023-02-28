#!/bin/bash

CLIPBOARD_CONTENT=$(wl-paste | tr -d '\n' | jq -Rs)

curl --location --request POST 'https://$HOST:9876/' \
--header 'Verification-Token: $VERIFICATION_TOKEN' \
--header 'Content-Type: application/json' \
--data-raw "{\"content\":$CLIPBOARD_CONTENT}"
