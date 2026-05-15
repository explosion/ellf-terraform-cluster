# terraform-ellf-cluster

Terraform modules and workspaces for provisioning an [Ellf](https://ellf.ai) cluster on a managed Kubernetes service in GCP, AWS, or Azure.

## About Ellf

**[Ellf](https://ellf.ai)** (short for [Explosion](https://explosion.ai) Large Language Framework) is an interactive, AI-powered assistant for Natural Language Processing (NLP) and machine learning projects. It integrates with your coding assistant (like Claude Code) and provides a fully data-private cluster — running locally or in the cloud under your control — that handles annotation, training, evaluation, and deployment.

This repository contains the Terraform that provisions that cluster. For product documentation — what Ellf is, how to install the CLI, and how the cluster fits into the platform — see <https://ellf.ai/docs/cluster>.

## What this provisions

Each workspace creates a private-by-default Kubernetes cluster with the supporting infrastructure an Ellf deployment needs:

- A managed Kubernetes cluster with private nodes and a public API endpoint
- A managed PostgreSQL database, reachable only from inside the VPC
- A managed NFS share, exposed to the cluster as a `ReadWriteMany` PV / PVC
- A container registry and an object storage bucket
- A Kubernetes namespace, a `Secret` containing the database password and a broker keypair, and the IAM glue that lets pods talk to cloud services

The Ellf helm chart, which deploys the application onto the cluster, lives elsewhere.

## Repository layout

```
modules/
  gcp/
    database/    # Cloud SQL for PostgreSQL (private IP only)
    gke/         # GKE cluster, node pools, Filestore NFS, IAM, namespace + secrets
  aws/
    database/    # RDS for PostgreSQL (private subnets only)
    eks/         # EKS cluster, managed node groups, EFS NFS, IAM, namespace + secrets
  azure/
    database/    # PostgreSQL Flexible Server (private networking only)
    aks/         # AKS cluster, node pools, Azure Files NFS, namespace + secrets

workspaces/
  gcp-k8s/       # GCP workspace wiring VPC + Artifact Registry + GCS + database + cluster
  aws-k8s/       # AWS workspace wiring VPC + ECR + S3 + database + cluster
  azure-k8s/     # Azure workspace wiring VNet + ACR + Storage + database + cluster
```

## Usage

The `ellf` CLI can download a packaged version of these modules and run terraform for you; see the [cluster docs](https://ellf.ai/docs/cluster) for the high-level flow. To run terraform directly:

```bash
cd workspaces/gcp-k8s   # or aws-k8s, azure-k8s
terraform init
terraform plan  -var-file=your.tfvars
terraform apply -var-file=your.tfvars
```

Each workspace's `variables.tf` documents the required inputs (project / region, domain, worker node pool definitions, etc.). Outputs include the cluster endpoint, the credentials command (`gcloud container clusters get-credentials`, `aws eks update-kubeconfig`, or `az aks get-credentials`), and the NFS PVC and infra secret names that the Ellf helm chart consumes.

## Cross-cloud parity

All three workspaces produce the same logical shape — private cluster, private database, NFS-backed `ReadWriteMany` PVC, and a single `ellf-infra` Kubernetes secret containing the broker keypair and the database password. Workloads written against one cloud's cluster should run on the others without changes.

## License

[MIT](LICENSE).
