#!/bin/bash

for node in $(kind get nodes); do
    docker exec -ti $node /bin/bash -c 'iptables -t mangle -F INPUT'
done

kubectl delete -f yamls
kubectl delete pod -n kube-system -l k8s-app=cilium

kubectl apply -f yamls
