# Complete Phase 4 Deployment Script
# This script deploys the entire Phase 4 setup with HAProxy, Nginx, and Auto-scaling

Write-Host "========================================" -ForegroundColor Green
Write-Host "Phase 4 - Complete Deployment Script" -ForegroundColor Green
Write-Host "HAProxy + Nginx + Auto-scaling" -ForegroundColor Green  
Write-Host "========================================" -ForegroundColor Green

# Step 1: Create Kind cluster with updated config
Write-Host ""
Write-Host "Step 1: Creating Kind cluster..." -ForegroundColor Cyan
kind delete cluster --name=notif-mgmt 2>$null
kind create cluster --config=k8s/kind-config.yaml --name=notif-mgmt

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to create Kind cluster!" -ForegroundColor Red
    exit 1
}

# Step 2: Load Docker images
Write-Host ""
Write-Host "Step 2: Loading Docker images..." -ForegroundColor Cyan
kind load docker-image project-auth-service:latest --name=notif-mgmt
kind load docker-image project-core-service:latest --name=notif-mgmt
kind load docker-image project-manage-service:latest --name=notif-mgmt
kind load docker-image webcenter/activemq:latest --name=notif-mgmt
kind load docker-image postgres:13.13-bullseye --name=notif-mgmt
kind load docker-image mysql:latest --name=notif-mgmt
kind load docker-image nginx:1.21 --name=notif-mgmt

# Step 3: Deploy Auth service
Write-Host ""
Write-Host "Step 3: Deploying Auth service..." -ForegroundColor Cyan
kubectl apply -f k8s/auth/auth-namespace.yaml
kubectl apply -f k8s/auth/auth-configmap.yaml 
kubectl apply -f k8s/auth/auth-secret.yaml
kubectl apply -f k8s/auth/auth-db-credentials.yaml
kubectl apply -f k8s/auth/mysql-pvc.yaml 
kubectl apply -f k8s/auth/mysql-deployment.yaml 
kubectl apply -f k8s/auth/mysql-service.yaml
kubectl apply -f k8s/auth/auth-deployment.yaml 
kubectl apply -f k8s/auth/auth-service-http.yaml 
kubectl apply -f k8s/auth/auth-service-grpc.yaml

# Step 4: Deploy Core service
Write-Host ""
Write-Host "Step 4: Deploying Core service..." -ForegroundColor Cyan
kubectl apply -f k8s/core/core-namespace.yaml
kubectl apply -f k8s/core/core-configmap.yaml 
kubectl apply -f k8s/core/core-secret.yaml
kubectl apply -f k8s/core/core-activemq-credentials.yaml
kubectl apply -f k8s/core/core-db-credentials.yaml
kubectl apply -f k8s/core/postgres-pvc.yaml 
kubectl apply -f k8s/core/postgres-deployment.yaml 
kubectl apply -f k8s/core/postgres-service.yaml
kubectl apply -f k8s/core/activemq-pvc.yaml 
kubectl apply -f k8s/core/activemq-deployment.yaml 
kubectl apply -f k8s/core/activemq-service.yaml
kubectl apply -f k8s/core/core-deployment.yaml 
kubectl apply -f k8s/core/core-service.yaml

# Step 5: Deploy Manage service
Write-Host ""
Write-Host "Step 5: Deploying Manage service..." -ForegroundColor Cyan
kubectl apply -f k8s/manage/manage-namespace.yaml
kubectl apply -f k8s/manage/manage-configmap.yaml
kubectl apply -f k8s/manage/manage-deployment.yaml
kubectl apply -f k8s/manage/manage-service.yaml

# Step 6: Deploy Nginx Load Balancer
Write-Host ""
Write-Host "Step 6: Deploying Nginx Load Balancer..." -ForegroundColor Cyan
kubectl apply -f k8s/nginx/nginx-namespace.yaml
kubectl apply -f k8s/nginx/nginx-configmap.yaml
kubectl apply -f k8s/nginx/nginx-deployment.yaml

# Step 7: Enable Metrics Server for HPA
Write-Host ""
Write-Host "Step 7: Installing Metrics Server..." -ForegroundColor Cyan
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Wait for metrics server to be ready
Write-Host "Waiting for metrics server to be ready..." -ForegroundColor Yellow
kubectl wait --for=condition=ready pod -l k8s-app=metrics-server -n kube-system --timeout=120s

# Step 8: Deploy HPA configurations
Write-Host ""
Write-Host "Step 8: Deploying HPA configurations..." -ForegroundColor Cyan
kubectl apply -f k8s/hpa/hpa-auth-service.yaml
kubectl apply -f k8s/hpa/hpa-core-service.yaml
kubectl apply -f k8s/hpa/hpa-manage-service.yaml

# Step 9: Wait for deployments to be ready
Write-Host ""
Write-Host "Step 9: Waiting for deployments to be ready..." -ForegroundColor Cyan
kubectl wait --for=condition=ready pod -l app=nginx-lb -n nginx-lb --timeout=120s
kubectl wait --for=condition=ready pod -l app=auth -n auth --timeout=120s
kubectl wait --for=condition=ready pod -l app=core -n core --timeout=120s
kubectl wait --for=condition=ready pod -l app=manage -n manage --timeout=120s

# Step 10: Start external HAProxy
Write-Host ""
Write-Host "Step 10: Starting external HAProxy..." -ForegroundColor Cyan
& .\start-haproxy.ps1

# Step 11: Display status
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Deployment Status" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

Write-Host ""
Write-Host "Services:" -ForegroundColor Cyan
kubectl get svc --all-namespaces

Write-Host ""
Write-Host "HPA Status:" -ForegroundColor Cyan
kubectl get hpa --all-namespaces

Write-Host ""
Write-Host "Pods:" -ForegroundColor Cyan
kubectl get pods --all-namespaces

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "✅ Phase 4 Deployment Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Access Points:" -ForegroundColor Cyan
Write-Host "  • Application: http://localhost/auth/, http://localhost/core/, http://localhost/manage/" -ForegroundColor White
Write-Host "  • HAProxy Stats: http://localhost:8080/stats" -ForegroundColor White
Write-Host "  • Kubernetes API: https://localhost:6443" -ForegroundColor White
Write-Host ""
Write-Host "Monitoring Commands:" -ForegroundColor Yellow
Write-Host "  • kubectl get hpa --all-namespaces -w" -ForegroundColor White
Write-Host "  • kubectl top pods --all-namespaces" -ForegroundColor White
Write-Host "  • docker logs haproxy-external" -ForegroundColor White
Write-Host ""
