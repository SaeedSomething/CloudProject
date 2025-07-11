# Health Deployment Validation Script
Write-Host "=== Health Deployment Validation ===" -ForegroundColor Green

# Step 1: Validate YAML syntax
Write-Host "1. Validating YAML syntax..." -ForegroundColor Yellow
$yamlValidation = kubectl apply --dry-run=client -f k8s/monitoring/health-deployment.yaml 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ YAML syntax is valid" -ForegroundColor Green
} else {
    Write-Host "❌ YAML syntax error:" -ForegroundColor Red
    Write-Host $yamlValidation
    exit 1
}

# Step 2: Check if auth namespace exists
Write-Host ""
Write-Host "2. Checking auth namespace..." -ForegroundColor Yellow
$authNs = kubectl get namespace auth 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Auth namespace exists" -ForegroundColor Green
} else {
    Write-Host "❌ Auth namespace not found" -ForegroundColor Red
    Write-Host "Creating auth namespace..." -ForegroundColor Cyan
    kubectl create namespace auth
}

# Step 3: Check if health-config ConfigMap exists
Write-Host ""
Write-Host "3. Checking health-config ConfigMap..." -ForegroundColor Yellow
$healthConfig = kubectl get configmap health-config -n auth 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ health-config ConfigMap exists" -ForegroundColor Green
} else {
    Write-Host "❌ health-config ConfigMap not found" -ForegroundColor Red
    Write-Host "Applying health-config ConfigMap..." -ForegroundColor Cyan
    kubectl apply -f k8s/monitoring/health-configmap.yaml
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ health-config ConfigMap created" -ForegroundColor Green
    } else {
        Write-Host "❌ Failed to create health-config ConfigMap" -ForegroundColor Red
    }
}

# Step 4: Check resource requirements
Write-Host ""
Write-Host "4. Validating resource requirements..." -ForegroundColor Yellow
$yamlContent = Get-Content k8s/monitoring/health-deployment.yaml -Raw
if ($yamlContent -match "requests:" -and $yamlContent -match "cpu: 1") {
    Write-Host "✅ Resource requirements are properly set" -ForegroundColor Green
} else {
    Write-Host "❌ Resource requirements may be missing or incorrect" -ForegroundColor Red
}

# Step 5: Test server-side validation
Write-Host ""
Write-Host "5. Testing server-side validation..." -ForegroundColor Yellow
kubectl apply --dry-run=server -f k8s/monitoring/health-deployment.yaml
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Server-side validation passed" -ForegroundColor Green
    Write-Host ""
    Write-Host "Ready to apply health deployment!" -ForegroundColor Cyan
    Write-Host "Run: kubectl apply -f k8s/monitoring/health-deployment.yaml" -ForegroundColor White
} else {
    Write-Host "❌ Server-side validation failed" -ForegroundColor Red
    Write-Host "There may be an issue with the ArvanCloud cluster or permissions" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Validation Complete ===" -ForegroundColor Green
