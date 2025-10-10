# Inception of Things

Automated Kubernetes environments for 42's Inception-of-Things journey, spanning local k3s labs, Ansible-driven multi-app deployments, GitOps with Argo CD, and a full self-hosted GitLab bonus.

## Table of Contents
- [Project Overview](#project-overview)
- [Prerequisites](#prerequisites)
- [Quick Start Guide](#quick-start-guide)
  - [Part 1 — Vagrant k3s Cluster](#part-1--vagrant-k3s-cluster)
  - [Part 2 — Ansible + Multi-App k3s](#part-2--ansible--multi-app-k3s)
  - [Part 3 — k3d + Argo CD (GitHub)](#part-3--k3d--argo-cd-github)
  - [Bonus — GitLab-powered GitOps](#bonus--gitlab-powered-gitops)
- [Project Structure](#project-structure)
- [How It All Fits Together](#how-it-all-fits-together)
- [Verification & Tear Down](#verification--tear-down)
- [Troubleshooting](#troubleshooting)
- [Resources](#resources)

## Project Overview
This repository implements each milestone of the **Inception of Things** course. Every folder contains an isolated automation scenario so you can rehearse Kubernetes fundamentals, configuration management, and GitOps workflows without relying on cloud providers.

### Part-by-part breakdown
| Segment | Goal | Key Tech | Entry Point |
| --- | --- | --- | --- |
| `p1/` | Provision a two-node k3s cluster (server + agent) with Vagrant. | Vagrant, VirtualBox, k3s | `p1/Vagrantfile` |
| `p2/` | Use Ansible to bootstrap k3s and deploy three sample apps with ingress. | Vagrant, Ansible, k3s, NGINX ingress | `p2/Vagrantfile` + `p2/playbooks/deploy.yml` |
| `p3/` | Spin up a k3d cluster, install Argo CD, and sync from GitHub. | k3d, kubectl, Argo CD, GitHub PAT | `p3/scripts/setup` |
| `bonus/` | Self-host GitLab, push manifests, and drive Argo CD via private repo credentials. | Docker, GitLab, k3d, Argo CD, GitOps | `bonus/scripts/setup.sh` |

## Prerequisites
### Common
- Linux host with hardware virtualization enabled.
- Admin access (`sudo`).
- Installed CLI tooling: `git`, `curl`, `ssh-keygen`, `jq`, and `docker` (required for the bonus scenario).

### Virtualization stack (Parts 1 & 2)
- [VirtualBox](https://www.virtualbox.org/) ≥ 7.0
- [Vagrant](https://developer.hashicorp.com/vagrant/downloads) ≥ 2.3
- Optional: [Ansible](https://www.ansible.com/) on the host (Vagrant Ansible provisioner can use the embedded binary on most distros).

### Container stack (Parts 3 & Bonus)
- `docker` running and accessible by your user.
- Outbound HTTPS access for downloading installers and container images.
- GitHub personal access token (PAT) with `repo` scope for Part 3.

> **Resource planning:** Part 1 launches two VMs (1 vCPU/1 GB each). Part 2 launches one stronger VM (2 vCPU/2 GB). Ensure you have ≥ 8 GB RAM free before running multiple segments concurrently.

## Quick Start Guide
Each segment is self-contained—run them independently to focus on the target concept.

### Part 1 — Vagrant k3s Cluster
1. Bring up the controller and worker nodes:
   ```bash
   cd p1
   vagrant up
   ```
2. Connect to the server node and confirm the cluster:
   ```bash
   vagrant ssh amounadiS
   sudo kubectl get nodes
   ```
3. (Optional) Copy the kubeconfig to your host:
   ```bash
   sudo cat /etc/rancher/k3s/k3s.yaml
   ```
   Update the server IP (`192.168.56.110`) if you plan to reuse it locally.

### Part 2 — Ansible + Multi-App k3s
1. Provision the VM and let Ansible install k3s and deploy all manifests:
   ```bash
   cd p2
   vagrant up
   ```
2. Validate the workloads:
   ```bash
   vagrant ssh amounadiS
   kubectl get nodes -o wide
   kubectl get ingress -n part-2
   ```
3. Add hostnames to your `/etc/hosts` (on the **host machine**) to exercise the ingresses:
   ```bash
   echo "192.168.56.110 app1.com app2.com app3.com" | sudo tee -a /etc/hosts
   ```
4. Test from the host:
   ```bash
   curl http://app1.com
   curl http://app2.com
   curl http://app3.com
   ```

### Part 3 — k3d + Argo CD (GitHub)
1. Run the automation script (it installs k3d/kubectl if needed):
   ```bash
   cd p3/scripts
   chmod +x setup
   ./setup
   ```
2. Provide your GitHub username and PAT when prompted. The script will:
   - Create the `iot-cluster` k3d cluster.
   - Install Argo CD in the `argocd` namespace.
   - Register the repo `https://github.com/Mounadi05/amounadi.git`.
   - Apply `p3/config/deploy.yaml`, which syncs manifests into the `dev` namespace.
3. After the script prints the Argo CD credentials, open the UI at <https://localhost:5555> (self-signed cert) and log in with `admin` and the generated password.
4. Confirm the sample app:
   ```bash
   kubectl get applications -n argocd
   kubectl get pods -n dev
   ```

### Bonus — GitLab-powered GitOps
1. Execute the umbrella script (expect a 5–10 min GitLab bootstrap):
   ```bash
   cd bonus/scripts
   chmod +x setup.sh
   ./setup.sh
   ```
2. The stages will:
   - Launch GitLab EE in Docker and capture connection info in `.env`.
   - Create a project, push manifests from `bonus/config/app1`, and generate a PAT.
   - Spin up k3d + Argo CD, configure repository credentials, and deploy the app into the `gitlab` namespace.
3. Watch the output for:
   - GitLab URL (e.g. `http://<host-ip>:9080`) and root password.
   - The Argo CD admin password and forwarded UI URL (`https://localhost:5555`).
4. Inspect the GitOps flow:
   ```bash
   kubectl get applications -n argocd
   kubectl get pods -n gitlab
   ```

## Project Structure
```
Inception-of-Things/
├── p1/                # Vagrant server+agent k3s lab
├── p2/                # Vagrant + Ansible multi-application deployment
├── p3/                # k3d + Argo CD automation (GitHub)
├── bonus/             # Self-hosted GitLab GitOps scenario
└── README.md
```
Key subdirectories:
- `p2/config/` & `bonus/config/`: Kubernetes manifests (deployments, services, ingresses, namespaces).
- `p2/playbooks/`: Ansible play responsible for k3s installation and app rollout.
- `p3/scripts/` & `bonus/scripts/`: Bash automation for cluster creation, Argo CD installation, and repo wiring.

## How It All Fits Together
1. **Local virtualization (Parts 1 & 2)** builds comfort with k3s on VirtualBox VMs while keeping full control over networking.
2. **GitOps with Argo CD (Part 3)** introduces declarative deployments sourced from GitHub, using k3d to avoid heavy virtualization.
3. **Self-hosted GitOps (Bonus)** demonstrates running the entire toolchain yourself—GitLab for source control + pipeline trigger, and Argo CD for reconciliation.

## Verification & Tear Down
- To stop any Vagrant environment:
  ```bash
  vagrant halt
  ```
- To remove Vagrant VMs entirely:
  ```bash
  vagrant destroy -f
  ```
- To remove the k3d cluster created by the scripts:
  ```bash
  k3d cluster delete iot-cluster
  ```
- To clean up the GitLab container:
  ```bash
  docker rm -f gitlab
  rm -rf ~/gitlab
  ```

## Troubleshooting
- **GitLab first-run delay:** The container may take several minutes; the scripts include waits, but you can watch with `docker logs -f gitlab`.
- **Networking issues:** If hostnames do not resolve, verify the `/etc/hosts` entries and that the VirtualBox host-only adapter is active.
- **Argo CD login fails:** Ensure the port-forwarding process is still running (`ps aux | grep argocd-server`). Re-run the script if needed.
- **Permission errors:** Run the scripts from a user that can execute `docker` without `sudo`, or prepend `sudo` where appropriate.
- **Idempotency:** Rerunning scripts is mostly safe; when in doubt, clean previous clusters/containers before re-executing.

## Resources
- [k3s Documentation](https://docs.k3s.io/)
- [k3d Documentation](https://k3d.io/)
- [Argo CD Getting Started](https://argo-cd.readthedocs.io/en/stable/getting_started/)
- [GitLab Documentation](https://docs.gitlab.com/)
- [Vagrant Docs](https://developer.hashicorp.com/vagrant/docs)
