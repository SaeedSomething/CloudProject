# ArvanCloud Microservices Testing Script
# This script tests all ingress endpoints to verify Phase 5 deployment

Write-Host "=== ArvanCloud Microservices Testing Script ===" -ForegroundColor Green
Write-Host "Testing all microservice endpoints..." -ForegroundColor Yellow

# Define test URLs
$testUrls = @{
    "Auth HTTP Service" = "http://auth-http-c9a4c1e532-auth.apps.ir-central1.arvancaas.ir"
    "Manage Service" = "http://manage-c9a4c1e532-auth.apps.ir-central1.arvancaas.ir"
    "Health Service" = "http://health-c9a4c1e532-auth.apps.ir-central1.arvancaas.ir"
    "Core Service" = "http://core-c9a4c1e532-core.apps.ir-central1.arvancaas.ir"
}

$swaggerUrls = @{
    "Auth Swagger UI" = "http://auth-http-c9a4c1e532-auth.apps.ir-central1.arvancaas.ir/swagger-ui/"
    "Manage Swagger UI" = "http://manage-c9a4c1e532-auth.apps.ir-central1.arvancaas.ir/swagger-ui/"
    "Core Swagger UI" = "http://core-c9a4c1e532-core.apps.ir-central1.arvancaas.ir/swagger-ui/"
}

# Function to test URL
function Test-Endpoint {
    param(
        [string]$Name,
        [string]$Url
    )
    
    Write-Host "`nTesting $Name..." -ForegroundColor Cyan
    Write-Host "URL: $Url" -ForegroundColor Gray
    
    try {
        $response = Invoke-WebRequest -Uri $Url -Method GET -TimeoutSec 10 -UseBasicParsing
        if ($response.StatusCode -eq 200) {
            Write-Host "✓ $Name is accessible (Status: $($response.StatusCode))" -ForegroundColor Green
            return $true
        } else {
            Write-Host "⚠ $Name returned status: $($response.StatusCode)" -ForegroundColor Yellow
            return $false
        }
    }
    catch {
        Write-Host "✗ $Name is not accessible: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Test main service endpoints
Write-Host "`n--- Testing Main Service Endpoints ---" -ForegroundColor Yellow
$successCount = 0
foreach ($service in $testUrls.GetEnumerator()) {
    if (Test-Endpoint -Name $service.Key -Url $service.Value) {
        $successCount++
    }
}

# Test Swagger UI endpoints
Write-Host "`n--- Testing Swagger UI Endpoints ---" -ForegroundColor Yellow
$swaggerSuccessCount = 0
foreach ($swagger in $swaggerUrls.GetEnumerator()) {
    if (Test-Endpoint -Name $swagger.Key -Url $swagger.Value) {
        $swaggerSuccessCount++
    }
}

# Summary
Write-Host "`n--- Test Summary ---" -ForegroundColor Green
Write-Host "Main Services: $successCount/$($testUrls.Count) accessible" -ForegroundColor Cyan
Write-Host "Swagger UIs: $swaggerSuccessCount/$($swaggerUrls.Count) accessible" -ForegroundColor Cyan

# Display ingress status
Write-Host "`n--- Current Ingress Status ---" -ForegroundColor Yellow
Write-Host "Auth namespace ingresses:"
kubectl get ingress -n auth
Write-Host "`nCore namespace ingresses:"
kubectl get ingress -n core

# Additional service information
Write-Host "`n--- Service Information ---" -ForegroundColor Yellow
Write-Host "Auth namespace services:"
kubectl get svc -n auth
Write-Host "`nCore namespace services:"
kubectl get svc -n core

Write-Host "`n=== Testing Complete ===" -ForegroundColor Green
