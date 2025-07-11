# Testing Strategy for Cloud Computing Project - Phases 4 & 5

Looking at your project requirements, I'll provide comprehensive testing strategies for both Phase 4 and Phase 5.

## **Phase 4 Testing Strategy**

### **📋 Phase 4 Requirements to Test:**

1. **Auto-scaling** - Services scale up/down based on load
2. **Internal Nginx** - Custom routing and load distribution
3. **External HAProxy** - Load balancing between master nodes
4. **High availability** - System resilience

### **🔧 Phase 4 Testing Options:**

#### **1. Stress Testing for Auto-scaling (HPA)**

**Option A: Apache Bench (ab)**

```powershell
# Install Apache Bench (comes with Apache)
# For Windows: Download Apache HTTP Server

# Test auth service scaling
ab -n 10000 -c 100 http://localhost/auth/users

# Test core service scaling
ab -n 5000 -c 50 http://localhost/core/status

# Test manage service scaling  
ab -n 8000 -c 80 http://localhost/manage/health
```

**Option B: Kubernetes Load Generator**

```powershell
# Create load generator pod
kubectl run load-generator --image=busybox --restart=Never -it --rm -- /bin/sh

# Inside the pod, generate continuous load
while true; do 
  wget -q -O- http://nginx-lb-service.nginx-lb/auth/users
  wget -q -O- http://nginx-lb-service.nginx-lb/core/status
  sleep 0.1
done
```

**Option C: Custom PowerShell Stress Test**

```powershell
# Create stress-test-phase4.ps1
$endpoints = @(
    "http://localhost/auth/users",
    "http://localhost/core/status", 
    "http://localhost/manage/health"
)

$jobs = @()
foreach ($endpoint in $endpoints) {
    $job = Start-Job -ScriptBlock {
        param($url)
        for ($i = 1; $i -le 1000; $i++) {
            try {
                Invoke-RestMethod -Uri $url -Method GET -TimeoutSec 5
                Write-Host "Request $i to $url completed"
            } catch {
                Write-Host "Request $i to $url failed: $($_.Exception.Message)"
            }
            Start-Sleep -Milliseconds 100
        }
    } -ArgumentList $endpoint
    $jobs += $job
}

# Monitor HPA during load
while ($jobs | Where-Object { $_.State -eq "Running" }) {
    kubectl get hpa --all-namespaces
    kubectl get pods --all-namespaces | findstr "auth\|core\|manage"
    Start-Sleep -Seconds 10
}
```

#### **2. Manual Testing for Phase 4**

**Nginx Routing Test:**

```powershell
# Test each service endpoint
curl http://localhost/auth/users
curl http://localhost/core/status
curl http://localhost/manage/health

# Test health endpoint
curl http://localhost/health

# Test with different HTTP methods
Invoke-RestMethod -Uri "http://localhost/auth/users" -Method GET
Invoke-RestMethod -Uri "http://localhost/core/data" -Method POST -Body '{"test":"data"}' -ContentType "application/json"
```

**HAProxy Testing:**

```powershell
# Check HAProxy stats
curl http://localhost:8080/stats

# Test master node failover (simulate failure)
docker pause kind-control-plane  # Pause one master
# Verify traffic still works
curl http://localhost/auth/users
docker unpause kind-control-plane  # Resume master
```

**Monitoring Commands:**

```powershell
# Real-time monitoring
kubectl get hpa --all-namespaces -w
kubectl get pods --all-namespaces -w
kubectl top pods --all-namespaces
kubectl top nodes

# HAProxy logs
docker logs haproxy-external

# Nginx logs
kubectl logs -n nginx-lb deployment/nginx-lb
```

---

## **Phase 5 Testing Strategy**

### **📋 Phase 5 Requirements to Test:**

1. **Migration success** - All services work on ArvanCloud
2. **Database backup/restore** - Step 2 demonstration
3. **Performance** - Services function correctly in cloud environment
4. **Networking** - Proper communication between services

### **🔧 Phase 5 Testing Options:**

#### **1. Stress Testing for ArvanCloud**

**Option A: Cloud-based Load Testing**

```powershell
# Get ArvanCloud LoadBalancer IP
$LB_IP = kubectl get svc -n ingress-nginx ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

# Stress test from multiple sources
# Test 1: High concurrent users
ab -n 20000 -c 200 http://$LB_IP/auth/users

# Test 2: Sustained load
ab -t 300 -c 50 http://$LB_IP/core/status  # 5 minutes

# Test 3: Mixed workload
$endpoints = @("/auth/users", "/core/status", "/manage/health")
foreach ($endpoint in $endpoints) {
    Start-Job -ScriptBlock {
        param($ip, $path)
        ab -n 5000 -c 100 http://$ip$path
    } -ArgumentList $LB_IP, $endpoint
}
```

**Option B: Kubernetes Job for Load Testing**

```yaml
# Create load-test-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: load-test
spec:
  parallelism: 10  # 10 parallel pods
  completions: 100 # 100 total runs
  template:
    spec:
      containers:
      - name: load-tester
        image: appropriate/curl
        command: ["/bin/sh"]
        args:
        - -c
        - |
          LB_IP=$(nslookup ingress-nginx.ingress-nginx.svc.cluster.local | grep Address | tail -1 | cut -d' ' -f2)
          for i in $(seq 1 100); do
            curl -s http://$LB_IP/auth/users > /dev/null
            curl -s http://$LB_IP/core/status > /dev/null
            curl -s http://$LB_IP/manage/health > /dev/null
            sleep 0.1
          done
      restartPolicy: Never
```

**Option C: External Load Testing Tools**

```powershell
# Using Artillery.js (install: npm install -g artillery)
# Create artillery-config.yaml
artillery quick --count 1000 --num 50 http://$LB_IP/auth/users

# Using JMeter (GUI tool)
# Create test plan with multiple thread groups targeting different endpoints

# Using k6 (lightweight)
k6 run --vus 100 --duration 5m script.js
```

#### **2. Database Backup/Restore Testing (Phase 5 Step 2)**

**Automated Test Script:**

```powershell
# Create comprehensive-db-test.ps1
Write-Host "=== Phase 5 Step 2: Database Backup/Restore Test ===" -ForegroundColor Green

# Step 1: Insert test data
Write-Host "Inserting test data..." -ForegroundColor Yellow
$AUTH_POD = kubectl get pods -n auth -l app=auth -o jsonpath='{.items[0].metadata.name}'
kubectl exec -n auth $AUTH_POD -- curl -X POST localhost:8082/auth/register -d '{"username":"testuser","password":"testpass"}'

# Step 2: Verify data exists
Write-Host "Verifying test data..." -ForegroundColor Yellow
kubectl exec -n auth $AUTH_POD -- curl localhost:8082/auth/users

# Step 3: Create backup
Write-Host "Creating database backup..." -ForegroundColor Yellow
$MYSQL_POD = kubectl get pods -n auth -l app=mysql -o jsonpath='{.items[0].metadata.name}'
kubectl exec -n auth $MYSQL_POD -- mysqldump -u root -pauth_pass authdb > backup-$(Get-Date -Format 'yyyyMMdd-HHmmss').sql

# Step 4: Delete database
Write-Host "Simulating database loss..." -ForegroundColor Red
kubectl exec -n auth $MYSQL_POD -- mysql -u root -pauth_pass -e "DROP DATABASE authdb;"

# Step 5: Verify data is gone
Write-Host "Verifying data loss..." -ForegroundColor Yellow
try {
    kubectl exec -n auth $AUTH_POD -- curl localhost:8082/auth/users
} catch {
    Write-Host "✓ Data successfully deleted" -ForegroundColor Green
}

# Step 6: Restore database
Write-Host "Restoring database..." -ForegroundColor Cyan
kubectl exec -n auth $MYSQL_POD -- mysql -u root -pauth_pass -e "CREATE DATABASE authdb;"
Get-Content backup-*.sql | kubectl exec -i -n auth $MYSQL_POD -- mysql -u root -pauth_pass authdb

# Step 7: Verify restoration
Write-Host "Verifying restoration..." -ForegroundColor Yellow
kubectl exec -n auth $AUTH_POD -- curl localhost:8082/auth/users

Write-Host "=== Backup/Restore Test Complete ===" -ForegroundColor Green
```

#### **3. Manual Testing for Phase 5**

**Service Functionality Test:**

```powershell
# Get LoadBalancer IP
$LB_IP = kubectl get svc -n ingress-nginx ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

# Test all endpoints
$tests = @(
    @{ Name = "Auth Health"; URL = "http://$LB_IP/auth/health"; Method = "GET" },
    @{ Name = "Auth Users"; URL = "http://$LB_IP/auth/users"; Method = "GET" },
    @{ Name = "Core Status"; URL = "http://$LB_IP/core/status"; Method = "GET" },
    @{ Name = "Manage Health"; URL = "http://$LB_IP/manage/health"; Method = "GET" },
    @{ Name = "System Health"; URL = "http://$LB_IP/health"; Method = "GET" }
)

foreach ($test in $tests) {
    try {
        $response = Invoke-RestMethod -Uri $test.URL -Method $test.Method -TimeoutSec 10
        Write-Host "✓ $($test.Name): PASS" -ForegroundColor Green
    } catch {
        Write-Host "✗ $($test.Name): FAIL - $($_.Exception.Message)" -ForegroundColor Red
    }
}
```

**Zone Distribution Verification:**

```powershell
# Check if services are distributed across zones
kubectl get pods -o wide --all-namespaces | Format-Table -AutoSize
kubectl get nodes -o wide

# Verify zone distribution
$zones = @("simin", "bamdad", "forough")
foreach ($zone in $zones) {
    Write-Host "=== Pods in $zone zone ===" -ForegroundColor Cyan
    kubectl get pods --all-namespaces -o wide | findstr $zone
}
```

**Performance Monitoring:**

```powershell
# Create monitoring script
while ($true) {
    Clear-Host
    Write-Host "=== ArvanCloud Performance Monitor ===" -ForegroundColor Green
    Write-Host "Timestamp: $(Get-Date)" -ForegroundColor Yellow
    
    Write-Host "`n--- HPA Status ---" -ForegroundColor Cyan
    kubectl get hpa --all-namespaces
    
    Write-Host "`n--- Resource Usage ---" -ForegroundColor Cyan
    kubectl top pods --all-namespaces
    
    Write-Host "`n--- Service Status ---" -ForegroundColor Cyan
    kubectl get svc --all-namespaces
    
    Write-Host "`n--- Load Balancer IP ---" -ForegroundColor Cyan
    kubectl get svc -n ingress-nginx ingress-nginx
    
    Start-Sleep -Seconds 10
}
```

### **🎯 Complete Testing Checklist**

#### **Phase 4 Checklist:**

- [ ] HPA scaling up under load
- [ ] HPA scaling down after load decreases
- [ ] Nginx routing to correct services
- [ ] HAProxy load balancing master nodes
- [ ] Health checks working
- [ ] All endpoints accessible via localhost

#### **Phase 5 Checklist:**

- [ ] All services accessible via ArvanCloud LoadBalancer
- [ ] Services distributed across zones (simin/bamdad/forough)
- [ ] Database backup creation successful
- [ ] Database deletion simulation
- [ ] Database restoration successful
- [ ] Data integrity maintained after restore
- [ ] Auto-scaling working in cloud environment
- [ ] Ingress controller routing properly

### **📹 Video Recording Tips:**

**Phase 4 Video (10 min):**

1. Show `kubectl get all --all-namespaces`
2. Access URLs: `localhost/auth/`, `/core/`, `manage`
3. Run stress test, show HPA scaling
4. Show HAProxy stats at `localhost:8080/stats`
5. Explain Nginx config and routing

**Phase 5 Video (20 min):**

1. Show ArvanCloud cluster overview
2. Demo all service endpoints via LoadBalancer IP
3. Show zone distribution of pods
4. **Complete database backup/restore demo**
5. Show auto-scaling in action
6. Verify data integrity before/after restore

This comprehensive testing strategy ensures you can demonstrate all requirements for both phases! 🚀
