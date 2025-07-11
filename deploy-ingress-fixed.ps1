# ArvanCloud Ingress Deployment Script
# This script deploys minimal ArvanCloud-compatible ingress configurations

Write-Host "=== ArvanCloud Ingress Deployment Script ===" -ForegroundColor Green
Write-Host "Deploying ingress configurations for all microservices..." -ForegroundColor Yellow

# Function to apply resource with error handling
function Invoke-ResourceApply {
    param(
        [string]$ResourceFile,
        [string]$Description
    )
    
    Write-Host "`nApplying $Description..." -ForegroundColor Cyan
    Write-Host "File: $ResourceFile" -ForegroundColor Gray
    
    try {
        kubectl apply -f $ResourceFile
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ Successfully applied $Description" -ForegroundColor Green
        } else {
            Write-Host "✗ Failed to apply $Description" -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "✗ Error applying $Description : $_" -ForegroundColor Red
        return $false
    }
    return $true
}

# Apply individual simple ingress configurations (following existing pattern)
Write-Host "`n--- Applying Simple Ingress Configurations ---" -ForegroundColor Yellow

$simpleIngresses = @(
    @{ File = "k8s\ingress\auth-http-ingress.yaml"; Desc = "Auth HTTP Ingress" },
    @{ File = "k8s\ingress\manage-ingress.yaml"; Desc = "Manage Service Ingress" },
    @{ File = "k8s\ingress\health-ingress.yaml"; Desc = "Health Service Ingress" },
    @{ File = "k8s\ingress\core-ingress.yaml"; Desc = "Core Service Ingress" }
)

$successCount = 0
foreach ($ingress in $simpleIngresses) {
    if (Invoke-ResourceApply -ResourceFile $ingress.File -Description $ingress.Desc) {
        $successCount++
    }
}

Write-Host "`n--- Optional: Cross-namespace service for unified ingress ---" -ForegroundColor Yellow
Invoke-ResourceApply -ResourceFile "k8s\ingress\core-external-service.yaml" -Description "Core External Service (for cross-namespace access)"

Write-Host "`n--- Deployment Summary ---" -ForegroundColor Green
Write-Host "Simple ingresses applied: $successCount/$($simpleIngresses.Count)" -ForegroundColor Cyan

# Check ingress status
Write-Host "`n--- Checking Ingress Status ---" -ForegroundColor Yellow
Write-Host "Ingresses in auth namespace:"
kubectl get ingress -n auth

Write-Host "`nIngresses in core namespace:"
kubectl get ingress -n core

Write-Host "`n--- Access URLs ---" -ForegroundColor Green
Write-Host "Auth HTTP Service: http://auth-http-c9a4c1e532-auth.apps.ir-central1.arvancaas.ir"
Write-Host "Manage Service: http://manage-c9a4c1e532-auth.apps.ir-central1.arvancaas.ir"
Write-Host "Health Service: http://health-c9a4c1e532-auth.apps.ir-central1.arvancaas.ir"
Write-Host "Core Service: http://core-c9a4c1e532-core.apps.ir-central1.arvancaas.ir"

Write-Host "`n--- Swagger UI URLs ---" -ForegroundColor Cyan
Write-Host "Auth Swagger UI: http://auth-http-c9a4c1e532-auth.apps.ir-central1.arvancaas.ir/swagger-ui/"
Write-Host "Manage Swagger UI: http://manage-c9a4c1e532-auth.apps.ir-central1.arvancaas.ir/swagger-ui/"
Write-Host "Core Swagger UI: http://core-c9a4c1e532-core.apps.ir-central1.arvancaas.ir/swagger-ui/"

Write-Host "`n=== Ingress Deployment Complete ===" -ForegroundColor Green
