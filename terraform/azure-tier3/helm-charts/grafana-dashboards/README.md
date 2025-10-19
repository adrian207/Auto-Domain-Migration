# Grafana Dashboards for ADMT Migration

Custom Grafana dashboards for monitoring Active Directory migrations.

## 📊 Dashboards Included

| Dashboard | Description | Datasource | Refresh |
|-----------|-------------|------------|---------|
| **ADMT Overview** | High-level migration metrics | Prometheus + PostgreSQL | 30s |
| **File Migration** | SMS/file server migration tracking | Prometheus + MinIO | 10s |
| **Infrastructure Health** | Cluster and VM health | Prometheus | 30s |
| **Azure Cost Tracking** | Real-time Azure cost monitoring | Azure Monitor | 5m |

---

## 🚀 Quick Import

### Option 1: Automatic (via Helm values)

Already configured in `prometheus/values.yaml`:

```yaml
grafana:
  dashboards:
    migration:
      admt-overview:
        url: https://raw.githubusercontent.com/yourusername/dashboards/main/admt-overview.json
      file-migration:
        url: https://raw.githubusercontent.com/yourusername/dashboards/main/file-migration.json
```

### Option 2: Manual Import

1. Access Grafana UI
2. Navigate to Dashboards → Import
3. Upload JSON files from this directory
4. Select datasources (Prometheus, PostgreSQL)
5. Click Import

### Option 3: ConfigMap

```bash
kubectl create configmap grafana-dashboards \
  --from-file=admt-overview.json \
  --from-file=file-migration.json \
  --from-file=infrastructure-health.json \
  --from-file=azure-cost-tracking.json \
  -n monitoring

# Label for automatic discovery
kubectl label configmap grafana-dashboards \
  grafana_dashboard=1 \
  -n monitoring
```

---

## 📈 Dashboard Details

### 1. ADMT Overview Dashboard

**Metrics tracked:**
- Total users migrated (counter)
- Migration success rate (%)
- Active migration jobs
- Average migration time per user
- Failed migrations (last 24h)
- Domain controller health
- ADMT service status

**Panels:**
- Migration progress gauge
- Success/failure rate over time
- Top 10 migration errors
- Users migrated per wave (bar chart)
- Migration timeline (Gantt-style)

**Data sources:**
- Prometheus (for metrics)
- PostgreSQL (for AWX job data)

---

### 2. File Migration Dashboard

**Metrics tracked:**
- Total data transferred (GB)
- Transfer speed (MB/s)
- Files migrated count
- SMS job status
- Storage utilization
- Transfer errors
- Replication lag

**Panels:**
- Data transfer rate (line graph)
- Storage capacity (gauge)
- File count by share (pie chart)
- Transfer timeline
- Error log table

**Data sources:**
- Prometheus (MinIO metrics)
- Loki (SMS logs)

---

### 3. Infrastructure Health Dashboard

**Metrics tracked:**
- Node CPU/Memory/Disk usage
- Pod health status
- PostgreSQL connection pool
- Vault seal status
- Network throughput
- Persistent volume usage

**Panels:**
- Cluster resource heatmap
- Service availability (uptime)
- Database performance
- Storage I/O graphs
- Network bandwidth

**Data sources:**
- Prometheus
- Node Exporter
- Kube-state-metrics

---

### 4. Azure Cost Tracking Dashboard

**Metrics tracked:**
- Daily Azure spend
- Cost by resource group
- VM costs
- Storage costs
- Network egress costs
- Month-to-date vs budget
- Cost forecasting

**Panels:**
- Current month spend (gauge)
- Daily cost trend
- Top 10 expensive resources
- Cost breakdown (pie chart)
- Budget vs actual (comparison)

**Data sources:**
- Azure Monitor (via Prometheus)
- Azure Cost Management API

---

## 🔔 Alerts Configured

Each dashboard includes alert panels:

### ADMT Overview Alerts
- ⚠️ Migration failure rate > 5%
- 🔴 Migration failure rate > 10%
- ⚠️ No migrations in last 2 hours (during business hours)
- 🔴 Domain controller unreachable

### File Migration Alerts
- ⚠️ Transfer speed < 10 MB/s
- 🔴 Transfer speed < 1 MB/s
- ⚠️ Storage > 80% full
- 🔴 Storage > 90% full
- 🔴 SMS service unavailable

### Infrastructure Alerts
- ⚠️ Node CPU > 80%
- 🔴 Node CPU > 90%
- ⚠️ Pod restart count > 5 (1h)
- 🔴 Database connection pool > 90%

### Cost Alerts
- ⚠️ Daily spend > expected by 20%
- 🔴 Monthly spend > budget
- ⚠️ Unexpected resource creation

---

## 🎨 Customization

### Variables

All dashboards support these variables:

```
$namespace     - Kubernetes namespace filter
$environment   - Production/Staging/Dev
$timeRange     - Time range selector
$refreshRate   - Auto-refresh interval
$domain        - Source/Target domain selector
```

### Templating Example

```json
{
  "templating": {
    "list": [
      {
        "name": "namespace",
        "type": "query",
        "query": "label_values(kube_pod_info, namespace)",
        "refresh": 1
      },
      {
        "name": "domain",
        "type": "custom",
        "options": [
          {"text": "source.local", "value": "source"},
          {"text": "target.local", "value": "target"}
        ]
      }
    ]
  }
}
```

---

## 📊 Metrics Reference

### AWX Job Metrics (from PostgreSQL)

Query AWX database:
```sql
SELECT 
  job_template_name,
  status,
  COUNT(*) as count,
  AVG(EXTRACT(EPOCH FROM (finished - started))) as avg_duration
FROM main_job
WHERE created > NOW() - INTERVAL '24 hours'
GROUP BY job_template_name, status;
```

### MinIO Metrics (from Prometheus)

```promql
# Total data transferred
sum(rate(minio_s3_requests_incoming_bytes[5m]))

# File count
minio_bucket_objects_count

# Storage usage
sum(minio_bucket_usage_object_total) by (bucket)

# Transfer errors
rate(minio_s3_requests_errors_total[5m])
```

### PostgreSQL Metrics

```promql
# Active connections
pg_stat_database_numbackends{datname="awx"}

# Query duration
rate(pg_stat_statements_mean_time_seconds[5m])

# Replication lag
pg_replication_lag_seconds
```

### Azure Cost Metrics

```promql
# Daily cost (from Azure Monitor)
azure_cost_daily_total{resource_group="admt-tier3-rg"}

# VM costs
sum(azure_vm_cost) by (vm_name)

# Storage costs
sum(azure_storage_cost) by (storage_account)
```

---

## 🔍 Query Examples

### Find failed migrations in last hour

```promql
increase(awx_job_failed_total{job_template=~".*migration.*"}[1h])
```

### Calculate migration success rate

```promql
(
  sum(rate(awx_job_successful_total[5m]))
  /
  sum(rate(awx_job_total[5m]))
) * 100
```

### Track file transfer speed

```promql
rate(minio_s3_requests_incoming_bytes[1m]) / 1024 / 1024
```

### Monitor database performance

```promql
rate(pg_stat_statements_calls[5m])
```

---

## 🎯 Best Practices

### Dashboard Design

1. **Keep it simple** - Max 8-10 panels per dashboard
2. **Use consistent colors** - Green (good), Yellow (warning), Red (critical)
3. **Group related metrics** - Use rows to organize panels
4. **Add descriptions** - Help text for each panel
5. **Set appropriate refresh** - Balance between real-time and load

### Performance

1. **Use recording rules** - Pre-calculate expensive queries
2. **Limit time ranges** - Default to last 1-24 hours
3. **Use variables** - Filter data efficiently
4. **Cache results** - Enable query result caching
5. **Optimize queries** - Use rate() instead of increase() when possible

### Maintenance

1. **Version control** - Store dashboards in Git
2. **Export regularly** - Backup dashboard JSON
3. **Document changes** - Add version notes
4. **Test queries** - Verify in Prometheus before adding
5. **Monitor dashboard load** - Check Grafana performance

---

## 📚 Additional Resources

- [Grafana Documentation](https://grafana.com/docs/)
- [PromQL Cheatsheet](https://promlabs.com/promql-cheat-sheet/)
- [Dashboard Best Practices](https://grafana.com/docs/grafana/latest/best-practices/)
- [Azure Monitor Integration](https://grafana.com/docs/grafana/latest/datasources/azuremonitor/)

---

**Ready to visualize your migrations!** 📊

