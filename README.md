## Demonstrate network cache-based identity could be mistaken due to eventual consistency issues

### Setup

sleep v1 is allowed to talk to helloworld v1, and sleep v2 is allowed to talk to helloworld v2.

### How does it work?
We demonstrate eventual consistency issue by simulating an "outage" and making the node helloworld v1 is on to not be able to reach the k8s api server. This means that the cilium agent is unable to update its IP cache when pods rotate.

### How to run the test?
Then we scale sleep v1 to zero, and re-rollout sleep v2 until it uses a recycled sleep v1 IP.

We then curl from the sleep v2 pod with the recycled IP to helloworld v1 successfully, against the policy.

Note that pod traffic is encrypted with wireguard.

run `setup.sh` first and then `test.sh`. you can use `cleanup.sh` to get back to clean state so you can run test again.
