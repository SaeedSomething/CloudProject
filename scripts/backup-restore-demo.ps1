# Phase 5 Step 2: Auth Database Backup & Restore Demonstration (PowerShell)
# This script demonstrates database backup and restore on ArvanCloud

Write-Host "=========================================" -ForegroundColor Green
Write-Host "Phase 5 Step 2: Database Backup & Restore" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green

# Set variables
$NAMESPACE = "auth"
$BACKUP_FILE = "auth-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss').sql"
$DB_NAME = "authdb"

# Function to get MySQL pod name
function Get-MySQLPod {
    $pod = kubectl get pods -n $NAMESPACE -l app=mysql -o jsonpath='{.items[0].metadata.name}'
    return $pod
}

# Function to check MySQL connectivity
function Test-MySQLConnection {
    param($podName)
    $result = kubectl exec -n $NAMESPACE $podName -- mysql -u root -pauth_pass -e "SELECT 1;" 2>$null
    return $LASTEXITCODE -eq 0
}

Write-Host "Step 1: Checking MySQL connectivity..." -ForegroundColor Yellow
$MYSQL_POD = Get-MySQLPod

if ([string]::IsNullOrEmpty($MYSQL_POD)) {
    Write-Host "ERROR: MySQL pod not found!" -ForegroundColor Red
    exit 1
}

Write-Host "Found MySQL pod: $MYSQL_POD" -ForegroundColor Cyan

if (-not (Test-MySQLConnection $MYSQL_POD)) {
    Write-Host "ERROR: Cannot connect to MySQL!" -ForegroundColor Red
    exit 1
}

Write-Host "✅ MySQL connection successful" -ForegroundColor Green

Write-Host ""
Write-Host "Step 2: Creating database backup..." -ForegroundColor Yellow
Write-Host "Backup file: $BACKUP_FILE" -ForegroundColor Cyan

# Create backup
kubectl exec -n $NAMESPACE $MYSQL_POD -- mysqldump -u root -pauth_pass --single-transaction --routines --triggers $DB_NAME > $BACKUP_FILE

if ($LASTEXITCODE -eq 0) {
    $backupSize = (Get-Item $BACKUP_FILE).Length / 1KB
    Write-Host "✅ Backup created successfully: $BACKUP_FILE" -ForegroundColor Green
    Write-Host "Backup size: $([math]::Round($backupSize, 2)) KB" -ForegroundColor Cyan
} else {
    Write-Host "❌ Backup failed!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Step 3: Demonstrating database deletion..." -ForegroundColor Yellow
Write-Host "WARNING: About to delete database '$DB_NAME' for demonstration" -ForegroundColor Red
$continue = Read-Host "Continue? (y/N)"

if ($continue -ne 'y' -and $continue -ne 'Y') {
    Write-Host "Operation cancelled" -ForegroundColor Yellow
    exit 1
}

# Drop database
kubectl exec -n $NAMESPACE $MYSQL_POD -- mysql -u root -pauth_pass -e "DROP DATABASE $DB_NAME;"

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Database '$DB_NAME' deleted successfully" -ForegroundColor Green
} else {
    Write-Host "❌ Database deletion failed!" -ForegroundColor Red
    exit 1
}

# Verify deletion
Write-Host "Verifying database deletion..." -ForegroundColor Yellow
$dbExists = kubectl exec -n $NAMESPACE $MYSQL_POD -- mysql -u root -pauth_pass -e "SHOW DATABASES;" | Select-String $DB_NAME

if (-not $dbExists) {
    Write-Host "✅ Database deletion confirmed" -ForegroundColor Green
} else {
    Write-Host "❌ Database still exists!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Step 4: Recreating database..." -ForegroundColor Yellow

# Recreate database
kubectl exec -n $NAMESPACE $MYSQL_POD -- mysql -u root -pauth_pass -e "CREATE DATABASE $DB_NAME;"

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Database '$DB_NAME' recreated successfully" -ForegroundColor Green
} else {
    Write-Host "❌ Database recreation failed!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Step 5: Restoring data from backup..." -ForegroundColor Yellow

# Restore from backup
Get-Content $BACKUP_FILE | kubectl exec -i -n $NAMESPACE $MYSQL_POD -- mysql -u root -pauth_pass $DB_NAME

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Database restored successfully from $BACKUP_FILE" -ForegroundColor Green
} else {
    Write-Host "❌ Database restore failed!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Step 6: Verification..." -ForegroundColor Yellow

# Verify restore
$tables = kubectl exec -n $NAMESPACE $MYSQL_POD -- mysql -u root -pauth_pass -e "USE $DB_NAME; SHOW TABLES;"
$tableCount = ($tables -split "`n").Count - 1

Write-Host "Tables found in restored database: $tableCount" -ForegroundColor Cyan

if ($tableCount -gt 0) {
    Write-Host "✅ Database restore verification successful" -ForegroundColor Green
    
    # Show some data to prove it's working
    Write-Host ""
    Write-Host "Sample data from restored database:" -ForegroundColor Cyan
    kubectl exec -n $NAMESPACE $MYSQL_POD -- mysql -u root -pauth_pass -e "USE $DB_NAME; SHOW TABLES;" 2>$null
} else {
    Write-Host "❌ Database restore verification failed" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Green
Write-Host "✅ Phase 5 Step 2 Completed Successfully!" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host "Summary:" -ForegroundColor Cyan
Write-Host "- ✅ Database backup created: $BACKUP_FILE" -ForegroundColor White
Write-Host "- ✅ Original database deleted" -ForegroundColor White
Write-Host "- ✅ Database recreated" -ForegroundColor White
Write-Host "- ✅ Data restored from backup" -ForegroundColor White
Write-Host "- ✅ Restoration verified" -ForegroundColor White
Write-Host ""
Write-Host "Backup file saved as: $BACKUP_FILE" -ForegroundColor Yellow
Write-Host "Keep this file for future use!" -ForegroundColor Yellow
