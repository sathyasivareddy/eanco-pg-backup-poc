# Minimum-Resource Design

## Principle
Use the fewest Azure resources that still meet production-grade security,
reliability, observability, and deployment standards. Reuse approved shared
services wherever possible (feature flags `create_*`).

## Deliberately NOT created
- Azure Function App, App Service Plan, AKS, VMs
- NAT Gateway, Azure Firewall, Application Gateway, Load Balancer
- Public IP for the backup job
- Container Apps Environment private endpoint
- Container App ingress
- Service Bus, Storage Queue, Event Grid, API Management
- Dedicated Container Apps workload profile (Consumption only)
- Separate ACR per environment
- Separate VNet when an approved VNet is reusable
- Unnecessary private endpoints (only if policy requires)

## Why the job needs no ingress
The backup job is outbound-only. It is triggered by the Azure control plane
(schedule or `az containerapp job start`). No inbound application traffic exists,
so there is no ingress and no private endpoint for the environment.

## Cost-minimizing choices
- PostgreSQL Burstable **B1ms**, 32 GiB, HA off, geo off (POC sizing).
- Container Apps Job scales to zero — no idle compute.
- Storage **LRS**, Hot tier, 7-day delete lifecycle (POC).
- ACR **Basic**. Log Analytics with modest retention.
- Reuse shared ACR / Key Vault / Log Analytics / Action Group when available.

## Reuse switches
`create_virtual_network`, `create_private_dns_zone`, `create_acr`,
`create_storage_account`, `create_key_vault`, `create_log_analytics_workspace`,
`create_action_group`. Each has a matching `existing_*_id` input, with validation
requiring exactly one of create/reuse for the VNet.
