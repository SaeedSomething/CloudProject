# HAProxy Management Script for Phase 4
# Run this script from the project root directory

Write-Host "========================================" -ForegroundColor Green
Write-Host "HAProxy External Load Balancer Setup" -ForegroundColor Green  
Write-Host "========================================" -ForegroundColor Green

# Check if haproxy.cfg exists
if (-not (Test-Path "haproxy.cfg")) {
    Write-Host "ERROR: haproxy.cfg not found in current directory!" -ForegroundColor Red
    Write-Host "Make sure you're running this from the project root directory." -ForegroundColor Red
    exit 1
}

# Stop and remove existing HAProxy container if it exists
Write-Host "Stopping existing HAProxy container (if any)..." -ForegroundColor Yellow
docker stop haproxy-external 2>$null
docker rm haproxy-external 2>$null

# Start new HAProxy container
Write-Host "Starting HAProxy external load balancer..." -ForegroundColor Green
docker run -d `
  --name haproxy-external `
  -p 80:80 `
  -p 6443:6443 `
  -p 8080:8080 `
  -v "$(Get-Location)\haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg:ro" `
  haproxy:2.4

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ HAProxy started successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "HAProxy Services:" -ForegroundColor Cyan
    Write-Host "  • Application traffic: http://localhost:80" -ForegroundColor White
    Write-Host "  • Kubernetes API: https://localhost:6443" -ForegroundColor White  
    Write-Host "  • Statistics dashboard: http://localhost:8080/stats" -ForegroundColor White
    Write-Host ""
    
    # Show container status
    Write-Host "Container Status:" -ForegroundColor Cyan
    docker ps --filter "name=haproxy-external" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    
    Write-Host ""
    Write-Host "To view logs: docker logs haproxy-external" -ForegroundColor Yellow
    Write-Host "To stop: docker stop haproxy-external" -ForegroundColor Yellow
    
} else {
    Write-Host "❌ Failed to start HAProxy!" -ForegroundColor Red
    Write-Host "Check Docker logs for details: docker logs haproxy-external" -ForegroundColor Red
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
