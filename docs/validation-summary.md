# Validation Summary

## Execution context

This evidence summary records the results observed during the AZ-104 Storage capstone deployment in a time-limited Pluralsight Azure sandbox.

| Item | Result |
|---|---|
| Deployment status | Successful |
| Deployment duration | 391 seconds |
| Primary Storage region | West US |
| DR Storage region | West US due to sandbox region restriction |
| Private Endpoint | Created |
| Private validation VM | Created |

No subscription ID, account key, connection string, or SAS signature is stored in this document.

## Security validation

| Test | Result | Status |
|---|---|---|
| Secure transfer required | `True` | Pass |
| Minimum TLS version | `TLS1_2` | Pass |
| Public Blob access | `False` | Pass |
| Storage firewall default action | `Deny` | Pass |
| System-assigned identity | Enabled | Pass |

## Blob protection validation

| Feature | Result | Status |
|---|---|---|
| Versioning | Enabled | Pass |
| Change Feed | Enabled | Pass |
| Blob soft delete | Enabled, 14 days | Pass |
| Container soft delete | Enabled | Pass |
| Point-in-time restore | Enabled | Pass |

## Encryption and lifecycle validation

| Feature | Result | Status |
|---|---|---|
| Encryption scope | `finance-scope` enabled | Pass |
| Lifecycle rule | `logs-cost-optimization` enabled | Pass |
| Lifecycle target prefix | `logs/` | Pass |

## Private connectivity validation

| Test | Observed result | Interpretation |
|---|---|---|
| Private Endpoint state | `Approved` | Blob Private Link connection accepted |
| Target subresource | `blob` | Endpoint scoped correctly |
| Blob hostname resolution | `10.40.2.4` | Public Blob hostname resolved to a private address from the VM |
| Anonymous HTTPS request | HTTP `400` | Azure Storage was reached over the private route; the root request was not a valid authorized Blob operation |

The DNS result is the primary proof that the VM used the Private Endpoint path.

## Monitoring validation

| Test | Result | Status |
|---|---|---|
| Diagnostic setting | `diag-blob-to-law` | Pass |
| Destination | `law-stc-storage` | Pass |
| Blob logs | Storage read, write, and delete categories enabled | Pass |
| Metrics | Transaction metrics enabled | Pass |

## Object Replication validation

The source and destination storage accounts each returned one matching Object Replication policy:

```text
Source policy count      : 1
Destination policy count : 1
```

Status: **Pass**

The sandbox forced both accounts into West US. This validates Object Replication configuration and policy association, but not geographic separation.

## Evidence not captured before expiration

The 45-minute sandbox expired before the final two Portal screenshots could be captured:

- Azure Files share snapshot
- Stored Access Policy

The Stored Access Policy was configured as a required deployment step, so successful completion of `deploy.sh` confirms its creation. Azure Files snapshot creation was an optional step and is recorded as implemented but not independently revalidated before expiration.

## Overall result

The capstone successfully validated its primary security, networking, protection, replication, encryption, lifecycle, identity, and monitoring objectives. The missing screenshots are documented evidence limitations rather than hidden or fabricated results.
