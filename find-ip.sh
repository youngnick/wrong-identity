#!/bin/bash

# rotate sleep-v2 pods until we get a sleep-v2 pod with ip of sleep-v1
while true; do
   # check if we got a click
   for ip in $SLEEPV1_IPs; do
       SLEEPV2POD=$(kubectl get pod -l app=sleep,version=v2 -o json|jq -r '.items|map(select(.status.podIP == "'$ip'"))|map(.metadata.name)|.[0]' )
       if [ -z "$SLEEPV2POD" ] || [ "$SLEEPV2POD" == "null" ]; then
           SLEEPV2POD=""
       else
           echo ""
           echo "Found sleep-v2 pod $SLEEPV2POD ip $ip"
           break
       fi
   done

   if [ -z "$SLEEPV2POD" ]; then
       echo "Matching sleep-v2 not found yet - retrying rollout"
       kubectl rollout restart deployment/sleep-v2
       # rollout status is really verbose, so send output to /dev/null
       kubectl rollout status deployment/sleep-v2 > /dev/null
   else
       break
   fi
done
