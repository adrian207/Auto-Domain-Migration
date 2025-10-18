# Deployment Tiers Comparison Guide

**Author:** Adrian Johnson <adrian207@gmail.com>  
**Date:** October 2025

## Quick Decision Matrix

**Choose your tier based on:**

| Criterion | Tier 1 (Demo) | Tier 2 (Medium) | Tier 3 (Enterprise) |
|-----------|---------------|-----------------|---------------------|
| **User Count** | <500 | 500-3,000 | >3,000 |
| **Workstation Count** | <100 | 100-800 | >800 |
| **Server Count** | <25 | 25-150 | >150 |
| **Team Size** | 2-3 FTE | 4-5 FTE | 6-8 FTE |
| **Budget** | $150k-220k | $350k-440k | $900k-1.3M |
| **Timeline** | 6-8 weeks | 10-14 weeks | 16-24 weeks |
| **Kubernetes Required** | No | No | Yes |
| **HA Requirements** | None | Moderate | Full HA |
| **Monitoring Maturity** | Basic | Production | Enterprise |

---

## Detailed Feature Comparison

### Infrastructure Components

| Component | Tier 1 | Tier 2 | Tier 3 |
|-----------|--------|--------|--------|
| **Orchestration** | Ansible Core CLI or single AWX VM | AWX HA pair (active/standby) | AWX on K8s (3 control + 3+ exec pods, HPA) |
| **Secrets Management** | Ansible Vault (file-based) | HashiCorp Vault (single node, snapshot backups) | HashiCorp Vault HA (3-node Raft, auto-unseal) |
| **Database** | SQLite or CSV files | PostgreSQL (primary + 1 replica) | PostgreSQL HA (Patroni, 3 nodes, pgBouncer) |
| **Object Storage** | Local filesystem or SMB share | MinIO single-node or cloud (S3/Blob) | MinIO HA (4+ nodes, erasure coding 4+2) |
| **State Stores (USMT)** | 1 SMB share (2 TB) | 2-3 regional DFS-R shares (10 TB each) | Multi-region object storage (100+ TB) |
| **Monitoring** | Prometheus + Grafana (Docker Compose) | Prometheus (2-node) + Grafana HA + Alertmanager | Prometheus Operator + Grafana HA + Loki + Alertmanager cluster |
| **Web Reporting** | Nginx (static HTML only) | Nginx (static HTML + Grafana proxy) | Nginx HA (Ingress Controller, TLS, SSO) |
| **Total VMs/Nodes** | 1 VM | 5-7 VMs | 15+ nodes (K8s + supporting services) |
| **Total vCPU** | 4 | 40-60 | 70-100 |
| **Total RAM** | 16 GB | 120-180 GB | 240-320 GB |
| **Storage** | 2-3 TB | 30-50 TB | 100-200 TB |

---

### Automation & Features

| Feature | Tier 1 | Tier 2 | Tier 3 |
|---------|--------|--------|--------|
| **Identity Export/Provision** | ✓ | ✓ | ✓ |
| **USMT Capture/Restore** | ✓ | ✓ | ✓ |
| **Domain Move (Windows)** | ✓ | ✓ | ✓ |
| **Server Rebind (Services/SPNs/ACLs)** | ✓ | ✓ | ✓ |
| **Linux Local User Migration** | ✓ | ✓ | ✓ |
| **Linux Domain-Joined (sssd)** | ✓ | ✓ | ✓ |
| **ADMT Integration** | Manual | ✓ (automated) | ✓ (automated) |
| **Entra Connect Sync Orchestration** | Manual | ✓ (wait loops) | ✓ (full automation) |
| **Pre-Flight Validation** | Basic (health checks) | ✓ (app dependencies, capacity) | ✓ (comprehensive + chaos tests) |
| **Rollback Automation** | Manual procedures | ✓ (playbook-driven) | ✓ (playbook + self-service portal) |
| **Wave Management** | Manual (CLI) | ✓ (AWX surveys) | ✓ (AWX workflows + approval gates) |
| **Safety Gates (auto-pause)** | Manual monitoring | ✓ (threshold-based) | ✓ (ML-based anomaly detection) |
| **Self-Healing** | ❌ | Limited (manual triggers) | ✓ (Alertmanager webhooks → AWX) |
| **Dynamic Credentials (Vault)** | ❌ (static in Ansible Vault) | ✓ (AD, DB, SSH CA) | ✓ (AD, DB, SSH CA, PKI, cloud IAM) |
| **Audit Logging** | File-based (Ansible logs) | PostgreSQL + SIEM integration | PostgreSQL + Loki + SIEM + compliance exports |

---

### Throughput & Performance

| Metric | Tier 1 | Tier 2 | Tier 3 |
|--------|--------|--------|--------|
| **Max Concurrent (Workstations)** | 25 | 100 (per runner, 2-3 runners = 200-300) | 200 (per runner, 5+ runners = 1,000+) |
| **Max Concurrent (Servers)** | 10 | 25 (per runner, 2-3 runners = 50-75) | 40 (per runner, 5+ runners = 200+) |
| **Users / 4-hour Window** | 500 | 3,000 | 10,000+ |
| **Workstations / 4-hour Window** | 100 | 800 | 2,400 |
| **Servers / 4-hour Window** | 30 | 150 | 360 |
| **State Store Bandwidth** | 1 Gbps (shared) | 10 Gbps per region (2-3 regions) | 10-40 Gbps per region (multi-region) |
| **USMT Compression** | ❌ (uncompressed) | ✓ (optional) | ✓ (always) |

---

### Observability & Alerting

| Feature | Tier 1 | Tier 2 | Tier 3 |
|---------|--------|--------|--------|
| **Prometheus Metrics** | Basic (runner, WinRM probes) | Full (runner, WinRM, Postgres, Vault, state stores) | Enterprise (all + K8s, object storage, custom apps) |
| **Grafana Dashboards** | 2-3 basic dashboards | 5-10 dashboards (per-wave drill-down) | 15+ dashboards (SLO, cost, compliance) |
| **Alerting** | Email only | Email + Slack + webhook | PagerDuty + Slack + Webhook + auto-remediation |
| **Log Aggregation** | Local files | PostgreSQL + partial log shipping | Loki + full centralized logging |
| **Distributed Tracing** | ❌ | ❌ | ✓ (Tempo, optional) |
| **SLO Tracking** | ❌ | Manual | ✓ (automated SLO dashboards) |
| **On-Call Procedures** | ❌ | Manual runbooks | ✓ (integrated with PagerDuty, auto-escalation) |

---

### Security & Compliance

| Feature | Tier 1 | Tier 2 | Tier 3 |
|---------|--------|--------|--------|
| **Transport Security** | WinRM/Kerberos + SSH keys | WinRM/Kerberos + SSH CA (Vault) | WinRM/Kerberos + SSH CA + mTLS for control plane |
| **Secret Rotation** | Manual (quarterly) | Semi-automated (Vault TTLs) | Fully automated (Vault dynamic + auto-rotation) |
| **Audit Trails** | Ansible logs + Git commits | Postgres + Git + Vault audit | Postgres + Loki + Vault audit + SIEM integration |
| **Break-Glass Access** | Static password (sealed envelope) | Static password + Vault emergency | Static password + Vault emergency + HSM |
| **Compliance Reports** | Manual CSV exports | HTML reports + PostgreSQL queries | Automated compliance exports (SOC2, ISO27001) |
| **Network Segmentation** | Best effort | Firewalls + VPN | Zero-trust architecture (mTLS, network policies) |

---

### Cost Breakdown

#### Tier 1: $150k-220k
- **Infrastructure:** $200-400/month × 2 months = **$800 total**
- **Storage:** $100/month × 2 months = **$200 total**
- **Licenses:** $0 (all open-source)
- **Labor:** 2-3 FTE × 8 weeks × 160 hours × $150/hour = **$144k-216k**
- **Contingency (10%):** $15k-22k
- **TOTAL:** ~$150k-220k

#### Tier 2: $350k-440k
- **Infrastructure:** $1,500-2,500/month × 4 months = **$6k-10k**
- **Storage:** $500-800/month × 4 months = **$2k-3k**
- **Licenses:** $0 (open-source) OR Vault Enterprise $5k-10k
- **Labor:** 4-5 FTE × 14 weeks × 160 hours × $150/hour = **$336k-420k**
- **Contingency (10%):** $35k-44k
- **TOTAL:** ~$350k-440k

#### Tier 3: $900k-1.3M
- **Infrastructure:** $5k-10k/month × 6 months = **$30k-60k**
- **Storage:** $2k-4k/month × 6 months = **$12k-24k**
- **Licenses:** Vault Enterprise HA $20k-50k, K8s support (optional) $10k-20k
- **Labor:** 6-8 FTE × 24 weeks × 160 hours × $150/hour = **$864k-1.15M**
- **Training:** $50k-75k (K8s, Vault, advanced Ansible)
- **Contingency (10%):** $90k-130k
- **TOTAL:** ~$900k-1.3M

**Note:** Excludes USMT licenses (~$50-100 per device), ADMT licensing, consultant fees, ongoing operations.

---

### Risk & Complexity

| Risk Factor | Tier 1 | Tier 2 | Tier 3 |
|-------------|--------|--------|--------|
| **Deployment Complexity** | Low (1 VM, Docker Compose) | Medium (5-7 VMs, HA config) | High (K8s cluster, 15+ components) |
| **Operational Complexity** | Low (manual execution) | Medium (AWX workflows, Vault rotation) | High (K8s ops, auto-scaling, self-healing) |
| **Skillset Requirements** | Ansible + AD basics | Ansible + Vault + Postgres + AD | Ansible + K8s + Vault + Postgres + networking |
| **Single Point of Failure** | Runner VM (no HA) | Vault (single node) | None (full HA) |
| **Recovery Time (RTO)** | 2-4 hours (rebuild VM) | 1 hour (failover to standby) | <5 minutes (K8s reschedule) |
| **Data Loss Risk (RPO)** | Last backup (daily) | Last backup (hourly) | Near-zero (continuous replication) |

---

## Migration Path Between Tiers

### Tier 1 → Tier 2 Upgrade

**When to upgrade:**
- Migration scope exceeds 500 users
- Need for rollback automation
- Business requirement for HA or SLA guarantees

**Upgrade steps:**
1. Export Ansible Vault secrets to HashiCorp Vault
2. Migrate SQLite/CSV data to PostgreSQL
3. Deploy AWX and import inventories/playbooks
4. Deploy DFS-R state stores (2-3 regions)
5. Upgrade monitoring (Prometheus HA, Alertmanager)
6. Test all playbooks in new environment
7. Cutover during low-activity window

**Estimated effort:** 3-4 weeks with 2 engineers

---

### Tier 2 → Tier 3 Upgrade

**When to upgrade:**
- Migration scope exceeds 3,000 users
- Multi-tenant or global requirements
- Need for auto-scaling and self-healing
- Regulatory compliance requires full audit trails

**Upgrade steps:**
1. Deploy K8s cluster (K3s or upstream)
2. Migrate AWX to AWX Operator on K8s
3. Deploy Vault HA with Raft (migrate secrets)
4. Deploy Patroni for PostgreSQL HA
5. Deploy MinIO HA with erasure coding
6. Migrate state stores to object storage
7. Deploy Prometheus Operator and Loki
8. Rebuild monitoring dashboards (Grafana HA)
9. Implement self-healing webhooks (Alertmanager → AWX)
10. Comprehensive testing and chaos engineering

**Estimated effort:** 8-12 weeks with 4 engineers

---

## Choosing Your Starting Tier

### Start with Tier 1 if:
- ✓ This is a pilot/POC to prove the concept
- ✓ Migration is <500 users OR one-time project
- ✓ Budget is limited (<$250k)
- ✓ Team is 2-3 people with basic Ansible skills
- ✓ Timeline is short (6-8 weeks)
- ✓ Acceptable to have manual rollback procedures
- ✓ OK with 2-4 hour RTO if control plane fails

### Start with Tier 2 if:
- ✓ Migration is 500-3,000 users
- ✓ This is a production migration with business impact
- ✓ Budget allows for moderate infrastructure ($350k-450k)
- ✓ Team is 4-5 people with Ansible + AD + database skills
- ✓ Timeline is 10-14 weeks
- ✓ Need automated rollback capability
- ✓ Need monitoring and alerting for operations
- ✓ Acceptable to have manual intervention for failures

### Start with Tier 3 if:
- ✓ Migration is >3,000 users OR multi-tenant
- ✓ This is mission-critical with SLA requirements
- ✓ Budget allows for enterprise infrastructure ($900k-1.5M)
- ✓ Team is 6-8 people with K8s + Vault + Ansible expertise
- ✓ Timeline is 16-24 weeks
- ✓ Need full HA with <5 min RTO
- ✓ Need self-healing and auto-scaling
- ✓ Regulatory compliance requires comprehensive audit trails
- ✓ Will use platform for ongoing migrations (M&A, spin-offs)

---

## Incremental Adoption Strategy (Recommended)

For organizations new to infrastructure automation or with uncertain migration scope, we recommend a **staged approach**:

### Phase 1: Tier 1 Pilot (Weeks 1-8)
- Deploy minimal infrastructure
- Migrate 50-100 users, 10-20 workstations, 2-5 servers
- Validate all playbooks and mappings
- Collect metrics on timing and failure rates
- **Decision point:** Proceed to production or upgrade to Tier 2?

### Phase 2A: Tier 1 Production (Weeks 9-12)
- If scope is <500 users, continue with Tier 1
- Execute 2-4 production waves
- Complete migration and hand off to operations

### Phase 2B: Upgrade to Tier 2 (Weeks 9-12)
- If scope is 500-3,000 users, upgrade infrastructure
- Re-run pilot with HA stack
- Validate rollback and monitoring

### Phase 3: Tier 2 Production (Weeks 13-22)
- Execute 6-12 production waves
- Tune concurrency and monitoring
- Collect operational metrics

### Phase 4: Tier 3 Expansion (Optional, Weeks 23+)
- If ongoing migrations or multi-tenant needs emerge, upgrade to Tier 3
- Deploy K8s and full HA stack
- Implement self-healing and auto-scaling
- Use for future migrations (M&A, divestitures)

**Total timeline with staged approach:** 22-30 weeks (vs. 16-24 weeks direct to Tier 3, but with lower risk)

---

## Hybrid Tier Configurations

Some organizations may benefit from **hybrid configurations** that mix elements from different tiers:

### Configuration A: "Tier 1.5" (Low-Cost Production)
- AWX single VM (not HA) + PostgreSQL single node
- Ansible Vault (no HashiCorp Vault)
- Prometheus + Grafana (Docker Compose, no HA)
- Manual rollback procedures but automated validation
- **Use case:** 500-1,000 users, moderate budget, accepting some risk

### Configuration B: "Tier 2.5" (Cost-Optimized Enterprise)
- AWX on K8s (no autoscaling)
- Vault HA (3 nodes) but PostgreSQL single + replica (no Patroni)
- MinIO single-node or cloud object storage (no self-hosted HA)
- Full monitoring but manual self-healing
- **Use case:** 3,000-5,000 users, budget-conscious, can tolerate 30-min RTO

### Configuration C: "Tier 3 Lite" (Simplified Enterprise)
- All Tier 3 components but smaller scale (K8s 5 nodes instead of 15)
- Self-healing for 3 most common failures only
- Loki optional (use cloud logging)
- **Use case:** 5,000-8,000 users, want HA but not full complexity

**Recommendation:** Start with standard tiers; customize only after pilot reveals specific needs.

---

## Summary Decision Tree

```
START
│
├─ Migration scope <500 users?
│  └─ YES → Tier 1
│  └─ NO → Continue
│
├─ Team has K8s + Vault expertise?
│  └─ NO → Tier 2
│  └─ YES → Continue
│
├─ Budget >$800k?
│  └─ NO → Tier 2
│  └─ YES → Continue
│
├─ Need <5 min RTO?
│  └─ NO → Tier 2
│  └─ YES → Tier 3
│
└─ Still uncertain?
   └─ Start with Tier 1 pilot, upgrade after validation
```

---

**END OF DOCUMENT**

*For implementation guides for each tier, see `docs/02_IMPLEMENTATION_GUIDE_TIER1.md`, `docs/03_IMPLEMENTATION_GUIDE_TIER2.md`, and `docs/04_IMPLEMENTATION_GUIDE_TIER3.md`.*

