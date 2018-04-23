# Clearwater Kubernetes

Please read [README.Metaswitch.md](https://github.com/Intel-Corp/clearwater-kubernertes/blob/master/README.Metaswitch.md) to understand docker setup, before continueing with this guide.

### License/Licence

- This is GPLv3 per [Metaswitch Clearwater Docker](https://github.com/Metaswitch/clearwater-docker)

### Contacts

- clearwater@lists.projectclearwater.org
- O Connor, Derek <derek.o.connor@intel.com>
- O Neill, David M <david.m.oneill@intel.com>

### Starting Clearwater kubernetes

To start the Clearwater kubernetes deployment:

#### modify config
vi run.conf

```
# This key is used for DDNS updates, please reference bind documention
DNSKEY="VBJev6+xzhFVXXYY7tAq4A=="
	
# This is the zone used in the IMS deployment 
USERZONE="clearwater.com"
	
# This is the clearwater public_ip variable (needs to be address of phyiscal node)
NODEHOST="node1.mydomain.com"
	
# Your upstream DNS server
DNSFORWARDER1="8.8.8.8"
	
# Your secondary DNS server
DNSFORWARDER2="8.8.4.4"
	
# The images that are built need to be stored on a docker registry
REGISTRY_HOST="docker-registry.mydomain.com"
	
# Optional prefix
IMAGE_PREFIX="prefix"
	
# If building behind proxy, then this might be useful
PROXY="http://proxy.mydomain.com:port"
	
# If you have an internal mirror of the clearwater repo, you can define it here.  If undefined it uses clearwater's
#REPOSITORY="http://deb.server.mydomain.com/clearwater/"
	
# If building internally behind proxy a NO_PROXY may be required
#NO_PROXY="10.0.0.0/8"
```    
#### Build all the other Clearwater Docker images and start a deployment.
./run.sh

#### Gotchas

Common gotchas are:

- Service ports - API~ server must be modified to support service ports in the range 3000-60000
- When connecting with SIP client, use the NODE HOST address as the proxy IP.  (Hard coupling bono/public_ip) 
-- [Unable to use IP abstraction in front of Bono #65](https://github.com/Metaswitch/clearwater-docker/issues/65) 

#### Overview

In this architecture, clearwater services no longer talk directly to one another.
Instead, on runtime the k8s service gets registered in DNS bind for use by all of the containers.

E.g When bono requested sprout, it does not get the IP of sprout, but rather the kubernetes service IP.
This allows kubernetes to perform load balancing accross multiple sprout instances.

Kubernetes services provide the pod/IP decoupling, 
however there are open questions as to the RFC specifically in relation to the NAPTR/SRV records pertainining to load balancing.

![clearwater-k8s-overview](https://raw.githubusercontent.com/Intel-Corp/clearwater-kubernertes/master/docs/images/clearwater-k8s.png)
