# Sandbox Limitations and Production Extensions

The project was deployed in a restricted Pluralsight Azure sandbox with a 45-minute lifetime. The implementation deliberately records these restrictions rather than presenting the lab as an unrestricted production deployment.

## Observed limitations

| Limitation | Project effect | Production design |
|---|---|---|
| Restricted Azure regions | DR account fell back to West US | Place the DR account in an approved secondary region |
| No permission to create role assignments | Full Key Vault CMK integration could not be completed | Grant the deployment identity the minimum RBAC permissions and use Key Vault-backed CMK |
| Short sandbox lifetime | Final Azure Files and Stored Access Policy screenshots were not captured | Run validation in CI/CD and retain immutable evidence artifacts |
| Ephemeral resources | Environment disappeared after expiration | Deploy through a controlled subscription and manage state through IaC |
| Portal data-plane access after firewall lockdown | Browser access may fail outside the allowed network | Use a trusted management network, VPN, Bastion, or private runner |

## Design adaptations

- The script tries the requested DR region and safely falls back to the primary region when the sandbox rejects it.
- Private Endpoint creation is attempted automatically. Service Endpoint access remains a fallback design.
- Data-plane setup occurs before the Storage firewall changes to default `Deny`.
- Optional operations produce warnings without hiding failure; required foundation failures stop deployment.
- Sensitive values are not printed to terminal output.

## Production roadmap

1. Rebuild the deployment with Bicep or Terraform.
2. Separate primary and DR Storage accounts geographically.
3. Use a user-assigned Managed Identity for Key Vault access.
4. Enable Customer-Managed Keys with rotation and recovery protection.
5. Add Azure Monitor alerts, action groups, and longer Log Analytics retention.
6. Run automated policy, security, and private-connectivity tests through CI/CD.
7. Store validation artifacts without including keys, SAS tokens, or environment secrets.
