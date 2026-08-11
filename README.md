<div align="center">

#  DevSecOps Automated Pipeline

**Declarative infrastructure and automated lightweight Kubernetes deployment on Microsoft Azure.**

Terraform · Ansible · K3s · Azure · Security-First

<img width="1536" height="1024" alt="Designer (2)" src="https://github.com/user-attachments/assets/cf0b4f3d-7fa8-4b7a-93a3-27e7d8774c53" />


[Architecture](#-architecture--bootstrap-sequence) · [Post-Mortem](#-engineering-post-mortem) · [Quickstart](#-quickstart) · [Roadmap](#-roadmap)

</div>

---

##  Table of Contents

- [Overview](#-overview)
- [Architecture & Bootstrap Sequence](#-architecture--bootstrap-sequence)
- [Repository Structure](#-repository-structure)
- [Engineering Post-Mortem](#-engineering-post-mortem)
- [Quickstart](#-quickstart)
- [Roadmap](#-roadmap)
- [License](#-license)

---

##  Overview

This repository implements an end-to-end **DevSecOps** pipeline that automates three critical layers of modern infrastructure:

| Layer | Tool | Responsibility |
|-------|------|----------------|
| **Infrastructure** | Terraform | Declarative provisioning of Azure resources (VNet, VM, NSG) |
| **Configuration** | Ansible | OS hardening and runtime orchestration (agentless) |
| **Orchestration** | K3s | Lightweight Kubernetes with secure context isolation |

> **Philosophy:** *Infrastructure as Code* with clean separation of state between cloud provisioning and OS configuration, applying the **Principle of Least Privilege** at every layer.

---

##  Architecture & Bootstrap Sequence

The architecture follows a **decoupled layered model** where infrastructure state never mixes with software configuration.

<img width="1536" height="1024" alt="Designer (3)" src="https://github.com/user-attachments/assets/dd6f1f0d-a00a-47ef-a8ef-967a26dd7cc5" />


###  Security Model

- **Network:** NSG restricts ingress to essential ports (SSH/22, K8s API/6443) from the administrative IP only.
- **Identity:** Azure authentication via OIDC (no secrets in code).
- **Access:** The `devsecops` (non-root) user can audit the cluster without root privileges.

---

##  Repository Structure

```
devsecops-pipeline/
├── infra/
│   ├── main.tf           # Core Azure resources (VM, VNet, NSG)
│   └── providers.tf      # Azure OIDC configuration + provider constraints
├── ansible/
│   ├── inventory.ini     # Host mapping and SSH authentication
│   ├── playbook.yml      # OS-level baseline hardening
│   └── k8s_setup.yml     # K3s installation and secure configuration
└── README.md
```

### Key Files

| File | Purpose | View |
|------|---------|------|
| `infra/main.tf` | Core resources: `azurerm_linux_virtual_machine`, `azurerm_network_security_group` | [View](infra/main.tf) |
| `infra/providers.tf` | `azurerm` provider with `skip_provider_registration = true` and OIDC | [View](infra/providers.tf) |
| `ansible/inventory.ini` | Dynamic host mapping with key-based SSH | [View](ansible/inventory.ini) |
| `ansible/playbook.yml` | Tasks: base packages, hardening, users | [View](ansible/playbook.yml) |
| `ansible/k8s_setup.yml` | K3s installation with security flags | [View](ansible/k8s_setup.yml) |

---

##  Engineering Post-Mortem

Documentation of critical issues resolved during development. Each entry includes **symptom**, **diagnosis**, and **resolution**.

### 1. Azure Provider Registration Hang

| Field | Detail |
|-------|--------|
| **Symptom** | `terraform plan` hangs indefinitely at `Read complete after 0s` |
| **Diagnosis** | Azure subscription restrictions blocked auto-registration of non-essential Resource Providers |
| **Resolution** | Added `skip_provider_registration = true` to the `azurerm` provider block in [`infra/providers.tf`](infra/providers.tf). Identified via debug: `TF_LOG=INFO terraform plan` |

### 2. Ansible Inventory Context Failure

| Field | Detail |
|-------|--------|
| **Symptom** | `[WARNING]: No inventory was parsed, only implicit localhost is available` |
| **Diagnosis** | The `ansible-playbook` command did not reference `inventory.ini`, causing tasks to run on `localhost` instead of the remote Azure VM |
| **Resolution** | Standardized execution to always require explicit inventory: `ansible-playbook -i inventory.ini <playbook>` |

### 3. K3s Non-Root Access Isolation

| Field | Detail |
|-------|--------|
| **Symptom** | The `devsecops` user cannot run `kubectl` (permission denied) |
| **Diagnosis** | K3s creates `kubeconfig` with `0600` permissions (root-only) by default |
| **Resolution** | Injected `INSTALL_K3S_EXEC="server --write-kubeconfig-mode 644"` during installation in [`ansible/k8s_setup.yml`](ansible/k8s_setup.yml). Enables non-root cluster auditing while maintaining secure defaults |

---

##  Quickstart

### Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/downloads) ≥ 1.5
- [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/index.html) ≥ 2.14
- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) authenticated (`az login`)
- SSH key pair (`~/.ssh/id_rsa.pub` available)

### Phase 1: Infrastructure as Code

```bash
cd infra/

# Initialize providers and modules
terraform init -upgrade

# Review execution plan
terraform plan -out=tfplan

# Apply infrastructure
terraform apply tfplan

# Save public IP for Ansible
terraform output -raw public_ip > ../ansible/vm_ip.txt
```

> **Note:** The first `terraform apply` may take ~3-5 minutes while Azure provisions the VM.

### Phase 2: Configuration Management

```bash
cd ../ansible/

# Update inventory.ini with VM IP (automated or manual)
sed -i "s/<VM_IP>/$(cat vm_ip.txt)/g" inventory.ini

# 2.1 OS Baseline: hardening + essential packages
ansible-playbook -i inventory.ini playbook.yml

# 2.2 Kubernetes: install and configure K3s
ansible-playbook -i inventory.ini k8s_setup.yml
```

### Verification

```bash
# Connect to the VM and verify the cluster
ssh -i ~/.ssh/id_rsa devsecops@$(cat vm_ip.txt)
kubectl get nodes
kubectl get pods -A
```

---

##  Roadmap

| Version | Status | Scope |
|---------|--------|-------|
| **v0.1** | ✅ Completed | Terraform + Ansible + K3s (Foundation) |
| **v0.2** | 🔄 In Progress | CI/CD Pipeline (GitHub Actions) + SAST/DAST (Trivy, SonarQube) |
| **v0.3** | 📋 Planned | Observability (Prometheus + Grafana + Loki) |
| **v0.4** | 📋 Planned | Policy-as-Code (OPA/Gatekeeper) + Secret Management (Vault) |

---

## 🤝 Contributing

Contributions are welcome. Please open an **Issue** to report bugs or a **Pull Request** with improvements. Follow [Conventional Commits](https://www.conventionalcommits.org/) style.

---

## 📄 License

MIT © 2026 Luis Salazar

---

<div align="center">

**[⬆ Back to Top](#-devsecops-automated-pipeline)**

</div>
