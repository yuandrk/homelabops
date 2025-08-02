---
created: 2025-07-26
tags:
  - terraform
  - aws
---

## 📝 Summary of Terraform + AWS Backend Setup Chat

### Overview

The conversation walks through bootstrapping a secure **Terraform backend on AWS** for a HomeLab project. It covers creating an IAM user, provisioning S3 + DynamoDB with Terraform, troubleshooting `terraform init`, and cleaning the repo before publishing.

---

### Key Steps & Decisions

1. **IAM Setup**
   - Manually create IAM user **`terraform`**.
   - Generate Access Key + Secret Key.
   - Attach **least-privilege inline policy**:
     - S3: `Get/Put/Delete/List` on `terraform-homelab-state` bucket.
     - DynamoDB: CRUD on `terraform-homelab-lock` table.

2. **AWS CLI & Provider Configuration**
   - Store keys in AWS profile `terraform` (`aws configure --profile terraform`) or use environment vars.
   - In Terraform `provider "aws"` and backend block, reference the same profile.

3. **Bootstrap Module Structure**
   ```
   bootstrap/
   ├── main.tf
   ├── versions.tf
   ├── variables.tf
   └── backend.tf   (added after resources exist)
   ```
   - **Resources** created:
     - `aws_s3_bucket` (`terraform-homelab-state`)
     - Public-access block
     - Separate resources for **versioning**, **SSE-AES256**, and **lifecycle rule** (≥ v4 provider requirement)
     - `aws_dynamodb_table` (`terraform-homelab-lock`)

4. **Troubleshooting & Fixes**
   - **`Argument definition required`** → fix one-line nested block.
   - **Duplicate provider** → keep a single `provider "aws"` block.
   - Convert inline `versioning`, `lifecycle_rule`, `server_side_encryption_configuration` to standalone resources.
   - Lifecycle warning resolved by adding `filter { prefix = "" }`.

5. **Planning & Applying**
   - Use `terraform plan -out plan.bin` → `terraform apply plan.bin` to guarantee the same plan.
   - After successful `apply`, S3 bucket & DynamoDB table exist.

6. **Migrating State to Remote Backend**
   - Add `backend "s3"` block in `backend.tf`.
   - Run `terraform init -reconfigure -migrate-state`; confirm S3 `bootstrap.tfstate` and DynamoDB lock entries.

---

### Repo Hygiene & CI Readiness

| File/Dir                                                    | Action                                                          |
| ----------------------------------------------------------- | --------------------------------------------------------------- |
| `terraform.tfstate*`, `*.tfplan`, `plan.bin`, `.terraform/` | **Ignore** in Git                                               |
| `.terraform.lock.hcl`                                       | *Commit* for reproducible provider versions                     |
| `.gitignore` sample                                         | `*.tfstate*`, `*.tfplan`, `plan.bin`, `.terraform/`, `*.tfvars` |

---

### Final Validation Checklist

- `terraform plan` ➜ **No changes**.
- `terraform state list` shows all backend resources.
- `aws s3 ls` & `aws dynamodb describe-table` confirm remote state & lock.
- Formatting (`terraform fmt`) and syntax (`terraform validate`) pass cleanly.

System ready for additional Terraform modules; backend is secure, versioned, and team-friendly.
