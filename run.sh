while true; do
for ip in $SLEEPV1IPs; do
    SLEEPV2POD=$(kubectl get pod -l app=sleep,version=v2 -o json|jq -r '.items|map(select(.status.podIP == "'$ip'"))|map(.metadata.name)|.[0]' )
    if [ -z "$SLEEPV2POD" ] || [ "$SLEEPV2POD" == "null" ]; then
        SLEEPV2POD=""
    else
        echo Found sleep v2 pod $SLEEPV2POD ip $ip
        break
    fi
done

    if [ -z "$SLEEPV2POD" ]; then
        echo "sleepv2 not found yet"
        kubectl rollout restart deployment/sleep-v2
        kubectl rollout status deployment/sleep-v2
    else
        break
    fi
done
