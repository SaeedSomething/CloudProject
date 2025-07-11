# Load Testing Script for HPA Demonstration
# This script generates load to demonstrate auto-scaling

Write-Host "=========================================" -ForegroundColor Green
Write-Host "HPA Load Testing & Scaling Demonstration" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green

# Get LoadBalancer IP
Write-Host "Step 1: Getting LoadBalancer IP..." -ForegroundColor Yellow
$nginxIP = kubectl get svc -n ingress-nginx ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

if ([string]::IsNullOrEmpty($nginxIP)) {
    Write-Host "ERROR: LoadBalancer IP not found!" -ForegroundColor Red
    Write-Host "Run: kubectl get svc -n ingress-nginx ingress-nginx" -ForegroundColor Yellow
    exit 1
}

Write-Host "LoadBalancer IP: $nginxIP" -ForegroundColor Green

# Test endpoints first
Write-Host ""
Write-Host "Step 2: Testing endpoints..." -ForegroundColor Yellow

$endpoints = @(
    @{name="Health"; url="http://$nginxIP/health"},
    @{name="Auth"; url="http://$nginxIP/auth/"},
    @{name="Core"; url="http://$nginxIP/core/"},
    @{name="Manage"; url="http://$nginxIP/manage/"}
)

foreach ($endpoint in $endpoints) {
    try {
        $response = Invoke-WebRequest -Uri $endpoint.url -TimeoutSec 5 -UseBasicParsing
        Write-Host "  ✅ $($endpoint.name): $($response.StatusCode)" -ForegroundColor Green
    } catch {
        Write-Host "  ❌ $($endpoint.name): Failed" -ForegroundColor Red
    }
}

# Show current HPA status
Write-Host ""
Write-Host "Step 3: Current HPA status..." -ForegroundColor Yellow
kubectl get hpa --all-namespaces

Write-Host ""
Write-Host "Step 4: Current pod counts..." -ForegroundColor Yellow
Write-Host "Auth pods:" -ForegroundColor Cyan
kubectl get pods -n auth -l app=auth

Write-Host "Core pods:" -ForegroundColor Cyan
kubectl get pods -n core -l app=core

Write-Host "Manage pods:" -ForegroundColor Cyan
kubectl get pods -n auth -l app=manage

# Start load generation
Write-Host ""
Write-Host "Step 5: Starting load generation..." -ForegroundColor Yellow
Write-Host "This will generate load for 5 minutes to trigger auto-scaling" -ForegroundColor Cyan

# Create load generator job
$loadGenJob = @"
apiVersion: batch/v1
kind: Job
metadata:
  name: load-generator
  namespace: auth
spec:
  parallelism: 5
  completions: 5
  template:
    spec:
      affinity:
        nodeAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            preference:
              matchExpressions:
              - key: topology.kubernetes.io/zone
                operator: In
                values:
                - forough
      containers:
      - name: load-generator
        image: busybox:latest
        command:
        - /bin/sh
        - -c
        - |
          echo "Starting load generation..."
          for i in `seq 1 300`; do
            wget -q -O- http://$nginxIP/auth/ &
            wget -q -O- http://$nginxIP/core/ &
            wget -q -O- http://$nginxIP/manage/ &
            wget -q -O- http://$nginxIP/health &
            sleep 1
          done
          echo "Load generation completed"
        resources:
          requests:
            cpu: 1
            memory: 256Mi
          limits:
            cpu: 1
            memory: 512Mi
      restartPolicy: Never
  backoffLimit: 3
"@

# Apply load generator
$loadGenJob | kubectl apply -f -

Write-Host "✅ Load generator started (5 parallel jobs)" -ForegroundColor Green
Write-Host ""
Write-Host "Monitor scaling in real-time with these commands:" -ForegroundColor Yellow
Write-Host "  kubectl get hpa --all-namespaces -w" -ForegroundColor White
Write-Host "  kubectl get pods --all-namespaces -w" -ForegroundColor White
Write-Host "  kubectl top pods --all-namespaces" -ForegroundColor White
Write-Host ""

# Monitor for 5 minutes
$endTime = (Get-Date).AddMinutes(5)
$iteration = 0

Write-Host "Monitoring for 5 minutes..." -ForegroundColor Cyan
Write-Host "Press Ctrl+C to stop monitoring early" -ForegroundColor Yellow

while ((Get-Date) -lt $endTime) {
    $iteration++
    Write-Host ""
    Write-Host "=== Monitoring Update #$iteration ===" -ForegroundColor Cyan
    Write-Host "Time: $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Gray
    
    Write-Host ""
    Write-Host "HPA Status:" -ForegroundColor Yellow
    kubectl get hpa --all-namespaces --no-headers | ForEach-Object {
        Write-Host "  $_" -ForegroundColor White
    }
    
    Write-Host ""
    Write-Host "Pod Counts:" -ForegroundColor Yellow
    $authPods = (kubectl get pods -n auth -l app=auth --no-headers | Measure-Object).Count
    $corePods = (kubectl get pods -n core -l app=core --no-headers | Measure-Object).Count
    $managePods = (kubectl get pods -n auth -l app=manage --no-headers | Measure-Object).Count
    
    Write-Host "  Auth: $authPods pods" -ForegroundColor White
    Write-Host "  Core: $corePods pods" -ForegroundColor White
    Write-Host "  Manage: $managePods pods" -ForegroundColor White
    
    Start-Sleep -Seconds 30
}

# Cleanup load generator
Write-Host ""
Write-Host "Step 6: Cleaning up load generator..." -ForegroundColor Yellow
kubectl delete job load-generator -n auth

Write-Host ""
Write-Host "=========================================" -ForegroundColor Green
Write-Host "✅ Load Testing Complete!" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green

Write-Host ""
Write-Host "Final Status:" -ForegroundColor Cyan
kubectl get hpa --all-namespaces
kubectl get pods --all-namespaces -l 'app in (auth,core,manage)'

Write-Host ""
Write-Host "Note: Pods will scale down after ~5 minutes of low load" -ForegroundColor Yellow
Write-Host "Monitor with: kubectl get hpa --all-namespaces -w" -ForegroundColor White
