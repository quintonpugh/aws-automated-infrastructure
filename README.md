# Automated AWS Infrastructure Provisioning

## Business Problem

Engineers were provisioning AWS infrastructure manually through the AWS Management Console. This made deployments slower, inconsistent, difficult to reproduce, and vulnerable to configuration drift and human error.

## Solution

I designed and implemented a Git-driven Infrastructure-as-Code workflow using Terraform, Jenkins, GitHub, and AWS.

Infrastructure changes are defined in Terraform and version-controlled in GitHub. Jenkins retrieves the repository and executes an automated pipeline that validates the Terraform configuration, generates a deployment plan, pauses for human approval, and applies the approved plan to AWS.

The deployed environment includes a configured EC2 web server running Nginx, demonstrating that the workflow can provision both infrastructure and a functional workload without manually configuring the target server.

## Architecture

```text
Engineer
   |
   v
GitHub
   |
   v
Jenkins
   |
   +--> Terraform Format Check
   +--> Terraform Init
   +--> Terraform Validate
   +--> Terraform Plan
   +--> Human Approval
   +--> Terraform Apply
   |
   v
AWS
   |
   +--> VPC
   +--> Internet Gateway
   +--> Public Subnet
   +--> Route Table
   +--> Security Group
   +--> IAM Role / Instance Profile
   +--> EC2
          |
          +--> Automated Nginx Configuration

## Technologies

- AWS EC2
- Amazon VPC
- AWS IAM
- AWS Systems Manager Session Manager
- Terraform
- Jenkins
- Git / GitHub
- Amazon Linux 2023
- Nginx

## Infrastructure as Code

Terraform provisions the target environment, including:

- VPC and Internet Gateway
- Public subnet and route table
- HTTP security group
- EC2 IAM role and instance profile
- Amazon Linux EC2 instance
- Automated Nginx installation and configuration

The Amazon Linux AMI is dynamically discovered rather than hardcoded. Terraform `user_data` installs Nginx, creates the validation webpage, enables the service, and starts it automatically.

## CI/CD Workflow

The Jenkins pipeline performs:

1. Source checkout from GitHub
2. Terraform format check
3. Terraform initialization
4. Terraform validation
5. Terraform plan
6. Human approval
7. Terraform apply using the saved plan

The approval gate ensures infrastructure changes are reviewed before deployment.

## Security Controls

Security was incorporated into the implementation rather than added only after deployment:

- Jenkins authenticates to AWS through an EC2 IAM instance role instead of stored long-lived AWS credentials.
- Jenkins administration uses AWS Systems Manager Session Manager instead of SSH.
- The target EC2 instance has no SSH ingress.
- The target EC2 instance uses its own IAM instance profile.
- IMDSv2 is required on the EC2 workload.
- Workload ingress is limited to HTTP port 80.
- Jenkins port 8080 was restricted to the operator's public IPv4 address during the proof of concept.
- Infrastructure deployment permissions are assigned through a dedicated Jenkins IAM role.

## Validation

The Jenkins pipeline successfully provisioned the environment through the human approval and Terraform apply stages.

Terraform reported:

```text
Apply complete! Resources: 10 added, 0 changed, 0 destroyed.
```

The deployed EC2 instance was then validated through Systems Manager Session Manager.

```text
$ whoami
ssm-user

$ sudo systemctl is-active nginx
active

$ curl -I http://localhost
HTTP/1.1 200 OK
```

The externally accessible validation page displayed:

```text
Infrastructure Provisioned Successfully

This EC2 server was deployed using Terraform.

Deployment workflow: Git -> Jenkins -> Terraform -> AWS
```

A subsequent Terraform plan returned:

```text
No changes. Your infrastructure matches the configuration.
```

This confirmed that the deployed AWS environment matched the Terraform configuration after deployment.

## Troubleshooting and Engineering Decisions

### Jenkins Runtime Requirement

Jenkins initially failed to start because the installed Java version did not meet the requirement of the Jenkins release. Service logs identified the incompatibility, Java 21 was installed, and Jenkins started successfully.

### Jenkins Executor Offline

The Jenkins built-in node was marked offline because `/tmp` was a small tmpfs filesystem that could not satisfy Jenkins' default 1 GiB free-space threshold.

The root EBS filesystem had sufficient capacity, confirming that the instance itself was not out of disk space. The temporary-space threshold was adjusted for the proof of concept, and Terraform runtime data was moved to persistent EBS-backed Jenkins storage.

### Jenkins Network Access

Jenkins was initially unreachable from the browser because the security group contained the AWS CloudShell egress IP rather than the operator's browser IP.

Local testing confirmed that Jenkins itself was healthy and listening on port 8080. The security-group source was then corrected to the operator's current public IPv4 address instead of exposing Jenkins to all internet traffic.

### AWS Authentication

The Jenkins service account was tested with AWS STS to confirm that it inherited temporary credentials through the EC2 instance profile. No static AWS access keys were required by the pipeline.

## Production Improvements

A production implementation would extend this proof of concept with:

- Dedicated Jenkins agents rather than running builds on the controller
- Private Jenkins connectivity with HTTPS and stable DNS
- Encrypted remote Terraform state with appropriate state locking
- More granular IAM resource and tag restrictions
- Automated security and policy checks before deployment
- Separate development, staging, and production workflows
- Automated source-control triggers where appropriate
- Additional workload availability controls based on business requirements

## Result

The project replaced manual AWS console provisioning with a repeatable Git-driven Infrastructure-as-Code workflow.

Infrastructure definition, validation, planning, human approval, deployment, workload configuration, and drift detection were demonstrated as a reproducible process rather than a sequence of manual console operations.

## Project Status

**Completed — infrastructure automated through Terraform and Jenkins, deployment validated, security controls verified, and zero configuration drift confirmed.**
