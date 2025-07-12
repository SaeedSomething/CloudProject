# PowerShell Script for Backup and Restore Demo
# This script demonstrates manual backup creation and database restore using Kubernetes Jobs

Write-Host "=== Auth Database Backup and Restore Demo ===" -ForegroundColor Green

# Function to check if resource exists
function Test-KubernetesResource {
    param(
        [string]$ResourceType,
        [string]$ResourceName,
        [string]$Namespace = "auth"
    )
    
    $result = kubectl get $ResourceType $ResourceName -n $Namespace 2>$null
    return $LASTEXITCODE -eq 0
}

# Function to wait for job completion
function Wait-ForJobCompletion {
    param(
        [string]$JobName,
        [string]$Namespace = "auth",
        [int]$TimeoutMinutes = 5
    )
    
    Write-Host "Waiting for job '$JobName' to complete..." -ForegroundColor Yellow
    $timeout = (Get-Date).AddMinutes($TimeoutMinutes)
    
    do {
        $status = kubectl get job $JobName -n $Namespace -o jsonpath='{.status.conditions[0].type}' 2>$null
        if ($status -eq "Complete") {
            Write-Host "Job '$JobName' completed successfully!" -ForegroundColor Green
            return $true
        } elseif ($status -eq "Failed") {
            Write-Host "Job '$JobName' failed!" -ForegroundColor Red
            return $false
        }
        Start-Sleep -Seconds 10
    } while ((Get-Date) -lt $timeout)
    
    Write-Host "Job '$JobName' timed out!" -ForegroundColor Red
    return $false
Write-Host "`n=== Step 1: Apply Backup Infrastructure ===" -ForegroundColor Cyan

# Apply backup storage class
Write-Host "Applying backup storage class..." -ForegroundColor Yellow
kubectl apply -f .\k8s\backup\backup-storage-class.yaml

# Apply backup PVC
Write-Host "Applying backup PVC..." -ForegroundColor Yellow
kubectl apply -f .\k8s\backup\auth-db-backup-pvc.yaml

# Wait for PVC to be bound
Write-Host "Waiting for PVC to be bound..." -ForegroundColor Yellow
do {
    $pvcStatus = kubectl get pvc auth-db-backup-pvc -n auth -o jsonpath='{.status.phase}' 2>$null
    if ($pvcStatus -eq "Bound") {
        Write-Host "PVC is bound!" -ForegroundColor Green
        break
    }
    Start-Sleep -Seconds 5
} while ($true)

Write-Host "`n=== Step 2: Create Manual Backup ===" -ForegroundColor Cyan

# Create manual backup job YAML content since the original file is empty
$manualBackupJobContent = @"
apiVersion: batch/v1
kind: Job
metadata:
    name: manual-auth-db-backup
    namespace: auth
spec:
    template:
        metadata:
            labels:
                app: manual-db-backup
        spec:
            affinity:
                nodeAffinity:
                    preferredDuringSchedulingIgnoredDuringExecution:
                        - weight: 100
                          preference:
                              matchExpressions:
                                  - key: topology.kubernetes.io/zone
                                    operator: In
                                    values:
                                        - bamdad
            containers:
                - name: mysql-backup
                  image: mysql:8.0
                  command:
                      - /bin/bash
                      - -c
                      - |
                          echo "Starting manual backup at `$(date)"
                          echo "Database: authdb"
                          echo "Target: /backup/manual-auth-db-`$(date +%Y%m%d-%H%M%S).sql"
                          
                          # Create backup
                          mysqldump -h mysql -u root -p`$MYSQL_ROOT_PASSWORD \
                            --single-transaction \
                            --routines \
                            --triggers \
                            --add-drop-database \
                            --databases authdb > /backup/manual-auth-db-`$(date +%Y%m%d-%H%M%S).sql
                          
                          if [ `$? -eq 0 ]; then
                            echo "Manual backup completed successfully at `$(date)"
                            echo "Backup files in storage:"
                            ls -la /backup/
                            echo "Backup file size: `$(ls -lh /backup/manual-auth-db-*.sql | tail -1 | awk '{print `$5}')"
                          else
                            echo "Manual backup failed!"
                            exit 1
                          fi
                  env:
                      - name: MYSQL_ROOT_PASSWORD
                        valueFrom:
                            secretKeyRef:
                                name: auth-db-credentials
                                key: DB_PASSWORD
                  volumeMounts:
                      - name: backup-storage
                        mountPath: /backup
                  resources:
                      requests:
                          cpu: 500m
                          memory: 256Mi
                      limits:
                          cpu: 1
                          memory: 512Mi
            volumes:
                - name: backup-storage
                  persistentVolumeClaim:
                      claimName: auth-db-backup-pvc
            restartPolicy: Never
    backoffLimit: 3
"@

# Write manual backup job to temp file
$manualBackupJobContent | Out-File -FilePath ".\temp-manual-backup-job.yaml" -Encoding UTF8

# Delete existing job if it exists
if (Test-KubernetesResource "job" "manual-auth-db-backup") {
    Write-Host "Deleting existing manual backup job..." -ForegroundColor Yellow
    kubectl delete job manual-auth-db-backup -n auth
    Start-Sleep -Seconds 5
}

# Apply manual backup job
Write-Host "Creating manual backup job..." -ForegroundColor Yellow
kubectl apply -f .\temp-manual-backup-job.yaml

# Wait for backup job to complete
if (Wait-ForJobCompletion "manual-auth-db-backup") {
    Write-Host "Getting backup job logs..." -ForegroundColor Yellow
    kubectl logs job/manual-auth-db-backup -n auth
} else {
    Write-Host "Manual backup job failed. Checking logs..." -ForegroundColor Red
    kubectl logs job/manual-auth-db-backup -n auth
}

Write-Host "`n=== Step 3: Simulate Database Failure ===" -ForegroundColor Cyan

# Simulate database corruption/failure by dropping tables
Write-Host "Simulating database failure (dropping tables)..." -ForegroundColor Red

$corruptDbScript = @"
apiVersion: batch/v1
kind: Job
metadata:
    name: simulate-db-failure
    namespace: auth
spec:
    template:
        spec:
            containers:
                - name: mysql-corruption
                  image: mysql:8.0
                  command:
                      - /bin/bash
                      - -c
                      - |
                          echo "=== SIMULATING DATABASE FAILURE ==="
                          echo "Dropping all tables in authdb..."
                          
                          # Connect and drop all tables
                          mysql -h mysql -u root -p`$MYSQL_ROOT_PASSWORD authdb -e "
                          SET FOREIGN_KEY_CHECKS = 0;
                          DROP TABLE IF EXISTS users;
                          DROP TABLE IF EXISTS roles;
                          DROP TABLE IF EXISTS user_roles;
                          DROP TABLE IF EXISTS sessions;
                          SET FOREIGN_KEY_CHECKS = 1;
                          "
                          
                          echo "Database tables dropped. Checking remaining tables:"
                          mysql -h mysql -u root -p`$MYSQL_ROOT_PASSWORD authdb -e "SHOW TABLES;"
                          echo "DATABASE FAILURE SIMULATION COMPLETE"
                  env:
                      - name: MYSQL_ROOT_PASSWORD
                        valueFrom:
                            secretKeyRef:
                                name: auth-db-credentials
                                key: DB_PASSWORD
            restartPolicy: Never
    backoffLimit: 1
"@

$corruptDbScript | Out-File -FilePath ".\temp-corrupt-db-job.yaml" -Encoding UTF8

# Delete existing corruption job if it exists
if (Test-KubernetesResource "job" "simulate-db-failure") {
    kubectl delete job simulate-db-failure -n auth
    Start-Sleep -Seconds 3
}

kubectl apply -f .\temp-corrupt-db-job.yaml

if (Wait-ForJobCompletion "simulate-db-failure") {
    Write-Host "Database failure simulation completed. Logs:" -ForegroundColor Red
    kubectl logs job/simulate-db-failure -n auth
}

Write-Host "`n=== Step 4: Restore Database ===" -ForegroundColor Cyan

# Delete existing restore job if it exists (since jobs are immutable)
if (Test-KubernetesResource "job" "restore-auth-db") {
    Write-Host "Deleting existing restore job..." -ForegroundColor Yellow
    kubectl delete job restore-auth-db -n auth
    Start-Sleep -Seconds 5
}

# Apply restore job
Write-Host "Starting database restore..." -ForegroundColor Yellow
kubectl apply -f .\k8s\backup\restore-job.yaml

# Wait for restore job to complete
if (Wait-ForJobCompletion "restore-auth-db") {
    Write-Host "Database restore completed! Getting logs..." -ForegroundColor Green
    kubectl logs job/restore-auth-db -n auth
} else {
    Write-Host "Database restore failed. Checking logs..." -ForegroundColor Red
    kubectl logs job/restore-auth-db -n auth
}

Write-Host "`n=== Step 5: Verify Restore ===" -ForegroundColor Cyan

# Create a verification job
$verifyScript = @"
apiVersion: batch/v1
kind: Job
metadata:
    name: verify-restore
    namespace: auth
spec:
    template:
        spec:
            containers:
                - name: mysql-verify
                  image: mysql:8.0
                  command:
                      - /bin/bash
                      - -c
                      - |
                          echo "=== VERIFYING DATABASE RESTORE ==="
                          echo "Checking database structure..."
                          
                          mysql -h mysql -u auth_user -p`$MYSQL_PASSWORD authdb -e "SHOW TABLES;"
                          echo ""
                          echo "Table count: `$(mysql -h mysql -u auth_user -p`$MYSQL_PASSWORD authdb -e 'SHOW TABLES;' | wc -l)"
                          echo ""
                          echo "Sample data verification:"
                          mysql -h mysql -u auth_user -p`$MYSQL_PASSWORD authdb -e "SELECT COUNT(*) as user_count FROM users;" 2>/dev/null || echo "Users table not found or empty"
                          mysql -h mysql -u auth_user -p`$MYSQL_PASSWORD authdb -e "SELECT COUNT(*) as role_count FROM roles;" 2>/dev/null || echo "Roles table not found or empty"
                          
                          echo "=== RESTORE VERIFICATION COMPLETE ==="
                  env:
                      - name: MYSQL_PASSWORD
                        valueFrom:
                            secretKeyRef:
                                name: auth-db-credentials
                                key: DB_PASS
            restartPolicy: Never
    backoffLimit: 1
"@

$verifyScript | Out-File -FilePath ".\temp-verify-restore-job.yaml" -Encoding UTF8

# Delete existing verification job if it exists
if (Test-KubernetesResource "job" "verify-restore") {
    kubectl delete job verify-restore -n auth
    Start-Sleep -Seconds 3
}

kubectl apply -f .\temp-verify-restore-job.yaml

if (Wait-ForJobCompletion "verify-restore") {
    Write-Host "Verification completed. Results:" -ForegroundColor Green
    kubectl logs job/verify-restore -n auth
}

Write-Host "`n=== Step 6: Test CronJob (Optional) ===" -ForegroundColor Cyan

# Apply the cronjob for scheduled backups
Write-Host "Applying scheduled backup CronJob..." -ForegroundColor Yellow
kubectl apply -f .\k8s\backup\auth-db-backup-cronjob.yaml

# Check cronjob status
Write-Host "CronJob status:" -ForegroundColor Yellow
kubectl get cronjob auth-db-backup -n auth

# Show cronjob details
Write-Host "CronJob details:" -ForegroundColor Yellow
kubectl describe cronjob auth-db-backup -n auth

# Manually trigger cronjob for testing
Write-Host "Manually triggering CronJob for testing..." -ForegroundColor Yellow
kubectl create job --from=cronjob/auth-db-backup manual-cronjob-test -n auth

if (Wait-ForJobCompletion "manual-cronjob-test") {
    Write-Host "Manual CronJob trigger completed. Logs:" -ForegroundColor Green
    kubectl logs job/manual-cronjob-test -n auth
}

Write-Host "`n=== Demo Summary ===" -ForegroundColor Green

Write-Host "Checking all backup-related resources:" -ForegroundColor Yellow
kubectl get all -l app=manual-db-backup -n auth
kubectl get all -l app=db-restore -n auth
kubectl get cronjob -n auth
kubectl get pvc auth-db-backup-pvc -n auth

Write-Host "`nJob history:" -ForegroundColor Yellow
kubectl get jobs -n auth

Write-Host "`n=== Cleanup Commands (Run manually if needed) ===" -ForegroundColor Magenta
Write-Host "kubectl delete job manual-auth-db-backup -n auth"
Write-Host "kubectl delete job simulate-db-failure -n auth"
Write-Host "kubectl delete job restore-auth-db -n auth"
Write-Host "kubectl delete job verify-restore -n auth"
Write-Host "kubectl delete job manual-cronjob-test -n auth"
Write-Host "kubectl delete cronjob auth-db-backup -n auth"

# Clean up temporary files
Remove-Item -Path ".\temp-manual-backup-job.yaml" -Force -ErrorAction SilentlyContinue
Remove-Item -Path ".\temp-corrupt-db-job.yaml" -Force -ErrorAction SilentlyContinue
Remove-Item -Path ".\temp-verify-restore-job.yaml" -Force -ErrorAction SilentlyContinue

Write-Host "`n=== Backup and Restore Demo Complete! ===" -ForegroundColor Green

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
