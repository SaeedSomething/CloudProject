# Swagger UI Testing Script for Cloud Computing Project
# Tests Swagger UI functionality through both Nginx (Phase 4) and Ingress (Phase 5)

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("nginx", "ingress", "both")]
    [string]$TestMode = "both",
    
    [Parameter(Mandatory=$false)]
    [string]$CustomIP = ""
)

Write-Host "🔬 Swagger UI Testing Script" -ForegroundColor Cyan
Write-Host "=============================" -ForegroundColor Cyan

function Test-SwaggerEndpoint {
    param(
        [string]$URL,
        [string]$Description
    )
    
    Write-Host "Testing: $Description" -ForegroundColor Yellow
    Write-Host "URL: $URL" -ForegroundColor Gray
    
    try {
        $response = Invoke-WebRequest -Uri $URL -UseBasicParsing -TimeoutSec 30
        if ($response.StatusCode -eq 200) {
            Write-Host "✓ PASS: $Description" -ForegroundColor Green
            return $true
        } else {
            Write-Host "✗ FAIL: $Description (Status: $($response.StatusCode))" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "✗ FAIL: $Description" -ForegroundColor Red
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor DarkRed
        return $false
    }
}

function Test-SwaggerUI {
    param(
        [string]$BaseURL,
        [string]$TestName
    )
    
    Write-Host "`n=== Testing Swagger UI: $TestName ===" -ForegroundColor Green
    
    $results = @()
    $endpoints = @(
        @{ Path = "/core/docs"; Description = "Main Swagger UI Documentation Page" },
        @{ Path = "/core/swagger-ui/index.html"; Description = "Swagger UI Index Page" },
        @{ Path = "/core/v3/api-docs"; Description = "OpenAPI v3 Specification" },
        @{ Path = "/core/v3/api-docs/swagger-config"; Description = "Swagger Configuration" }
    )
    
    foreach ($endpoint in $endpoints) {
        $url = "$BaseURL$($endpoint.Path)"
        $success = Test-SwaggerEndpoint -URL $url -Description $endpoint.Description
        $results += $success
    }
    
    # Test Swagger UI assets
    Write-Host "`nTesting Swagger UI Assets..." -ForegroundColor Yellow
    $assets = @(
        "/core/swagger-ui/swagger-ui-bundle.js",
        "/core/swagger-ui/swagger-ui.css",
        "/core/swagger-ui/swagger-ui-standalone-preset.js"
    )
    
    foreach ($asset in $assets) {
        $url = "$BaseURL$asset"
        $success = Test-SwaggerEndpoint -URL $url -Description "Asset: $asset"
        $results += $success
    }
    
    # Test API specification loading
    Write-Host "`nTesting API Specification Loading..." -ForegroundColor Yellow
    try {
        $apiDocs = Invoke-RestMethod -Uri "$BaseURL/core/v3/api-docs" -Method Get
        if ($apiDocs.openapi) {
            Write-Host "✓ API specification loads correctly (OpenAPI $($apiDocs.openapi))" -ForegroundColor Green
            $results += $true
        } else {
            Write-Host "✗ API specification format invalid" -ForegroundColor Red
            $results += $false
        }
    } catch {
        Write-Host "✗ API specification loading failed: $($_.Exception.Message)" -ForegroundColor Red
        $results += $false
    }
    
    # Test path rewriting functionality
    Write-Host "`nTesting Path Rewriting..." -ForegroundColor Yellow
    try {
        $swaggerHTML = Invoke-WebRequest -Uri "$BaseURL/core/docs" -UseBasicParsing
        if ($swaggerHTML.Content -match "/core/swagger-ui") {
            Write-Host "✓ Path rewriting is working correctly" -ForegroundColor Green
            $results += $true
        } else {
            Write-Host "⚠️  Path rewriting may not be working properly" -ForegroundColor Yellow
            $results += $false
        }
    } catch {
        Write-Host "✗ Could not verify path rewriting" -ForegroundColor Red
        $results += $false
    }
    
    # Summary
    $passed = ($results | Where-Object { $_ -eq $true }).Count
    $total = $results.Count
    $percentage = [math]::Round(($passed / $total) * 100, 1)
    
    Write-Host "`n📊 Test Results for $TestName" -ForegroundColor Cyan
    Write-Host "Passed: $passed/$total ($percentage%)" -ForegroundColor $(if ($percentage -ge 80) { "Green" } elseif ($percentage -ge 60) { "Yellow" } else { "Red" })
    
    if ($percentage -ge 80) {
        Write-Host "✅ Swagger UI is functioning well!" -ForegroundColor Green
    } elseif ($percentage -ge 60) {
        Write-Host "⚠️  Swagger UI has some issues but is mostly functional" -ForegroundColor Yellow
    } else {
        Write-Host "❌ Swagger UI has significant issues" -ForegroundColor Red
    }
    
    return $percentage
}

function Show-ManualTestInstructions {
    param([string]$URL)
    
    Write-Host "`n🔍 Manual Testing Instructions" -ForegroundColor Cyan
    Write-Host "===============================" -ForegroundColor Cyan
    Write-Host "Please perform the following manual tests:" -ForegroundColor White
    Write-Host "1. Open browser to: $URL/core/docs" -ForegroundColor Yellow
    Write-Host "2. Verify Swagger UI loads completely with all styles" -ForegroundColor Yellow
    Write-Host "3. Check that all API endpoints are listed" -ForegroundColor Yellow
    Write-Host "4. Test the 'Try it out' functionality on any endpoint" -ForegroundColor Yellow
    Write-Host "5. Verify that API responses are displayed correctly" -ForegroundColor Yellow
    Write-Host "6. Check browser developer tools for any 404 errors on assets" -ForegroundColor Yellow
    Write-Host "7. Verify that relative links work correctly" -ForegroundColor Yellow
}

# Main execution
try {
    if ($TestMode -eq "nginx" -or $TestMode -eq "both") {
        Write-Host "🔧 Testing Phase 4 - Nginx Reverse Proxy" -ForegroundColor Magenta
        
        if ($CustomIP) {
            $nginxURL = "http://$CustomIP"
        } else {
            # Try to get Nginx service IP
            $nginxIP = kubectl get svc -n nginx-lb nginx-lb-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>$null
            if (!$nginxIP) { 
                $nginxIP = "localhost"
                Write-Host "⚠️  Using localhost - make sure HAProxy is running on port 80" -ForegroundColor Yellow
            }
            $nginxURL = "http://$nginxIP"
        }
        
        Write-Host "Using Nginx URL: $nginxURL" -ForegroundColor Cyan
        $nginxScore = Test-SwaggerUI -BaseURL $nginxURL -TestName "Nginx Reverse Proxy"
        Show-ManualTestInstructions -URL $nginxURL
    }
    
    if ($TestMode -eq "ingress" -or $TestMode -eq "both") {
        Write-Host "`n🚀 Testing Phase 5 - ArvanCloud Ingress" -ForegroundColor Magenta
        
        if ($CustomIP) {
            $ingressURL = "http://$CustomIP"
        } else {
            # Try to get LoadBalancer IP
            Write-Host "Getting LoadBalancer IP..." -ForegroundColor Yellow
            $lbIP = kubectl get svc -n ingress-nginx ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>$null
            if (!$lbIP) {
                Write-Host "⚠️  LoadBalancer IP not yet assigned. Waiting 10 seconds..." -ForegroundColor Yellow
                Start-Sleep -Seconds 10
                $lbIP = kubectl get svc -n ingress-nginx ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>$null
            }
            
            if (!$lbIP) {
                Write-Host "❌ Could not get LoadBalancer IP. Is the Ingress deployed on ArvanCloud?" -ForegroundColor Red
                Write-Host "   Try running: kubectl get svc -n ingress-nginx" -ForegroundColor Yellow
                return
            }
            $ingressURL = "http://$lbIP"
        }
        
        Write-Host "Using LoadBalancer URL: $ingressURL" -ForegroundColor Cyan
        $ingressScore = Test-SwaggerUI -BaseURL $ingressURL -TestName "ArvanCloud Ingress"
        Show-ManualTestInstructions -URL $ingressURL
    }
    
    # Final summary
    Write-Host "`n🎯 Final Summary" -ForegroundColor Cyan
    Write-Host "================" -ForegroundColor Cyan
    
    if ($TestMode -eq "both") {
        if ($nginxScore -and $ingressScore) {
            $avgScore = [math]::Round(($nginxScore + $ingressScore) / 2, 1)
            Write-Host "Nginx Score: $nginxScore%" -ForegroundColor $(if ($nginxScore -ge 80) { "Green" } else { "Yellow" })
            Write-Host "Ingress Score: $ingressScore%" -ForegroundColor $(if ($ingressScore -ge 80) { "Green" } else { "Yellow" })
            Write-Host "Average Score: $avgScore%" -ForegroundColor $(if ($avgScore -ge 80) { "Green" } else { "Yellow" })
        }
    }
    
    Write-Host "`n📝 Common Issues and Solutions:" -ForegroundColor Yellow
    Write-Host "• 404 errors on assets: Check sub_filter rules in Nginx config" -ForegroundColor White
    Write-Host "• Relative path issues: Verify Ingress annotations and configuration snippets" -ForegroundColor White
    Write-Host "• API spec not loading: Check /v3/api-docs endpoint handling" -ForegroundColor White
    Write-Host "• CORS errors: Verify CORS headers in both Nginx and Ingress configs" -ForegroundColor White
    
} catch {
    Write-Host "❌ Error during testing: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n✅ Swagger UI testing completed!" -ForegroundColor Green
