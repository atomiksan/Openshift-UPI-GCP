
---

# 🚀 OpenShift 4.21 UPI on GCP – Master-Only Cluster

**User-Provisioned Infrastructure (UPI)** installation of OpenShift 4.21 on Google Cloud Platform using:

* Custom VPC
* Cloud NAT
* Private DNS
* Bastion with HAProxy
* Apache httpd for Ignition
* Master-only topology (no workers)

---

# 📦 1. Required Downloads

Download to your workstation or Bastion:

* OpenShift Installer 4.21
* OpenShift CLI (`oc`)
* RHCOS GCP image

Upload RHCOS image to GCP and create a custom image:

```
rhcos-421
```

---

# 🌐 2. Infrastructure Setup

---

## 2.1 Create VPC & Subnet

```bash
gcloud compute networks create ocp-network \
  --subnet-mode=custom \
  --project=vernal-branch-484810-p6

gcloud compute networks subnets create ocp-subnet \
  --network=ocp-network \
  --range=10.0.0.0/24 \
  --region=us-central1 \
  --project=vernal-branch-484810-p6
```

---

## 2.2 Cloud NAT

```bash
gcloud compute routers create ocp-router \
  --network=ocp-network \
  --region=us-central1

gcloud compute routers nats create ocp-nat \
  --router=ocp-router \
  --region=us-central1 \
  --auto-allocate-nat-external-ips \
  --nat-all-subnet-ip-ranges
```

---

# 🌍 2.3 Private DNS Configuration

Create zone:

```bash
gcloud dns managed-zones create ocp-private-zone \
  --dns-name=ocp-lab.ocp.satyabrata.net. \
  --description="OpenShift Private Zone" \
  --visibility=private \
  --networks=ocp-network
```

Start transaction:

```bash
gcloud dns record-sets transaction start --zone=ocp-private-zone
```

---

## 🔹 Node Records

```bash
# Bootstrap
gcloud dns record-sets transaction add 10.0.0.50 \
  --name=bootstrap.ocp-lab.ocp.satyabrata.net. \
  --ttl=60 --type=A --zone=ocp-private-zone

# Masters
gcloud dns record-sets transaction add 10.0.0.20 \
  --name=master0.ocp-lab.ocp.satyabrata.net. \
  --ttl=60 --type=A --zone=ocp-private-zone

gcloud dns record-sets transaction add 10.0.0.30 \
  --name=master1.ocp-lab.ocp.satyabrata.net. \
  --ttl=60 --type=A --zone=ocp-private-zone

gcloud dns record-sets transaction add 10.0.0.40 \
  --name=master2.ocp-lab.ocp.satyabrata.net. \
  --ttl=60 --type=A --zone=ocp-private-zone
```

---

## 🔹 API & Internal API

```bash
gcloud dns record-sets transaction add 10.0.0.10 \
  --name=api.ocp-lab.ocp.satyabrata.net. \
  --ttl=60 --type=A --zone=ocp-private-zone

gcloud dns record-sets transaction add 10.0.0.10 \
  --name=api-int.ocp-lab.ocp.satyabrata.net. \
  --ttl=60 --type=A --zone=ocp-private-zone
```

---

## 🔹 Wildcard Apps Record

```bash
gcloud dns record-sets transaction add 10.0.0.10 \
  --name=*.apps.ocp-lab.ocp.satyabrata.net. \
  --ttl=60 --type=A --zone=ocp-private-zone
```

Execute:

```bash
gcloud dns record-sets transaction execute --zone=ocp-private-zone
```

---

# 🔥 3. Firewall Rules

```bash
gcloud compute firewall-rules create ocp-allow-internal \
  --network=ocp-network \
  --allow all \
  --source-ranges=10.0.0.0/24

gcloud compute firewall-rules create ocp-allow-control-plane \
  --network=ocp-network \
  --allow tcp:6443,tcp:22623 \
  --source-ranges=0.0.0.0/0 \
  --target-tags=bastion-vm

gcloud compute firewall-rules create ocp-allow-ingress \
  --network=ocp-network \
  --allow tcp:80,tcp:443,tcp:9000 \
  --source-ranges=0.0.0.0/0 \
  --target-tags=bastion-vm

gcloud compute firewall-rules create ocp-allow-ssh \
  --network=ocp-network \
  --allow tcp:22 \
  --source-ranges=0.0.0.0/0
```

---

# 📝 4. OpenShift Config

## install-config.yaml

```yaml
apiVersion: v1
baseDomain: ocp.satyabrata.net
compute:
- hyperthreading: Enabled
  name: worker
  replicas: 0
controlPlane:
  hyperthreading: Enabled
  name: master
  replicas: 3
metadata:
  name: ocp-lab
networking:
  clusterNetwork:
  - cidr: 10.128.0.0/14
    hostPrefix: 23
  networkType: OVNKubernetes
  serviceNetwork:
  - 172.30.0.0/16
platform:
  none: {}
fips: false
pullSecret: '{"auths": ...}' ##Put your pull secret here
sshKey: 'ssh-ed25519 AAAA...' ##Put your ssh key here
```

Generate ignition files:

```bash
openshift-install create ignition-configs --dir=<your config directory>
```

---

# 🌐 5. Apache httpd for Ignition

Install:

```bash
sudo yum install -y httpd
```

Setup:

```bash
sudo mkdir -p /var/www/html/ignition
sudo cp *.ign /var/www/html/ignition/
sudo chown -R apache:apache /var/www/html

# Change httpd port to 8080
sudo sed -i 's/Listen 80/Listen 8080/' /etc/httpd/conf/httpd.conf

# Allow HTTP traffic permanently
sudo firewall-cmd --permanent --add-service=http

# Reload the firewall to apply changes
sudo firewall-cmd --reload

# Apply the correct SELinux context for web content
sudo restorecon -Rv /var/www/html/ocp4
```

Enable:

```bash
sudo systemctl enable httpd
sudo systemctl start httpd
```

Test:

```
curl -I http://10.0.0.10:8080/ignition/bootstrap.ign
```

---

# ⚖️ 6. HAProxy Config

`/etc/haproxy/haproxy.cfg`

```haproxy

global
    log         127.0.0.1 local2
    chroot      /var/lib/haproxy
    pidfile     /var/run/haproxy.pid
    maxconn     4000
    user        haproxy
    group       haproxy
    daemon

defaults
    mode                    tcp
    log                     global
    option                  tcplog
    option                  dontlognull
    retries                 3
    timeout http-request    10s
    timeout queue           1m
    timeout connect         10s
    timeout client          1m
    timeout server          1m
    timeout check           10s
    maxconn                 3000

# ---------------------------------------------------------------------
# HAProxy Stats Page
# ---------------------------------------------------------------------
listen stats
    bind :9000
    mode http
    stats enable
    stats uri /
    stats refresh 5s
    stats auth admin:admin123

# ---------------------------------------------------------------------
# API Server (Port 6443)
# ---------------------------------------------------------------------
frontend api-frontend
    bind *:6443
    default_backend api-backend

backend api-backend
    balance roundrobin
    server bootstrap 10.0.0.50:6443 check
    server master0   10.0.0.20:6443 check
    server master1   10.0.0.30:6443 check
    server master2   10.0.0.40:6443 check

# ---------------------------------------------------------------------
# Machine Config Server (Port 22623)
# ---------------------------------------------------------------------
frontend machine-config-frontend
    bind *:22623
    default_backend machine-config-backend

backend machine-config-backend
    balance roundrobin
    server bootstrap 10.0.0.50:22623 check
    server master0   10.0.0.20:22623 check
    server master1   10.0.0.30:22623 check
    server master2   10.0.0.40:22623 check

# ---------------------------------------------------------------------
# Ingress HTTP (Port 80)
# ---------------------------------------------------------------------
frontend ingress-http-frontend
    bind *:80
    default_backend ingress-http-backend

backend ingress-http-backend
    balance roundrobin
    server master0 10.0.0.20:80 check
    server master1 10.0.0.30:80 check
    server master2 10.0.0.40:80 check

# ---------------------------------------------------------------------
# Ingress HTTPS (Port 443)
# ---------------------------------------------------------------------
frontend ingress-https-frontend
    bind *:443
    default_backend ingress-https-backend

backend ingress-https-backend
    balance roundrobin
    server master0 10.0.0.20:443 check
    server master1 10.0.0.30:443 check
    server master2 10.0.0.40:443 check

```

Restart:

```bash
# Open ports in Firewalld
sudo firewall-cmd --permanent --add-port={6443,22623,80,443}/tcp
sudo firewall-cmd --reload

# Allow HAProxy to make outbound connections (SELinux)
sudo setsebool -P haproxy_connect_any 1

# Start HAProxy
sudo systemctl enable --now haproxy
sudo systemctl restart haproxy
```

---

# 🧪 7. Final Pre-Provisioning Sanity Check (MANDATORY)

⚠️ **Do NOT provision bootstrap or master nodes until all checks in this section pass.**

This verifies:

* DNS resolution (Cloud DNS Private Zone)
* Resolver configuration (GCP metadata server)
* HAProxy listening ports
* Apache and HAProxy are not conflicting

---

## 7.1 Install Required Tools

If not already installed, install `bind-utils` to get `dig` and `nslookup`.

```bash
sudo dnf install -y bind-utils
```

---

## 7.2 Perform the “Identity Check” (DNS Validation)

Since you're using **Google Cloud DNS Private Zones**, your Bastion should automatically resolve internal records.

Run the following tests **from the Bastion**.

---

### 🔹 Test the API (Load Balancer)

```bash
dig +short api.ocp-lab.ocp.satyabrata.net
```

Expected result:

```
10.0.0.10
```

---

### 🔹 Test a Master Node

```bash
dig +short master0.ocp-lab.ocp.satyabrata.net
```

Expected result:

```
10.0.0.20
```

---

### 🔹 Test the Wildcard Apps Record

```bash
dig +short console-openshift-console.apps.ocp-lab.ocp.satyabrata.net
```

Expected result:

```
10.0.0.10
```

---

If any of these fail:

* Verify DNS zone is attached to the correct VPC
* Ensure you executed the DNS transaction
* Confirm the Bastion is inside the same VPC

---

## 7.3 Why This Works on CentOS 10

CentOS 10 uses:

* NetworkManager
* systemd-resolved

When your Bastion boots in GCP, it receives a DHCP lease that sets:

```
nameserver 169.254.169.254
```

This special IP is the **Google metadata server**, which provides access to:

* Cloud DNS Private Zones
* Internal name resolution

---

### 🔎 Verify Resolver Configuration

```bash
cat /etc/resolv.conf
```

You should see:

```
nameserver 169.254.169.254
```

If you do not:

* Check NetworkManager status
* Restart networking
* Ensure no custom DNS override exists

---

## 7.4 Verify HAProxy is Listening

Since Apache is now serving ignition files, ensure it is not conflicting with HAProxy.

Run:

```bash
sudo ss -tunlp | grep -E '6443|22623|80|443'
```

You should see:

* HAProxy listening on:

  * 6443
  * 22623
  * 443
* Apache listening on:

  * 80

If ports are missing:

```bash
sudo systemctl status haproxy
sudo systemctl status httpd
```

Restart if necessary:

```bash
sudo systemctl restart haproxy
sudo systemctl restart httpd
```

---

# ✅ Final Confirmation Checklist

Before proceeding to bootstrap:

* [ ] API resolves correctly
* [ ] Master node resolves correctly
* [ ] Wildcard apps resolves correctly
* [ ] `/etc/resolv.conf` points to 169.254.169.254
* [ ] HAProxy listening on 6443, 22623, 443
* [ ] Apache listening on 80
* [ ] No port conflicts

---

If all checks pass — you are cleared to provision bootstrap and master nodes.

---


# 🛠 8. Provision Nodes

Bootstrap:

```bash
gcloud compute instances create ocp-bootstrap \
  --image=rhcos-421 \
  --machine-type=n2-standard-4 \
  --boot-disk-size=100GB \
  --boot-disk-type=pd-ssd \
  --network=ocp-network \
  --subnet=ocp-subnet \
  --private-network-ip=10.0.0.50 \
  --metadata-from-file=user-data=bootstrap.ign
```

Repeat for masters.

---

# 🌐 9. Configure Ingress for Master-Only Cluster (CRITICAL)

Since this deployment uses **no worker nodes**, the default ingress controller will not schedule router pods unless explicitly told to run on masters.

You must patch the default ingress controller to:

* Use `HostNetwork`
* Allow scheduling on master nodes
* Add proper tolerations (`NoSchedule` and `NoExecute`)

---

## Apply the Patch

```bash
oc patch ingresscontroller default \
  -n openshift-ingress-operator \
  --type=merge \
  -p '{"spec":{"endpointPublishingStrategy":{"type":"HostNetwork"},"nodePlacement":{"nodeSelector":{"matchLabels":{"node-role.kubernetes.io/master":""}},"tolerations":[{"effect":"NoSchedule","key":"node-role.kubernetes.io/master","operator":"Exists"},{"effect":"NoExecute","key":"node-role.kubernetes.io/master","operator":"Exists"}]}}}'
```

---

## Verify Router Pods Are Running

```bash
oc get pods -n openshift-ingress -o wide
```

You should see router pods scheduled on:

```
master0
master1
master2
```

---

## Verify Ingress Operator Status

```bash
oc get co ingress
```

Expected:

```
Available=True
Progressing=False
Degraded=False
```

---

## Test Console Route

```bash
oc get route console -n openshift-console
```

Then test from Bastion:

```bash
curl -k https://console-openshift-console.apps.ocp-lab.ocp.satyabrata.net
```

If it loads (even with self-signed cert warning), ingress is working.

---

# 🧠 Why This Is Required

By default:

* Masters are tainted with:

  ```
  node-role.kubernetes.io/master:NoSchedule
  ```
* Router pods expect worker nodes.

Your patch:

* Adds tolerations
* Forces placement on masters
* Uses host networking to bind directly to node IPs

Without this patch:

* `*.apps` DNS will resolve
* HAProxy will forward traffic
* But nothing will answer on port 443


---

# 🔎 10. Deep Debugging Guide

## Bootstrap Logs

```bash
journalctl -b -f -u release-image.service -u bootkube.service
sudo systemctl status release-image.service
```

## Kubelet

```bash
journalctl -u kubelet -f
```

## etcd

```bash
etcdctl endpoint health
```

## API

```bash
curl -k https://api.ocp-lab.ocp.satyabrata.net:6443/version
```

## CSR

```bash
oc get csr
oc get csr -o name | xargs oc adm certificate approve
```

## Check Operators

```bash
oc get co
```

## On the Masters

```bash
# Watch the Machine Config Daemon (the service that applies the configuration)
journalctl -b -f -u machine-config-daemon-pull.service
journalctl -b -u ignition-fetch-offline.service
journalctl -b -f -u kubelet
```

---

# 🧨 11. Complete Bootstrap

```bash
openshift-install wait-for bootstrap-complete
```

Delete bootstrap:

```bash
gcloud compute instances delete ocp-bootstrap \
  --zone=us-central1-c --quiet
```

Remove bootstrap from HAProxy backend.

---

# 🧹 12. Teardown

```bash
gcloud compute instances delete \
  ocp-master-0 ocp-master-1 ocp-master-2 bastion-0 \
  --zone=us-central1-c --quiet

gcloud compute networks delete ocp-network --quiet
```

---

# ✅ Validation

```bash
oc get nodes
oc get co
oc get pods -A
```

Expected:

```
Available=True
Degraded=False
Progressing=False
```

---
