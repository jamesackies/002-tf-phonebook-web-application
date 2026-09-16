# Project 002 - Phonebook Application

A full-stack web application built with Python Flask, deployed on AWS using an Application Load Balancer, Auto Scaling Group, and RDS MySQL — all provisioned with Terraform.

---

## Architecture Overview

```
Internet
   |
   v
Application Load Balancer (HTTP :80)
   |
   v
Auto Scaling Group (min:1, desired:2, max:3)
   EC2 Instances (Amazon Linux 2, t2.micro)
   - Flask app running on port 80
   |
   v
RDS MySQL Instance (db.t3.micro, MySQL 8.0.19)
```

---

## Project Structure

```
002-tf-phonebook-web-application/
|---- README.md
|---- main.tf                  # Terraform infrastructure config
|---- phonebook-app.py         # Python Flask application
|---- templates/
        |---- index.html       # Search page
        |---- add-update.html  # Add/Update page
        |---- delete.html      # Delete page
```

---

## Technologies Used

| Layer | Technology |
|-------|-----------|
| Application | Python 3, Flask, flask-mysql |
| Database | AWS RDS MySQL 8.0.19 |
| Load Balancing | AWS Application Load Balancer |
| Compute | AWS EC2 (Amazon Linux 2, t2.micro) |
| Scaling | AWS Auto Scaling Group + Launch Template |
| Networking | AWS VPC, Security Groups |
| IaC | Terraform |
| Version Control | Git / GitHub |

---

## Features

- Search contacts by name (case-insensitive)
- Add new contacts with input validation
- Update existing contact phone numbers
- Delete contacts by name
- Input validation:
  - Name cannot be empty or numeric
  - Phone number cannot be empty or non-numeric
  - Names are stored in lowercase, displayed in Title Case

---

## AWS Resources Created by Terraform

- **Security Group (ALB)** — allows HTTP (port 80) from anywhere
- **Security Group (EC2)** — allows HTTP only from the ALB security group
- **Security Group (RDS)** — allows MySQL (port 3306) only from EC2 security group
- **RDS MySQL Instance** — db.t3.micro, MySQL 8.0.19, database named `phonebook`
- **Application Load Balancer** — internet-facing, HTTP listener on port 80
- **ALB Target Group** — HTTP, port 80, with health checks on `/`
- **ALB Listener** — forwards traffic to the target group
- **Launch Template** — installs Flask, pulls app from GitHub, starts the server
- **Auto Scaling Group** — min 1, desired 2, max 3, ELB health checks, 300s grace period

---

## Prerequisites

- AWS CLI configured (`aws configure`)
- Terraform installed (v1.0+)
- GitHub repository with the application code pushed

---

## Setup & Deployment

### 1. Update the GitHub repo URL in main.tf

In `main.tf`, find the user data section and replace the placeholder:

```bash
git clone https://github.com/YOUR_GITHUB_USERNAME/YOUR_REPO_NAME.git app
```

### 2. Initialize Terraform

```bash
terraform init
```

### 3. Preview the infrastructure plan

```bash
terraform plan
```

### 4. Deploy to AWS

```bash
terraform apply
```

After apply completes, Terraform will output the application URL:

```
Outputs:
phonebook_app_url = "http://<alb-dns-name>"
rds_endpoint      = "<rds-endpoint>"
```

### 5. Destroy resources when done

```bash
terraform destroy
```

---

## Environment Variables

The Flask app reads the RDS endpoint from an environment variable set by the Launch Template user data script:

```bash
MYSQL_DATABASE_HOST=<rds-endpoint>
```

---

## Developer

Developed by **James Ackies** | Deployed with Flask on AWS Cloud using Terraform
