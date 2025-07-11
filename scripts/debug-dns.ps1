# Kubernetes DNS Troubleshooting Script
Write-Host "=== Kubernetes DNS Troubleshooting ===" -ForegroundColor Green

Write-Host ""
Write-Host "1. Checking if MySQL service exists..." -ForegroundColor Yellow
kubectl get svc -n auth
Write-Host ""

Write-Host "2. Checking MySQL service details..." -ForegroundColor Yellow
kubectl describe svc mysql -n auth
Write-Host ""

Write-Host "3. Checking if MySQL pods are running..." -ForegroundColor Yellow
kubectl get pods -n auth -l app=mysql
Write-Host ""

Write-Host "4. Checking auth pods..." -ForegroundColor Yellow
kubectl get pods -n auth -l app=auth
Write-Host ""

Write-Host "5. Testing DNS resolution from auth pod..." -ForegroundColor Yellow
$authPod = kubectl get pods -n auth -l app=auth -o jsonpath='{.items[0].metadata.name}' 2>$null
if (![string]::IsNullOrEmpty($authPod)) {
    Write-Host "Found auth pod: $authPod" -ForegroundColor Cyan
    Write-Host "Testing DNS resolution..." -ForegroundColor Cyan
    
    # Test different DNS formats
    Write-Host "Testing 'mysql' (short name):" -ForegroundColor White
    kubectl exec -n auth $authPod -- nslookup mysql 2>$null
    
    Write-Host "Testing 'mysql.auth' (namespace qualified):" -ForegroundColor White
    kubectl exec -n auth $authPod -- nslookup mysql.auth 2>$null
    
    Write-Host "Testing 'mysql.auth.svc.cluster.local' (FQDN):" -ForegroundColor White
    kubectl exec -n auth $authPod -- nslookup mysql.auth.svc.cluster.local 2>$null
    
    Write-Host "Testing general DNS:" -ForegroundColor White
    kubectl exec -n auth $authPod -- nslookup kubernetes.default 2>$null
} else {
    Write-Host "❌ No auth pod found" -ForegroundColor Red
}

Write-Host ""
Write-Host "6. Checking CoreDNS status..." -ForegroundColor Yellow
kubectl get pods -n kube-system -l k8s-app=kube-dns 2>$null

Write-Host ""
Write-Host "7. Checking service endpoints..." -ForegroundColor Yellow
kubectl get endpoints -n auth

Write-Host ""
Write-Host "=== DNS Analysis Complete ===" -ForegroundColor Green
