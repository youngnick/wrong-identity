#!/bin/bash

# Apply services:
# Note that: hello-v1 and hello-v2 go on different nodes, and the sleep deployments go on nodes where hello are not.
echo "Depolying services and waiting for them to be ready..."
kubectl apply -f ./yamls

kubectl rollout status deployment/sleep-v1
kubectl rollout status deployment/sleep-v2
kubectl rollout status deployment/helloworld-v1
kubectl rollout status deployment/helloworld-v2

# Show that v1 talks only to v1 and v2 only to v2.
for i in 1 2; do
    for j in 1 2; do
        echo Trying to connect from deploy/sleep-v$i to helloworld-v$j
        (kubectl exec deploy/sleep-v$i -- curl -s http://helloworld-v$j:5000/hello --max-time 2 && echo "Connection success.")|| echo "Connection Failed."
        echo
    done
done

# Find the all the IPs of sleep-v1:
SLEEPV1_IPs=$(kubectl get pod -l app=sleep,version=v1 -o json | jq -r '.items[]|.status.podIP')

NODEV1=$(kubectl get pod -l app=helloworld,version=v1 -o=jsonpath='{.items[0].spec.nodeName}')
AGENT_POD="$(kubectl get pods -n kube-system --field-selector spec.nodeName="$NODEV1" -l k8s-app=cilium -o custom-columns=:.metadata.name --no-headers)"

# For informational purposes, show the current ip cache:
echo "Here is the current ip cache for agent $AGENT_POD in node $NODEV1:"
kubectl exec -n kube-system $AGENT_POD -c cilium-agent -- cilium map get cilium_ipcache
echo ""

# get the identity of sleep-v1:
SLEEPV1_ID=$(kubectl get ciliumendpoints.cilium.io -l app=sleep,version=v1 -o jsonpath='{.items[0].status.identity.id}')
SLEEPV2_ID=$(kubectl get ciliumendpoints.cilium.io -l app=sleep,version=v2 -o jsonpath='{.items[0].status.identity.id}')

echo "Security identity for sleep-v1 is $SLEEPV1_ID. CiliumIdentity:"
kubectl get ciliumidentities.cilium.io $SLEEPV1_ID -o yaml
echo ""
echo "Security identity for sleep-v1 is $SLEEPV2_ID. CiliumIdentity:"
kubectl get ciliumidentities.cilium.io $SLEEPV2_ID -o yaml
echo ""

API_SERVER=$(kubectl get service -n default kubernetes -o=jsonpath='{.spec.clusterIP}')
API_SERVEREP=$(kubectl get endpoints -n default kubernetes -o jsonpath='{.subsets[0].addresses[0].ip}')
# Now, simulate an "outage" so that the agent in helloworld-v1 will not be able to update its ip-cache.
# bye bye api server - drop all incoming packets from the api server.
docker exec $NODEV1 iptables -t mangle -I INPUT -p tcp -s $API_SERVER -j DROP
docker exec $NODEV1 iptables -t mangle -I INPUT -p tcp -s $API_SERVEREP -j DROP

echo ""
echo "Now that the ip-cache cannot be updated, we can rotate sleep-v2 pods, until we get a pod with an"
echo "ip that used to belong to sleep-v1."
echo ""

# scale sleep-v1 to 0
kubectl scale deploy sleep-v1 --replicas=0
# scale sleep-v2 to 15
kubectl scale deploy sleep-v2 --replicas=15

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

echo ""
echo "Trying to curl from sleep-v2 to helloworld-v2. running:"
echo kubectl exec $SLEEPV2POD -- curl -s http://helloworld-v2:5000/hello --max-time 2
(kubectl exec $SLEEPV2POD -- curl -s http://helloworld-v2:5000/hello --max-time 2 && echo "Connection success.")|| echo "Connection Failed."
echo ""
echo ""


# Try curl from the sleep-v2 pod we found to the helloworld-v1 deployment. This should fail according to policy
# but will succeed because the ip-cache is not up to date.
echo ""
echo "Trying to curl from sleep-v2 to helloworld-v1. running:"
echo kubectl exec $SLEEPV2POD -- curl -s http://helloworld-v1:5000/hello --max-time 2
(kubectl exec $SLEEPV2POD -- curl -s http://helloworld-v1:5000/hello --max-time 2 && echo "Connection success.")|| echo "Connection Failed."
echo ""
echo ""

# we can't see the ip-cache with kubectl now because of the "outage" we triggered. So we use docker/crictl instead:
# kubectl exec -n kube-system -ti $AGENT_POD -c cilium-agent --  cilium map get cilium_ipcache
echo "You can see the agent logs with:"
echo "docker exec -ti $NODEV1 /bin/bash -c 'crictl logs \$(crictl ps --name cilium-agent -q)'"
echo ""
echo "Current ip cache:"
docker exec $NODEV1 /bin/bash -c 'crictl exec $(crictl ps --name cilium-agent -q) cilium map get cilium_ipcache'
echo ""
echo ""
echo "We noted earlier that sleep-v1 had identity $SLEEPV1_ID, and sleep-v2 had $SLEEPV2_ID"
echo "Specifically, note the identity of the sleep-v2 pod's IP:"
docker exec $NODEV1 /bin/bash -c 'crictl exec $(crictl ps --name cilium-agent -q) cilium map get cilium_ipcache' | grep $ip
echo "and compare to above ip cache and identity."