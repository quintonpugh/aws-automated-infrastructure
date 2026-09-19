# Standard Operating Procedure — Automated AWS Infrastructure Provisioning

## Purpose

This SOP documents the implementation, validation, troubleshooting, security controls, and teardown process for the Automated AWS Infrastructure Provisioning project.

## Business Requirement

The environment was designed to replace manual AWS console provisioning with a repeatable Git-driven Infrastructure-as-Code workflow.

The implementation needed to demonstrate:

- Version-controlled infrastructure definitions
- Automated Terraform validation and planning
- Human approval before infrastructure changes
- Automated AWS deployment
- Automated workload configuration
- Role-based AWS authentication without static pipeline credentials
- Secure administrative access
- Functional validation
- Configuration-drift validation
- Clean teardown after project completion

## Architecture

Deployment workflow:

Engineer -> GitHub -> Jenkins -> Terraform -> AWS

Jenkins pipeline stages:

1. Checkout
2. Terraform Format Check
3. Terraform Init
4. Terraform Validate
5. Terraform Plan
6. Human Approval
7. Terraform Apply

Terraform provisions:

- VPC
- Internet Gateway
- Public subnet
- Route table and association
- Security group
- EC2 IAM role
- EC2 instance profile
- Amazon Linux EC2 instance
- Automated Nginx configuration

## Jenkins Controller

The Jenkins controller was bootstrapped separately from the Terraform-managed target environment.

This separation was intentional for the proof of concept: Jenkins acts as the deployment system responsible for creating the target infrastructure and therefore must exist before the target Terraform workflow can execute.

The controller uses:

- Amazon Linux 2023
- Jenkins
- Java 21
- Terraform
- Git
- AWS Systems Manager Session Manager
- A dedicated EC2 IAM role and instance profile

Jenkins authenticates to AWS using temporary credentials supplied through the EC2 instance profile. No long-lived AWS access keys are stored in the Jenkins pipeline.

## Terraform Deployment

Terraform dynamically discovers an Amazon Linux 2023 AMI and creates the target environment.

The EC2 workload uses `user_data` to:

1. Update package metadata
2. Install Nginx
3. Create the project validation webpage
4. Enable Nginx
5. Start Nginx

The target instance requires IMDSv2 and does not expose SSH.

## Security Controls

Implemented controls include:

- Dedicated IAM role for Jenkins
- EC2 instance-profile authentication
- No static AWS credentials in Jenkins
- Systems Manager Session Manager for administration
- No inbound SSH access to the target EC2 instance
- IMDSv2 required on the target workload
- Dedicated target EC2 IAM role
- HTTP-only workload security-group ingress
- Jenkins port 8080 restricted to the operator's current public IPv4 address during the proof of concept
- Human approval before Terraform apply

The Jenkins deployment policy was intentionally broad enough to support the proof-of-concept resource lifecycle. A production implementation should further restrict resources using appropriate ARNs, tags, conditions, and environment boundaries.

## Deployment Validation

The initial Terraform plan identified:

10 resources to add, 0 to change, and 0 to destroy.

The Jenkins pipeline successfully completed all deployment stages and paused for manual approval before applying the saved Terraform plan.

Terraform completed successfully with:

Apply complete! Resources: 10 added, 0 changed, 0 destroyed.

## Workload Validation

The target EC2 instance was accessed through Systems Manager Session Manager.

Validation included:

- Confirming the administrative identity
- Confirming Nginx was active
- Confirming the local HTTP endpoint returned HTTP 200
- Confirming the externally accessible project webpage loaded successfully

The validation webpage identified the deployment workflow as:

Git -> Jenkins -> Terraform -> AWS

## Drift Validation

After successful deployment and workload validation, the pipeline was executed again through the Terraform planning stage.

Terraform reported:

No changes. Your infrastructure matches the configuration.

This confirmed that the deployed AWS environment matched the desired Terraform configuration.

## Troubleshooting Record

### AWS Account and Region Context

During setup, resources initially appeared to be missing because the AWS console and shell context were not always operating in the intended workload account and region.

The active AWS identity and region were verified before continuing.

Lesson:

Always verify AWS identity and region before diagnosing an apparently missing resource.

### CloudShell vs EC2 Session

Jenkins installation commands were initially executed from AWS CloudShell instead of the intended EC2 Systems Manager session.

The environment was identified by checking the operating user and system context.

The installation was then performed on the correct Jenkins controller.

Lesson:

Verify the execution environment before making host-level changes.

### Jenkins Java Version

Jenkins initially failed because the installed Java version did not satisfy the Jenkins release requirement.

Service logs identified the runtime incompatibility.

Java 21 was installed and selected, after which Jenkins started successfully.

Lesson:

Use service logs to diagnose application startup failures instead of assuming network or firewall problems.

### Jenkins Browser Connectivity

Jenkins was running and responding locally but could not initially be reached from the operator's browser.

Local HTTP testing proved that the Jenkins service itself was healthy.

The security-group source had been configured using the CloudShell egress IP instead of the operator's browser public IP.

The source was corrected to the operator's current public IPv4 address.

Lesson:

Separate application-health testing from network-path testing before changing firewall rules.

### Jenkins Node Offline

The Jenkins built-in node was marked offline because Jenkins expected at least 1 GiB of free temporary space.

The `/tmp` filesystem was a small tmpfs filesystem that could not satisfy that threshold even though the root EBS filesystem had sufficient free capacity.

For the proof of concept, the Jenkins temporary-space threshold was adjusted and Terraform runtime data was moved to persistent EBS-backed Jenkins storage.

Terraform data directory:

/var/lib/jenkins/.terraform-data/project2

Lesson:

Filesystem capacity and filesystem layout must be evaluated separately. Overall instance disk availability does not guarantee that an individual mount point can satisfy an application's threshold.

### Git Authentication

A fresh CloudShell environment required Git identity configuration and SSH authentication before repository changes could be pushed to GitHub.

SSH host trust and key authentication were configured before pushing the updated pipeline.

Lesson:

Git commit identity and Git remote authentication are separate requirements and should be validated independently.

## Production Recommendations

A production implementation should consider:

- Dedicated Jenkins agents
- Private Jenkins connectivity
- HTTPS and stable DNS
- Encrypted remote Terraform state with appropriate locking
- More granular IAM resource and tag conditions
- Separate development, staging, and production workflows
- Automated security and policy validation
- Source-control webhook or equivalent automated triggers
- Centralized logging and monitoring
- Backup and recovery requirements for the CI/CD platform
- Highly available application architecture when justified by business requirements

## Teardown Procedure

The Terraform-managed target infrastructure must be destroyed before terminating the Jenkins controller because the active Terraform state is stored with the Jenkins deployment workspace.

Teardown order:

1. Preserve required project evidence and documentation.
2. Confirm the Git repository contains no Terraform state or sensitive runtime data.
3. Destroy the Terraform-managed target infrastructure using the existing Terraform state.
4. Verify the target VPC, subnet, routing, security group, IAM resources, and EC2 workload were removed.
5. Terminate the Jenkins controller.
6. Remove project-specific Jenkins bootstrap resources that are no longer required.
7. Verify that no project-specific billable resources remain.

Do not delete shared AWS Organizations resources, workload-account access roles, default VPC resources, or other infrastructure that was not created specifically for this project.

## Final Status

Implementation and validation completed successfully.

The project demonstrated a repeatable Git-driven Terraform deployment through Jenkins, role-based AWS authentication, human deployment approval, automated EC2 workload configuration, security controls, functional validation, troubleshooting, and zero-drift verification.
