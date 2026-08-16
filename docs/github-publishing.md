# GitHub Publishing Guide

## Recommended repository settings

Repository name:

```text
Azure-Secure-Storage-Capstone
```

Description:

```text
Automated secure Azure Storage platform built with Bash and Azure CLI for hands-on AZ-104 preparation.
```

Recommended topics:

```text
azure
az-104
azure-storage
azure-cli
bash
private-endpoint
cloud-security
object-replication
log-analytics
```

## Publish from a local terminal

After extracting the project and adding the available screenshots:

```bash
git init
git branch -M main
git add .
git commit -m "Build secure Azure Storage AZ-104 capstone"
git remote add origin https://github.com/sohrabjalali30/Azure-Secure-Storage-Capstone.git
git push -u origin main
```

Create the empty GitHub repository before running the final two commands. Do not initialize the remote repository with another README when using this method.

## Evidence review before publishing

```bash
git status
git diff --cached
```

Confirm that none of these files are staged:

```text
stc-project.env
deployment-output.txt
validation-output.txt
*.key
*.pem
```

Inspect screenshots for subscription IDs, account keys, SAS signatures, public IPs, usernames, and other personal information before committing them.
