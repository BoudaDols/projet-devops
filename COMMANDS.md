# Commands Reference

Quick reference for every command used during deployment and operations.

---

## kubectl

### Inspection

| Command | Purpose |
|---|---|
| `kubectl get all -n default` | List all resources in the default namespace |
| `kubectl get pods -n default` | List pods and their status |
| `kubectl get nodes` | List cluster nodes and their status |
| `kubectl get secrets -n default` | List all secrets |
| `kubectl get events -n default --sort-by='.lastTimestamp'` | List cluster events sorted by time |
| `kubectl get secret <name> -n default -o jsonpath='{.data.<key>}' \| base64 -d` | Decode a secret value |
| `kubectl logs <pod> -n default` | Get pod logs |
| `kubectl logs <pod> -n default -c <container>` | Get init container logs |
| `kubectl describe pod <pod> -n default` | Get detailed pod info including events |

### Deployments

| Command | Purpose |
|---|---|
| `kubectl apply -f <file.yaml>` | Apply a manifest |
| `kubectl rollout restart deployment/<name> -n default` | Restart a deployment |
| `kubectl rollout status deployment/<name> -n default --timeout=120s` | Wait for rollout to complete |
| `kubectl set image deployment/<name> <container>=<image>:<tag> -n default` | Update deployment image |
| `kubectl delete <type> <name> -n default --ignore-not-found` | Delete a resource safely |

### Secrets

| Command | Purpose |
|---|---|
| `kubectl create secret generic <name> --namespace=default --from-literal=KEY="VALUE" --dry-run=client -o yaml \| kubectl apply -f -` | Create or update a secret |
| `kubectl delete secret <name> -n default` | Delete a secret |

### Context switching

| Command | Purpose |
|---|---|
| `kubectl config get-contexts` | List all available clusters |
| `kubectl config use-context docker-desktop` | Switch to local cluster |
| `aws eks update-kubeconfig --region us-east-1 --name proj-devops-eks` | Switch to EKS cluster |
| `az aks get-credentials --resource-group proj-devops-rg --name proj-devops-aks --overwrite-existing` | Switch to AKS cluster |

---

## AWS CLI

| Command | Purpose |
|---|---|
| `aws sts get-caller-identity` | Verify current IAM identity and credentials |
| `aws sso login` | Refresh SSO session when credentials expire |
| `aws eks list-clusters --region us-east-1` | List EKS clusters |
| `aws eks describe-cluster --name proj-devops-eks --query 'cluster.status' --output text` | Check EKS cluster status |
| `aws eks list-nodegroups --cluster-name proj-devops-eks` | List node groups |
| `aws eks describe-nodegroup --cluster-name proj-devops-eks --nodegroup-name <name> --query 'nodegroup.status' --output text` | Check node group status |
| `aws eks update-kubeconfig --region us-east-1 --name proj-devops-eks` | Update local kubeconfig for EKS |
| `aws account show --query id -o tsv` | Get AWS account ID |

---

## Azure CLI

| Command | Purpose |
|---|---|
| `az login` | Log in to Azure |
| `az account show --query id -o tsv` | Get subscription ID |
| `az aks list --output table` | List AKS clusters |
| `az aks show --resource-group proj-devops-rg --name proj-devops-aks --query 'provisioningState' -o tsv` | Check AKS cluster status |
| `az aks get-credentials --resource-group proj-devops-rg --name proj-devops-aks --overwrite-existing` | Update local kubeconfig for AKS |
| `az ad sp create-for-rbac --name "proj-devops-github" --role Contributor --scopes /subscriptions/<id> --sdk-auth` | Create service principal for GitHub Actions |
| `az group create --name <name> --location eastus2` | Create a resource group |
| `az storage account create --name <name> --resource-group <rg> --sku Standard_LRS` | Create a storage account |
| `az storage container create --name tfstate --account-name <name>` | Create a blob container |

---

## Terraform

### Initialization

| Command | Purpose |
|---|---|
| `terraform init` | Initialize — downloads providers and modules |
| `terraform init -reconfigure` | Reinitialize with a different backend config |
| `terraform init -migrate-state` | Reinitialize and migrate state to new backend |

### Planning and applying

| Command | Purpose |
|---|---|
| `terraform plan` | Preview changes without applying |
| `terraform apply` | Apply changes (prompts for confirmation) |
| `terraform apply -auto-approve` | Apply without confirmation prompt |
| `terraform apply -target=<resource>` | Apply only a specific resource |
| `terraform apply -lock=false` | Apply without state locking — use only when lock is stale |
| `terraform fmt -recursive` | Format all .tf files |
| `terraform validate` | Validate configuration syntax |

### State management

| Command | Purpose |
|---|---|
| `terraform state list` | List all resources tracked in state |
| `terraform state show <resource>` | Show details of a resource in state |
| `terraform state rm <resource>` | Remove a resource from state without destroying it |
| `terraform import <resource> <id>` | Import an existing resource into state |
| `terraform force-unlock -force <lock-id>` | Force unlock a stale state lock |
| `aws s3 rm s3://proj-devops-tfstate/<path>/terraform.tfstate` | Delete a state file from S3 — full reset |

### Import script

| Command | Purpose |
|---|---|
| `cd terraform/aws-k8s && ./import.sh` | Import all existing k8s resources into aws-k8s state — skips already imported ones |

---

## Docker

| Command | Purpose |
|---|---|
| `docker build -t <name>:latest .` | Build a Docker image |
| `docker build -t abonnement:latest ./abonnement` | Build abonnement image locally |
| `docker build -t api-gateway:latest ./api-gateway` | Build api-gateway image locally |

---

## Troubleshooting

### Diagnose pod scheduling issues

| Command | Purpose |
|---|---|
| `kubectl get pods -n default` | Check pod status (Pending, Running, CrashLoopBackOff) |
| `kubectl describe pod -l app=<name> -n default` | Get detailed pod info and events (scheduling errors, image pull errors) |
| `kubectl logs -l app=<name> --tail=50 -n default` | Get last 50 lines of pod logs |
| `kubectl logs -l app=<name> --all-containers -n default` | Get logs from all containers including init containers |
| `kubectl get pvc -n default` | Check persistent volume claims status |
| `kubectl describe pvc <name> -n default` | Get PVC details (storage provisioner errors) |
| `kubectl get storageclass` | List available storage classes |
| `kubectl get pods -n kube-system \| grep ebs-csi` | Check if EBS CSI driver is running |
| `kubectl get configmap aws-auth -n kube-system -o yaml` | Check which IAM users/roles have EKS access |

### Fix Terraform state issues

| Command | Purpose |
|---|---|
| `terraform state rm module.k8s_apps.kubernetes_deployment.abonnement` | Remove corrupted deployment from state |
| `terraform state rm module.k8s_apps.kubernetes_deployment.api_gateway` | Remove corrupted deployment from state |
| `terraform state rm module.k8s_apps.kubernetes_deployment.api_gateway_mysql` | Remove corrupted deployment from state |
| `terraform state rm module.k8s_apps.kubernetes_deployment.abonnement_mysql` | Remove corrupted deployment from state |

---


| Command | Purpose |
|---|---|
| `kubectl proxy` | Start proxy to access the dashboard locally |
| `kubectl -n kubernetes-dashboard create token admin-user` | Generate a new login token (expires in 1 hour) |

Dashboard URL: `http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/`
