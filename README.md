## Demonstrate potential wrong Identity due to eventual consistency issues

The setup is:

sleep v1 is allowed to talk to hello v1, and
sleep v2 is allowed to talk to hello v2.

We demonstrate eventual consistency issue by simulating an "outage" and making the node hello v1 is on to not be able to reach the k8s api server. This means that the cilium agent is unable to update its IP cache when pods rotate.

Then we scale sleepv1 to zero, and re-rollout sleepv2 until it uses recycled sleepv1 IP.

We then curl from the sleepv2 pod with the recycled IP to hello v1 successfully, against the policy.

Note that pod traffic is encrypted with wireguard.

run `setup.sh` first and then `test.sh`. you can use `cleanup.sh` to get back to clean state so you can run test again.