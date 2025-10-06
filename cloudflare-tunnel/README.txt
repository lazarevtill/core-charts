# Cloudflare Tunnel Setup

## What is Cloudflare Tunnel?

Cloudflare Tunnel creates a secure, outbound-only connection from your Kubernetes cluster to Cloudflare's edge network.

**Benefits:**
- ✅ Server IP completely hidden (zero-trust security)
- ✅ No inbound ports needed (can firewall 443/80)
- ✅ DDoS protection via Cloudflare
- ✅ Traffic encrypted through tunnel
- ✅ No DNS configuration needed (managed via tunnel)
- ✅ Works with Cloudflare proxy enabled (orange cloud)

## How It Works

```
User Request
    ↓
Cloudflare Edge (with orange cloud proxy)
    ↓
Cloudflare Tunnel (encrypted)
    ↓
cloudflared pod in Kubernetes
    ↓
nginx-ingress controller
    ↓
Your application
```

## Setup Instructions

### 1. Run Setup Script

```bash
cd /root/core-charts
bash setup-cloudflare-tunnel.sh
```

This script will:
1. Install cloudflared CLI
2. Authenticate with Cloudflare (opens browser)
3. Create tunnel (default name: k8s-tunnel)
4. Deploy cloudflared to Kubernetes (2 replicas for HA)
5. Provide commands to route domains

### 2. Route Domains Through Tunnel

After setup completes, run the generated script:

```bash
bash /tmp/route-all-domains.sh k8s-tunnel
```

This routes all domains through the tunnel:
- argo.theedgestory.org
- kafka.theedgestory.org
- grafana.theedgestory.org
- prometheus.theedgestory.org
- status.theedgestory.org
- s3-admin.theedgestory.org
- core-pipeline.dev.theedgestory.org
- core-pipeline.theedgestory.org
- auth.theedgestory.org

### 3. Verify

```bash
# Check cloudflared pods
kubectl get pods -n cloudflare-tunnel

# Check logs
kubectl logs -n cloudflare-tunnel -l app=cloudflared -f

# Test a service
curl -I https://argo.theedgestory.org
```

## Configuration

The tunnel configuration is in `deployment.yaml`:

- **ConfigMap:** Routes hostnames to nginx-ingress controller
- **Deployment:** Runs cloudflared with 2 replicas
- **Secret:** Stores tunnel credentials (created by setup script)

### Adding New Domains

Edit `deployment.yaml` ConfigMap and add:

```yaml
- hostname: new-service.theedgestory.org
  service: http://ingress-nginx-controller.kube-system.svc.cluster.local:80
  originRequest:
    noTLSVerify: false
```

Then route the domain:
```bash
cloudflared tunnel route dns k8s-tunnel new-service.theedgestory.org
```

## TLS Certificates

With Cloudflare Tunnel, you have two options:

### Option 1: Cloudflare Origin Certificates (Recommended)
- Generated in Cloudflare dashboard
- Valid for 15 years
- Stored as Kubernetes secrets
- No cert-manager needed

### Option 2: Let's Encrypt + DNS-01 Challenge
- Automated via cert-manager
- Requires Cloudflare API token
- 90-day certificates (auto-renewed)
- Use `letsencrypt-cloudflare` ClusterIssuer

## Monitoring

Metrics exposed on port 2000:
```bash
kubectl port-forward -n cloudflare-tunnel svc/cloudflared-metrics 2000:2000
curl http://localhost:2000/metrics
```

## Troubleshooting

### Tunnel Not Connecting

```bash
# Check pod status
kubectl describe pod -n cloudflare-tunnel -l app=cloudflared

# Check logs
kubectl logs -n cloudflare-tunnel -l app=cloudflared --tail=100

# Verify tunnel exists
cloudflared tunnel list

# Check tunnel info
cloudflared tunnel info k8s-tunnel
```

### Domain Not Routing

```bash
# Check DNS routing
cloudflared tunnel route dns list

# Re-route domain
cloudflared tunnel route dns k8s-tunnel argo.theedgestory.org

# Check Cloudflare DNS in dashboard
# Should show CNAME record pointing to <tunnel-id>.cfargotunnel.com
```

### 404 Errors

```bash
# Check nginx-ingress controller
kubectl get svc -n kube-system ingress-nginx-controller

# Check ingress resources
kubectl get ingress -A

# Test internal service
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl -H "Host: argo.theedgestory.org" \
  http://ingress-nginx-controller.kube-system.svc.cluster.local:80
```

## Security

- Tunnel credentials stored in Kubernetes secret (encrypted at rest)
- Outbound-only connection (no inbound ports)
- Traffic encrypted with TLS through tunnel
- Server IP never exposed publicly

## High Availability

- 2 replica deployment for redundancy
- Automatic failover if one pod fails
- LoadBalancer health checks via /ready endpoint

## Cleanup

To remove Cloudflare Tunnel:

```bash
# Delete Kubernetes resources
kubectl delete namespace cloudflare-tunnel

# Delete tunnel from Cloudflare
cloudflared tunnel delete k8s-tunnel

# Remove DNS routes
cloudflared tunnel route dns delete argo.theedgestory.org
```

## Additional Resources

- Cloudflare Tunnel Docs: https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/
- cloudflared GitHub: https://github.com/cloudflare/cloudflared
