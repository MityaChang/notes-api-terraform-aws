Full‑Stack + Terraform on AWS 
Goal
Deliver a small production‑ready REST API and the Terraform infrastructure to host it on
AWS, with attention to security, logging and a GitLab CI deployment pipeline.
Select and justify all service/technology choices (compute, storage, etc.).
Requirements
• Candidate must choose and justify AWS services used for compute, storage and
API exposure.
• Terraform must be modular and parameterised:
o Separate modules or files for network, compute, storage and IAM.
o Use variables and outputs; avoid hardcoded ARNs/credentials.
o Recommend or document remote state management (S3 + locking or
explanation if local).
• Security:
o IAM roles/policies should follow least privilege.
o Network access controls must be defined (security groups/NACLs or
rationale if omitted).
o Storage must be encrypted at rest.
• Logging & observability:
o Application and infrastructure logs must be enabled and retrievable
o Set a reasonable retention period and document where logs are found.
• CI/CD:
o Pipeline produces a Terraform plan artifact and requires a manual deploy
to apply changes.
o CI variables used for AWS credentials and other secrets; document
required variables.
o Do not perform automatic applies on merge.
Duration
• Candidate will have up to a week to complete the project.
• Estimated time needed to complete: 12–20 hours (1–2 days).
Deliverables
• Application source code for the REST API (language/framework chosen by
candidate).
• Infrastructure as Code using Terraform that provisions networking, compute,
storage and logging on AWS.
• A GitLab CI pipeline (.gitlab-ci.yml) that:
o Runs terraform fmt/validate and produces a terraform plan.
o Builds/publishes artifacts or container images (if applicable).
o Includes a manual deploy job for terraform apply (or equivalent).
o Uses CI variables for secrets — no hardcoded credentials.
• README describing architecture, deployment steps, required CI variables, and
how the evaluator can verify the system.
• Optional: container image artifact or terraform plan file as produced by CI.
Scope & constraints
• One CRUD resource (e.g., "note" with id, title, body, created_at).
• Do not commit secrets or credentials.
• Use cost‑safe defaults (serverless/small instances, manual deployment step).
• Provide clear README that allows an evaluator to verify the work.
Submission
• Provide a public or private Git repository URL with the following at repo root:
o app/ (application source)
o infra/ or terraform/ (Terraform code)
o .gitlab-ci.yml
o README.md (instructions for evaluator)
• Optionally provide a short architecture diagram (image or ASCII) in the README.
The assignment is intentionally open on implementation details; assess candidates on
clarity of choices, Terraform best practices, security posture and CI workflow rather
than on specific AWS services chosen.