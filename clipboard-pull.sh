#!/bin/bash

curl -s 'https://$HOST:9876/' --header 'Verification-Token: $VERIFICATION_TOKEN' | jq -r '.content' | tr -d '\n' | wl-copy
