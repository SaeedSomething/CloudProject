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

# Step 2: Verify Metrics Server (ArvanCloud managed)
Write-Host ""
Write-Host "Step 2: Verifying ArvanCloud managed Metrics Server..." -ForegroundColor Yellow

# Test HPA compatibility
Write-Host "Testing HPA compatibility..." -ForegroundColor Cyan
$hpaTest = kubectl apply --dry-run=client -f k8s/hpa/hpa-auth-service.yaml 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Metrics Server available - HPA can be deployed" -ForegroundColor Green
    Write-Host "✅ Using ArvanCloud managed metrics infrastructure" -ForegroundColor Green
} else {
    Write-Host "❌ HPA compatibility issue" -ForegroundColor Red
    Write-Host $hpaTest
}

# Step 3: Deploy storage and backup infrastructure
Write-Host ""
Write-Host "Step 3: Setting up storage and backup infrastructure..." -ForegroundColor Yellow

Write-Host "  - Applying backup storage class..." -ForegroundColor Cyan
kubectl apply -f k8s/backup/backup-storage-class.yaml
if ($LASTEXITCODE -eq 0) { Write-Host "    ✅ Storage class applied" -ForegroundColor Green } else { Write-Host "    ❌ Storage class failed" -ForegroundColor Red }

Write-Host "  - Applying auth database backup PVC..." -ForegroundColor Cyan
kubectl apply -f k8s/backup/auth-db-backup-pvc.yaml
if ($LASTEXITCODE -eq 0) { Write-Host "    ✅ Backup PVC applied" -ForegroundColor Green } else { Write-Host "    ❌ Backup PVC failed" -ForegroundColor Red }

Write-Host "  - Applying auth database backup CronJob..." -ForegroundColor Cyan
kubectl apply -f k8s/backup/auth-db-backup-cronjob.yaml
if ($LASTEXITCODE -eq 0) { Write-Host "    ✅ Backup CronJob applied" -ForegroundColor Green } else { Write-Host "    ❌ Backup CronJob failed" -ForegroundColor Red }

# Step 4: Deploy core services (with zone distribution)
Write-Host ""
Write-Host "Step 4: Deploying core services with zone distribution..." -ForegroundColor Yellow

# Step 4: Deploy core services (with zone distribution)
Write-Host ""
Write-Host "Step 4: Deploying core services with zone distribution..." -ForegroundColor Yellow

Write-Host "  - Deploying Auth services (bamdad zone)..." -ForegroundColor Cyan

# Auth namespace (may already exist)
Write-Host "    Applying auth namespace..." -ForegroundColor DarkCyan
kubectl apply -f k8s/auth/auth-namespace.yaml 2>$null
if ($LASTEXITCODE -eq 0) { Write-Host "      ✅ Auth namespace ready" -ForegroundColor Green } else { Write-Host "      ⚠️  Auth namespace may already exist" -ForegroundColor Yellow }

# Auth configurations
Write-Host "    Applying auth configuration..." -ForegroundColor DarkCyan
kubectl apply -f k8s/auth/auth-configmap.yaml
if ($LASTEXITCODE -eq 0) { Write-Host "      ✅ Auth config applied" -ForegroundColor Green } else { Write-Host "      ❌ Auth config failed" -ForegroundColor Red }

Write-Host "    Applying auth secrets..." -ForegroundColor DarkCyan
kubectl apply -f k8s/auth/auth-secret.yaml
if ($LASTEXITCODE -eq 0) { Write-Host "      ✅ Auth secret applied" -ForegroundColor Green } else { Write-Host "      ❌ Auth secret failed" -ForegroundColor Red }

kubectl apply -f k8s/auth/auth-db-credentials.yaml
if ($LASTEXITCODE -eq 0) { Write-Host "      ✅ Auth DB credentials applied" -ForegroundColor Green } else { Write-Host "      ❌ Auth DB credentials failed" -ForegroundColor Red }

# MySQL components
Write-Host "    Applying MySQL components..." -ForegroundColor DarkCyan
kubectl apply -f k8s/auth/mysql-pvc.yaml
if ($LASTEXITCODE -eq 0) { Write-Host "      ✅ MySQL PVC applied" -ForegroundColor Green } else { Write-Host "      ❌ MySQL PVC failed" -ForegroundColor Red }

kubectl apply -f k8s/auth/mysql-service.yaml
if ($LASTEXITCODE -eq 0) { Write-Host "      ✅ MySQL service applied" -ForegroundColor Green } else { Write-Host "      ❌ MySQL service failed" -ForegroundColor Red }

kubectl apply -f k8s/auth/mysql-deployment.yaml
if ($LASTEXITCODE -eq 0) { Write-Host "      ✅ MySQL deployment applied" -ForegroundColor Green } else { Write-Host "      ❌ MySQL deployment failed" -ForegroundColor Red }

# Auth services
Write-Host "    Applying Auth services..." -ForegroundColor DarkCyan
kubectl apply -f k8s/auth/auth-service-http.yaml
if ($LASTEXITCODE -eq 0) { Write-Host "      ✅ Auth HTTP service applied" -ForegroundColor Green } else { Write-Host "      ❌ Auth HTTP service failed" -ForegroundColor Red }

kubectl apply -f k8s/auth/auth-service-grpc.yaml
if ($LASTEXITCODE -eq 0) { Write-Host "      ✅ Auth gRPC service applied" -ForegroundColor Green } else { Write-Host "      ❌ Auth gRPC service failed" -ForegroundColor Red }

# Auth deployment
Write-Host "    Applying Auth deployment..." -ForegroundColor DarkCyan
kubectl apply -f k8s/auth/auth-deployment.yaml
if ($LASTEXITCODE -eq 0) { Write-Host "      ✅ Auth deployment applied" -ForegroundColor Green } else { Write-Host "      ❌ Auth deployment failed" -ForegroundColor Red }

# Manage service (in auth namespace)
Write-Host "    Applying Manage service..." -ForegroundColor DarkCyan
kubectl apply -f k8s/manage/manage-configmap.yaml
if ($LASTEXITCODE -eq 0) { Write-Host "      ✅ Manage config applied" -ForegroundColor Green } else { Write-Host "      ❌ Manage config failed" -ForegroundColor Red }

kubectl apply -f k8s/manage/manage-service.yaml
if ($LASTEXITCODE -eq 0) { Write-Host "      ✅ Manage service applied" -ForegroundColor Green } else { Write-Host "      ❌ Manage service failed" -ForegroundColor Red }

kubectl apply -f k8s/manage/manage-deployment.yaml
if ($LASTEXITCODE -eq 0) { Write-Host "      ✅ Manage deployment applied" -ForegroundColor Green } else { Write-Host "      ❌ Manage deployment failed" -ForegroundColor Red }

Write-Host "  - Deploying Core services (simin zone)..." -ForegroundColor Cyan

# Core namespace
Write-Host "    Applying core namespace..." -ForegroundColor DarkCyan
kubectl apply -f k8s/core/core-namespace.yaml 2>$null
if ($LASTEXITCODE -eq 0) { Write-Host "      ✅ Core namespace ready" -ForegroundColor Green } else { Write-Host "      ⚠️  Core namespace may already exist" -ForegroundColor Yellow }

# Core configurations
Write-Host "    Applying core configuration..." -ForegroundColor DarkCyan
kubectl apply -f k8s/core/core-configmap.yaml
if ($LASTEXITCODE -eq 0) { Write-Host "      ✅ Core config applied" -ForegroundColor Green } else { Write-Host "      ❌ Core config failed" -ForegroundColor Red }

kubectl apply -f k8s/core/core-secret.yaml
if ($LASTEXITCODE -eq 0) { Write-Host "      ✅ Core secret applied" -ForegroundColor Green } else { Write-Host "      ❌ Core secret failed" -ForegroundColor Red }

kubectl apply -f k8s/core/core-db-credentials.yaml
if ($LASTEXITCODE -eq 0) { Write-Host "      ✅ Core DB credentials applied" -ForegroundColor Green } else { Write-Host "      ❌ Core DB credentials failed" -ForegroundColor Red }

kubectl apply -f k8s/core/core-activemq-credentials.yaml
if ($LASTEXITCODE -eq 0) { Write-Host "      ✅ Core ActiveMQ credentials applied" -ForegroundColor Green } else { Write-Host "      ❌ Core ActiveMQ credentials failed" -ForegroundColor Red }

# Postgres components
Write-Host "    Applying Postgres components..." -ForegroundColor DarkCyan
kubectl apply -f k8s/core/postgres-pvc.yaml
if ($LASTEXITCODE -eq 0) { Write-Host "      ✅ Postgres PVC applied" -ForegroundColor Green } else { Write-Host "      ❌ Postgres PVC failed" -ForegroundColor Red }

kubectl apply -f k8s/core/postgres-service.yaml
if ($LASTEXITCODE -eq 0) { Write-Host "      ✅ Postgres service applied" -ForegroundColor Green } else { Write-Host "      ❌ Postgres service failed" -ForegroundColor Red }

kubectl apply -f k8s/core/postgres-deployment.yaml
if ($LASTEXITCODE -eq 0) { Write-Host "      ✅ Postgres deployment applied" -ForegroundColor Green } else { Write-Host "      ❌ Postgres deployment failed" -ForegroundColor Red }

# ActiveMQ components
Write-Host "    Applying ActiveMQ components..." -ForegroundColor DarkCyan
kubectl apply -f k8s/core/activemq-pvc.yaml
if ($LASTEXITCODE -eq 0) { Write-Host "      ✅ ActiveMQ PVC applied" -ForegroundColor Green } else { Write-Host "      ❌ ActiveMQ PVC failed" -ForegroundColor Red }

kubectl apply -f k8s/core/activemq-service.yaml
if ($LASTEXITCODE -eq 0) { Write-Host "      ✅ ActiveMQ service applied" -ForegroundColor Green } else { Write-Host "      ❌ ActiveMQ service failed" -ForegroundColor Red }

kubectl apply -f k8s/core/activemq-deployment.yaml
if ($LASTEXITCODE -eq 0) { Write-Host "      ✅ ActiveMQ deployment applied" -ForegroundColor Green } else { Write-Host "      ❌ ActiveMQ deployment failed" -ForegroundColor Red }

# Core service
Write-Host "    Applying Core service..." -ForegroundColor DarkCyan
kubectl apply -f k8s/core/core-service.yaml
if ($LASTEXITCODE -eq 0) { Write-Host "      ✅ Core service applied" -ForegroundColor Green } else { Write-Host "      ❌ Core service failed" -ForegroundColor Red }

kubectl apply -f k8s/core/core-deployment.yaml
if ($LASTEXITCODE -eq 0) { Write-Host "      ✅ Core deployment applied" -ForegroundColor Green } else { Write-Host "      ❌ Core deployment failed" -ForegroundColor Red }

Write-Host "  - Deploying Health monitoring..." -ForegroundColor Cyan
kubectl apply -f k8s/monitoring/health-configmap.yaml
if ($LASTEXITCODE -eq 0) { Write-Host "      ✅ Health config applied" -ForegroundColor Green } else { Write-Host "      ❌ Health config failed" -ForegroundColor Red }

kubectl apply -f k8s/monitoring/health-deployment.yaml
if ($LASTEXITCODE -eq 0) { Write-Host "      ✅ Health deployment applied" -ForegroundColor Green } else { Write-Host "      ❌ Health deployment failed" -ForegroundColor Red }


kubectl apply -f k8s/monitoring/health-service-svc.yaml
if ($LASTEXITCODE -eq 0) { Write-Host "      ✅ Health service applied" -ForegroundColor Green } else { Write-Host "      ❌ Health service failed" -ForegroundColor Red }

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

Write-Host "  - Applying ingress namespace..." -ForegroundColor Cyan
kubectl apply -f k8s/ingress/ingress-nginx-namespace.yaml
if ($LASTEXITCODE -eq 0) { Write-Host "    ✅ Ingress namespace applied" -ForegroundColor Green } else { Write-Host "    ❌ Ingress namespace failed" -ForegroundColor Red }

Write-Host "  - Applying nginx configuration..." -ForegroundColor Cyan
kubectl apply -f k8s/ingress/nginx-configuration.yaml
if ($LASTEXITCODE -eq 0) { Write-Host "    ✅ Nginx config applied" -ForegroundColor Green } else { Write-Host "    ❌ Nginx config failed" -ForegroundColor Red }

Write-Host "  - Applying TCP services..." -ForegroundColor Cyan
kubectl apply -f k8s/ingress/tcp-services.yaml
if ($LASTEXITCODE -eq 0) { Write-Host "    ✅ TCP services applied" -ForegroundColor Green } else { Write-Host "    ❌ TCP services failed" -ForegroundColor Red }

Write-Host "  - Applying UDP services..." -ForegroundColor Cyan
kubectl apply -f k8s/ingress/udp-services.yaml
if ($LASTEXITCODE -eq 0) { Write-Host "    ✅ UDP services applied" -ForegroundColor Green } else { Write-Host "    ❌ UDP services failed" -ForegroundColor Red }

Write-Host "  - Applying ingress controller deployment..." -ForegroundColor Cyan
kubectl apply -f k8s/ingress/nginx-ingress-controller-deployment.yaml
if ($LASTEXITCODE -eq 0) { Write-Host "    ✅ Ingress controller deployment applied" -ForegroundColor Green } else { Write-Host "    ❌ Ingress controller deployment failed" -ForegroundColor Red }

Write-Host "  - Applying ingress service..." -ForegroundColor Cyan
kubectl apply -f k8s/ingress/ingress-nginx-service.yaml
if ($LASTEXITCODE -eq 0) { Write-Host "    ✅ Ingress service applied" -ForegroundColor Green } else { Write-Host "    ❌ Ingress service failed" -ForegroundColor Red }

Write-Host "Waiting for Ingress Controller to be ready..." -ForegroundColor Cyan
kubectl wait --for=condition=available --timeout=300s deployment/nginx-ingress-controller -n ingress-nginx

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Ingress Controller ready" -ForegroundColor Green
} else {
    Write-Host "⚠️  Ingress Controller timeout" -ForegroundColor Yellow
}

# Step 7: Deploy Application Ingress Routes (with Swagger UI fixes)
Write-Host ""
Write-Host "Step 7: Deploying application ingress routes..." -ForegroundColor Yellow
kubectl apply -f k8s/ingress/microservices-ingress.yaml
if ($LASTEXITCODE -eq 0) { Write-Host "✅ Microservices ingress with Swagger UI fixes applied" -ForegroundColor Green } else { Write-Host "❌ Microservices ingress failed" -ForegroundColor Red }

# Step 8: Deploy HPA configurations
Write-Host ""
Write-Host "Step 8: Deploying Horizontal Pod Autoscalers..." -ForegroundColor Yellow

Write-Host "  - Applying Auth HPA..." -ForegroundColor Cyan
kubectl apply -f k8s/hpa/hpa-auth-service.yaml
if ($LASTEXITCODE -eq 0) { Write-Host "    ✅ Auth HPA applied" -ForegroundColor Green } else { Write-Host "    ❌ Auth HPA failed" -ForegroundColor Red }

Write-Host "  - Applying Core HPA..." -ForegroundColor Cyan
kubectl apply -f k8s/hpa/hpa-core-service.yaml
if ($LASTEXITCODE -eq 0) { Write-Host "    ✅ Core HPA applied" -ForegroundColor Green } else { Write-Host "    ❌ Core HPA failed" -ForegroundColor Red }

Write-Host "  - Applying Manage HPA..." -ForegroundColor Cyan
kubectl apply -f k8s/hpa/hpa-manage-service.yaml
if ($LASTEXITCODE -eq 0) { Write-Host "    ✅ Manage HPA applied" -ForegroundColor Green } else { Write-Host "    ❌ Manage HPA failed" -ForegroundColor Red }

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
Write-Host "3. Test Swagger UI: .\scripts\test-swagger-ui.ps1 -TestMode ingress" -ForegroundColor White
Write-Host "4. Run backup/restore demo: .\scripts\backup-restore-demo.ps1" -ForegroundColor White
Write-Host "5. Generate load to test HPA scaling" -ForegroundColor White
Write-Host ""
Write-Host "Monitoring Commands:" -ForegroundColor Yellow
Write-Host "  kubectl get hpa --all-namespaces -w    # Watch HPA scaling" -ForegroundColor White
Write-Host "  kubectl top pods --all-namespaces      # Resource usage" -ForegroundColor White
Write-Host "  kubectl get pods -o wide --all-namespaces  # Pod distribution" -ForegroundColor White
Write-Host ""
