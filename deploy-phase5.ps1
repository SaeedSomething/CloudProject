# Complete Phase 5 ArvanCloud Deployment Script
# This script deploys all Phase 5 components to ArvanCloud

Write-Host "=========================================" -ForegroundColor Green
Write-Host "Phase 5: Complete ArvanCloud Deployment" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green

# Verify kubectl context
Write-Host "Step 1: Verifying ArvanCloud cluster connection..." -ForegroundColor Yellow
$currentContext = kubectl config current-context
Write-Host "Current kubectl context: $currentContext" -ForegroundColor Cyan

if ($currentContext -notmatch "arvan") {
    Write-Host "WARNING: Not connected to ArvanCloud cluster!" -ForegroundColor Red
    $continue = Read-Host "Continue anyway? (y/N)"
    if ($continue -ne 'y') { exit 1 }
}

# Step 2: Apply Metrics Server (required for HPA)
Write-Host ""
Write-Host "Step 2: Installing Metrics Server..." -ForegroundColor Yellow
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Wait for metrics server
Write-Host "Waiting for metrics server to be ready..." -ForegroundColor Cyan
kubectl wait --for=condition=ready pod -l k8s-app=metrics-server -n kube-system --timeout=180s

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Metrics server ready" -ForegroundColor Green
} else {
    Write-Host "⚠️  Metrics server timeout (may still be starting)" -ForegroundColor Yellow
}

# Step 3: Deploy storage and backup infrastructure
Write-Host ""
Write-Host "Step 3: Setting up storage and backup infrastructure..." -ForegroundColor Yellow
kubectl apply -f k8s/backup/backup-storage-class.yaml
kubectl apply -f k8s/backup/auth-db-backup-pvc.yaml
kubectl apply -f k8s/backup/auth-db-backup-cronjob.yaml

# Step 4: Deploy core services (with zone distribution)
Write-Host ""
Write-Host "Step 4: Deploying core services with zone distribution..." -ForegroundColor Yellow

Write-Host "  - Deploying Auth services (bamdad zone)..." -ForegroundColor Cyan
kubectl apply -f k8s/auth/

Write-Host "  - Deploying Core services (simin zone)..." -ForegroundColor Cyan
kubectl apply -f k8s/core/

Write-Host "  - Deploying Health monitoring..." -ForegroundColor Cyan
kubectl apply -f k8s/monitoring/health-configmap.yaml
kubectl apply -f k8s/monitoring/health-deployment.yaml  
kubectl apply -f k8s/monitoring/health-service-svc.yaml

# Step 5: Wait for core services to be ready
Write-Host ""
Write-Host "Step 5: Waiting for core services to be ready..." -ForegroundColor Yellow

$deployments = @(
    @{name="mysql"; namespace="auth"},
    @{name="auth"; namespace="auth"},
    @{name="manage"; namespace="auth"},
    @{name="postgres"; namespace="core"},
    @{name="activemq"; namespace="core"},
    @{name="core"; namespace="core"}
)

foreach ($deployment in $deployments) {
    Write-Host "  - Waiting for $($deployment.name) in $($deployment.namespace)..." -ForegroundColor Cyan
    kubectl wait --for=condition=available --timeout=300s deployment/$($deployment.name) -n $($deployment.namespace)
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "    ✅ $($deployment.name) ready" -ForegroundColor Green
    } else {
        Write-Host "    ⚠️  $($deployment.name) timeout" -ForegroundColor Yellow
    }
}

# Step 6: Deploy Ingress Controller
Write-Host ""
Write-Host "Step 6: Deploying Nginx Ingress Controller..." -ForegroundColor Yellow
kubectl apply -f k8s/ingress/ingress-nginx-namespace.yaml
kubectl apply -f k8s/ingress/nginx-configuration.yaml
kubectl apply -f k8s/ingress/tcp-services.yaml
kubectl apply -f k8s/ingress/udp-services.yaml
kubectl apply -f k8s/ingress/nginx-ingress-controller-deployment.yaml
kubectl apply -f k8s/ingress/ingress-nginx-service.yaml

Write-Host "Waiting for Ingress Controller to be ready..." -ForegroundColor Cyan
kubectl wait --for=condition=available --timeout=300s deployment/nginx-ingress-controller -n ingress-nginx

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Ingress Controller ready" -ForegroundColor Green
} else {
    Write-Host "⚠️  Ingress Controller timeout" -ForegroundColor Yellow
}

# Step 7: Deploy Application Ingress Routes
Write-Host ""
Write-Host "Step 7: Deploying application ingress routes..." -ForegroundColor Yellow
kubectl apply -f k8s/ingress/microservices-ingress.yaml

# Step 8: Deploy HPA configurations
Write-Host ""
Write-Host "Step 8: Deploying Horizontal Pod Autoscalers..." -ForegroundColor Yellow
kubectl apply -f k8s/hpa/hpa-auth-service.yaml
kubectl apply -f k8s/hpa/hpa-core-service.yaml
kubectl apply -f k8s/hpa/hpa-manage-service.yaml

# Wait a moment for HPA to initialize
Start-Sleep -Seconds 10

# Step 9: Verification and Status Display
Write-Host ""
Write-Host "Step 9: Verification and status..." -ForegroundColor Yellow

Write-Host ""
Write-Host "=== Pod Status ===" -ForegroundColor Cyan
kubectl get pods --all-namespaces -o wide

Write-Host ""
Write-Host "=== Service Status ===" -ForegroundColor Cyan
kubectl get svc --all-namespaces

Write-Host ""
Write-Host "=== Ingress Status ===" -ForegroundColor Cyan
kubectl get ingress --all-namespaces

Write-Host ""
Write-Host "=== HPA Status ===" -ForegroundColor Cyan
kubectl get hpa --all-namespaces

Write-Host ""
Write-Host "=== LoadBalancer External IPs ===" -ForegroundColor Cyan
kubectl get svc -n ingress-nginx ingress-nginx

# Step 10: Testing endpoints
Write-Host ""
Write-Host "Step 10: Testing application endpoints..." -ForegroundColor Yellow

$nginxService = kubectl get svc -n ingress-nginx ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

if ([string]::IsNullOrEmpty($nginxService)) {
    Write-Host "⚠️  LoadBalancer IP not yet assigned. Check status with:" -ForegroundColor Yellow
    Write-Host "   kubectl get svc -n ingress-nginx ingress-nginx" -ForegroundColor White
} else {
    Write-Host "✅ LoadBalancer IP: $nginxService" -ForegroundColor Green
    Write-Host ""
    Write-Host "Test your services at:" -ForegroundColor Cyan
    Write-Host "  - Auth service: http://$nginxService/auth/" -ForegroundColor White
    Write-Host "  - Core service: http://$nginxService/core/" -ForegroundColor White
    Write-Host "  - Manage service: http://$nginxService/manage/" -ForegroundColor White
    Write-Host "  - Health check: http://$nginxService/health" -ForegroundColor White
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Green
Write-Host "✅ Phase 5 Deployment Complete!" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green

Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "1. Wait for LoadBalancer IP assignment" -ForegroundColor White
Write-Host "2. Test all service endpoints" -ForegroundColor White
Write-Host "3. Run backup/restore demo: .\scripts\backup-restore-demo.ps1" -ForegroundColor White
Write-Host "4. Generate load to test HPA scaling" -ForegroundColor White
Write-Host ""
Write-Host "Monitoring Commands:" -ForegroundColor Yellow
Write-Host "  kubectl get hpa --all-namespaces -w    # Watch HPA scaling" -ForegroundColor White
Write-Host "  kubectl top pods --all-namespaces      # Resource usage" -ForegroundColor White
Write-Host "  kubectl get pods -o wide --all-namespaces  # Pod distribution" -ForegroundColor White
Write-Host ""
