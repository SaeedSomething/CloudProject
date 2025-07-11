#!/bin/bash

# Phase 5 Step 2: Auth Database Backup & Restore Demonstration
# This script demonstrates database backup and restore on ArvanCloud

echo "========================================="
echo "Phase 5 Step 2: Database Backup & Restore"
echo "========================================="

# Set variables
NAMESPACE="auth"
BACKUP_FILE="auth-backup-$(date +%Y%m%d-%H%M%S).sql"
DB_NAME="authdb"

# Function to get MySQL pod name
get_mysql_pod() {
    kubectl get pods -n $NAMESPACE -l app=mysql -o jsonpath='{.items[0].metadata.name}'
}

# Function to check MySQL connectivity
check_mysql() {
    local pod_name=$1
    kubectl exec -n $NAMESPACE $pod_name -- mysql -u root -pauth_pass -e "SELECT 1;" > /dev/null 2>&1
    return $?
}

echo "Step 1: Checking MySQL connectivity..."
MYSQL_POD=$(get_mysql_pod)

if [ -z "$MYSQL_POD" ]; then
    echo "ERROR: MySQL pod not found!"
    exit 1
fi

echo "Found MySQL pod: $MYSQL_POD"

if ! check_mysql $MYSQL_POD; then
    echo "ERROR: Cannot connect to MySQL!"
    exit 1
fi

echo "✅ MySQL connection successful"

echo ""
echo "Step 2: Creating database backup..."
echo "Backup file: $BACKUP_FILE"

# Create backup
kubectl exec -n $NAMESPACE $MYSQL_POD -- mysqldump -u root -pauth_pass --single-transaction --routines --triggers $DB_NAME > $BACKUP_FILE

if [ $? -eq 0 ]; then
    echo "✅ Backup created successfully: $BACKUP_FILE"
    echo "Backup size: $(du -h $BACKUP_FILE | cut -f1)"
else
    echo "❌ Backup failed!"
    exit 1
fi

echo ""
echo "Step 3: Demonstrating database deletion..."
echo "WARNING: About to delete database '$DB_NAME' for demonstration"
read -p "Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Operation cancelled"
    exit 1
fi

# Drop database
kubectl exec -n $NAMESPACE $MYSQL_POD -- mysql -u root -pauth_pass -e "DROP DATABASE $DB_NAME;"

if [ $? -eq 0 ]; then
    echo "✅ Database '$DB_NAME' deleted successfully"
else
    echo "❌ Database deletion failed!"
    exit 1
fi

# Verify deletion
echo "Verifying database deletion..."
kubectl exec -n $NAMESPACE $MYSQL_POD -- mysql -u root -pauth_pass -e "SHOW DATABASES;" | grep $DB_NAME
if [ $? -ne 0 ]; then
    echo "✅ Database deletion confirmed"
else
    echo "❌ Database still exists!"
    exit 1
fi

echo ""
echo "Step 4: Recreating database..."

# Recreate database
kubectl exec -n $NAMESPACE $MYSQL_POD -- mysql -u root -pauth_pass -e "CREATE DATABASE $DB_NAME;"

if [ $? -eq 0 ]; then
    echo "✅ Database '$DB_NAME' recreated successfully"
else
    echo "❌ Database recreation failed!"
    exit 1
fi

echo ""
echo "Step 5: Restoring data from backup..."

# Restore from backup
kubectl exec -i -n $NAMESPACE $MYSQL_POD -- mysql -u root -pauth_pass $DB_NAME < $BACKUP_FILE

if [ $? -eq 0 ]; then
    echo "✅ Database restored successfully from $BACKUP_FILE"
else
    echo "❌ Database restore failed!"
    exit 1
fi

echo ""
echo "Step 6: Verification..."

# Verify restore
TABLE_COUNT=$(kubectl exec -n $NAMESPACE $MYSQL_POD -- mysql -u root -pauth_pass -e "USE $DB_NAME; SHOW TABLES;" | wc -l)
echo "Tables found in restored database: $((TABLE_COUNT - 1))"

if [ $TABLE_COUNT -gt 1 ]; then
    echo "✅ Database restore verification successful"
    
    # Show some data to prove it's working
    echo ""
    echo "Sample data from restored database:"
    kubectl exec -n $NAMESPACE $MYSQL_POD -- mysql -u root -pauth_pass -e "USE $DB_NAME; SHOW TABLES; SELECT COUNT(*) as 'Total Records' FROM users;" 2>/dev/null || echo "Note: users table might not exist yet"
else
    echo "❌ Database restore verification failed"
    exit 1
fi

echo ""
echo "========================================="
echo "✅ Phase 5 Step 2 Completed Successfully!"
echo "========================================="
echo "Summary:"
echo "- ✅ Database backup created: $BACKUP_FILE"
echo "- ✅ Original database deleted"
echo "- ✅ Database recreated"
echo "- ✅ Data restored from backup"
echo "- ✅ Restoration verified"
echo ""
echo "Backup file saved as: $BACKUP_FILE"
echo "Keep this file for future use!"
echo ""
