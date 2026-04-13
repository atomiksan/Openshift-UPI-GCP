# OpenShift UPI on GCP

Terraform for a small OpenShift UPI lab on Google Cloud Platform.

The layout creates:

- One custom VPC and subnet.
- Reserved private IP addresses for bastion, bootstrap, masters, and workers.
- Private Cloud DNS records for OpenShift.
- Firewall rules for internal cluster traffic and bastion access.
- Cloud Router and Cloud NAT for private instance egress.
- One bastion/load balancer VM.
- One bootstrap VM, three master VMs, and two worker VMs with no external IPs.

## Network Layout

| Role | Private IP | DNS name |
| --- | --- | --- |
| Bastion / HAProxy | `10.0.0.10` | `bastion.<cluster_id>.<base_domain>` |
| Master 0 | `10.0.0.11` | `master0.<cluster_id>.<base_domain>` |
| Master 1 | `10.0.0.12` | `master1.<cluster_id>.<base_domain>` |
| Master 2 | `10.0.0.13` | `master2.<cluster_id>.<base_domain>` |
| Worker 0 | `10.0.0.14` | `worker0.<cluster_id>.<base_domain>` |
| Worker 1 | `10.0.0.15` | `worker1.<cluster_id>.<base_domain>` |
| Bootstrap | `10.0.0.20` | `bootstrap.<cluster_id>.<base_domain>` |

The default cluster domain is:

```text
ocp-lab.ocp.satyabrata.net
```

The following OpenShift records are created in private Cloud DNS:

- `api.<cluster_domain>` -> `10.0.0.10`
- `api-int.<cluster_domain>` -> `10.0.0.10`
- `*.apps.<cluster_domain>` -> `10.0.0.10`
- `bastion.<cluster_domain>` -> `10.0.0.10`
- `bootstrap.<cluster_domain>` -> `10.0.0.20`
- `master0.<cluster_domain>` -> `10.0.0.11`
- `master1.<cluster_domain>` -> `10.0.0.12`
- `master2.<cluster_domain>` -> `10.0.0.13`
- `worker0.<cluster_domain>` -> `10.0.0.14`
- `worker1.<cluster_domain>` -> `10.0.0.15`
- `_etcd-server-ssl._tcp.<cluster_domain>` SRV records for the three masters.

## Prerequisites

Install or enter the Nix dev shell:

```bash
nix develop
```

You also need:

- A GCP project with Compute Engine, Cloud DNS, IAM, and Cloud NAT APIs enabled.
- GCP credentials. ADC is easiest:

```bash
gcloud auth application-default login
gcloud config set project <project_id>
```

- An RHCOS image imported into your project.
- `openshift-install` and `oc`.
- A valid pull secret and SSH public key.

## Configure Terraform

Create your local variables file:

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

Edit at least:

```hcl
project_id  = "my-gcp-project"
base_domain = "ocp.example.com"
rhcos_image = "projects/my-gcp-project/global/images/rhcos-421"
```

Leave `credentials_file = null` to use ADC/gcloud credentials. If you prefer a service account key, set:

```hcl
credentials_file = "../ocp-sa-key.json"
```

Keep private values out of git. Terraform state and `*.tfvars` files are ignored.

## Generate OpenShift Ignition

Start from the sample config:

```bash
cp ocp-install-config/install-config.yaml /tmp/ocp-install/install-config.yaml
```

Edit `/tmp/ocp-install/install-config.yaml` and set:

- `baseDomain`
- `metadata.name`
- `pullSecret`
- `sshKey`

For the default Terraform variables, keep:

```yaml
baseDomain: ocp.satyabrata.net
metadata:
  name: ocp-lab
compute:
- name: worker
  replicas: 2
controlPlane:
  name: master
  replicas: 3
platform:
  none: {}
```

Create ignition files:

```bash
openshift-install create ignition-configs --dir=/tmp/ocp-install
```

You should now have:

```text
/tmp/ocp-install/bootstrap.ign
/tmp/ocp-install/master.ign
/tmp/ocp-install/worker.ign
```

## Choose Ignition Mode

The example variables use file mode:

```hcl
ignition_mode = "file"
ignition_dir  = "../ocp-install-config"
```

Copy the generated ignition files into `ocp-install-config/` before `terraform apply`:

```bash
cp /tmp/ocp-install/bootstrap.ign ocp-install-config/bootstrap.ign
cp /tmp/ocp-install/master.ign ocp-install-config/master.ign
cp /tmp/ocp-install/worker.ign ocp-install-config/worker.ign
```

The ignition files are ignored by git.

URL mode is available if your ignition files exceed GCP metadata size limits:

```hcl
ignition_mode     = "url"
ignition_base_url = "http://10.0.0.10:8080/ignition"
```

URL mode sends small pointer configs in instance metadata. The bastion starts Apache on port `8080`, but you must place the generated ignition files on the bastion before the OpenShift nodes boot successfully:

```text
/var/www/html/ignition/bootstrap.ign
/var/www/html/ignition/master.ign
/var/www/html/ignition/worker.ign
```

## Apply

Initialize and review:

```bash
terraform -chdir=terraform init
terraform -chdir=terraform plan
```

Create the infrastructure:

```bash
terraform -chdir=terraform apply
```

After apply, Terraform prints the bastion public IP when `bastion_enable_public_ip = true`.

## Bastion Services

The bastion VM is configured by startup script.

It runs:

- HAProxy on `80`, `443`, `6443`, `22623`, and `9000`.
- Apache on `8080` for ignition hosting.

HAProxy routes:

- `6443` to bootstrap and masters.
- `22623` to bootstrap and masters.
- `80` and `443` to masters.

Use the `haproxy_stats_user` and `haproxy_stats_password` variables to change the stats login.

## Verify DNS From Inside The VPC

From the bastion:

```bash
dig +short api.ocp-lab.ocp.satyabrata.net
dig +short api-int.ocp-lab.ocp.satyabrata.net
dig +short master0.ocp-lab.ocp.satyabrata.net
dig +short worker0.ocp-lab.ocp.satyabrata.net
dig +short -t SRV _etcd-server-ssl._tcp.ocp-lab.ocp.satyabrata.net
```

Expected key answers:

```text
10.0.0.10
10.0.0.11
10.0.0.14
```

## Complete OpenShift Install

From the machine that has your generated install directory:

```bash
openshift-install wait-for bootstrap-complete --dir=/tmp/ocp-install --log-level=info
openshift-install wait-for install-complete --dir=/tmp/ocp-install --log-level=info
```

After bootstrap completes, remove the bootstrap instance:

```bash
terraform -chdir=terraform destroy -target=module.compute.google_compute_instance.bootstrap
```

## Destroy

```bash
terraform -chdir=terraform destroy
```
