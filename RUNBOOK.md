# 45-Minute Execution Runbook

## Before starting the timer

Download `Azure-Secure-Storage-Capstone.zip`. Start a fresh Pluralsight sandbox only when the ZIP file is ready on your computer.

## Minute 0–3: Upload and start

1. Open Azure Cloud Shell and select **Bash**.
2. Use **Manage files → Upload** and upload the ZIP file.
3. Run:

```bash
unzip -o Azure-Secure-Storage-Capstone.zip
cd Azure-Secure-Storage-Capstone
chmod +x deploy.sh validate.sh
bash deploy.sh | tee deployment-output.txt
```

The script automatically detects the sandbox resource group when exactly one accessible resource group exists. If it reports multiple resource groups, run:

```bash
export AZURE_RG='paste-the-sandbox-resource-group-name'
bash deploy.sh | tee deployment-output.txt
```

## Minute 3–30: Let deployment finish

- Do not create resources manually while the script is running.
- `[WARN]` means an optional capability was skipped and the script is continuing.
- `[FAIL]` means a required foundation component failed. Copy only the final error message; never share access keys, connection strings, or SAS values.
- A rejected second region automatically falls back to the primary region.
- A rejected Private Endpoint automatically falls back to the Service Endpoint design.

## Minute 30–36: Validate

Run:

```bash
bash validate.sh | tee validation-output.txt
```

Expected private-network test:

- The Blob hostname resolves to a private address when Private Endpoint and Private DNS succeeded.
- An anonymous request to the service root can return `400` or `403`, depending on how Azure Storage evaluates the request. DNS resolution to the private address is the primary proof that the Private Endpoint path is active.

## Minute 36–45: Capture evidence

Follow `screenshot-checklist.md`. Capture only eight screenshots and redact subscription IDs, account keys, connection strings, SAS tokens, signatures, and public IP addresses.

Download these evidence files before the sandbox expires:

```text
deployment-output.txt
validation-output.txt
stc-project.env
```

The environment file contains resource names only and does not contain secrets.

If the sandbox expires before the files are downloaded, record only the results that were actually observed. Do not recreate screenshots or claim unverified evidence.

## Important behavior

After deployment, the primary Storage firewall defaults to `Deny` and allows the client subnet. Azure Portal data browsing from your own computer might therefore show an authorization or network error. This is expected evidence of network isolation; use the VM run-command result for private connectivity validation.
