# Phase 5 Kubernetes Configuration Files Structure

## Directory Structure

```
k8s/
├── auth/
│   ├── auth-namespace.yaml
│   ├── auth-configmap.yaml
│   ├── auth-secret.yaml
│   ├── auth-db-credentials.yaml
│   ├── mysql-pvc.yaml
│   ├── mysql-deployment.yaml
│   ├── mysql-service.yaml
│   ├── auth-deployment.yaml
│   ├── auth-service-http.yaml
│   └── auth-service-grpc.yaml
│
├── core/
│   ├── core-namespace.yaml
│   ├── core-configmap.yaml
│   ├── core-secret.yaml
│   ├── core-activemq-credentials.yaml
│   ├── core-db-credentials.yaml
│   ├── postgres-pvc.yaml
│   ├── postgres-deployment.yaml
│   ├── postgres-service.yaml
│   ├── activemq-pvc.yaml
│   ├── activemq-deployment.yaml
│   ├── activemq-service.yaml
│   ├── core-deployment.yaml
│   └── core-service.yaml
│
├── backup/
│   ├── backup-storage-class.yaml         # ArvanCloud storage class for backups
│   ├── auth-db-backup-pvc.yaml          # Persistent volume claim for backup storage
│   ├── auth-db-backup-cronjob.yaml      # Automated daily backup job
│   └── auth-db-backup.yaml              # Reference file (broken down)
│
├── ingress/
│   ├── ingress-nginx-namespace.yaml     # Namespace for ingress controller
│   ├── nginx-configuration.yaml         # Nginx controller configuration
│   ├── tcp-services.yaml                # TCP services configuration
│   ├── udp-services.yaml                # UDP services configuration  
│   ├── nginx-ingress-controller-deployment.yaml  # Ingress controller deployment
│   ├── ingress-nginx-service.yaml       # Ingress controller service
│   ├── microservices-ingress.yaml       # Application routing rules
│   └── nginx-ingress-controller.yaml    # Reference file (broken down)
│
├── monitoring/
│   ├── health-configmap.yaml            # Health service nginx configuration
│   ├── health-deployment.yaml           # Health service deployment
│   ├── health-service-svc.yaml          # Health service ClusterIP service
│   └── health-service.yaml              # Reference file (broken down)
│
└── hpa/
    ├── hpa-auth-service.yaml             # Auth service auto-scaling
    ├── hpa-core-service.yaml             # Core service auto-scaling
    └── hpa-manage-service.yaml           # Manage service auto-scaling
```

## Deployment Order

### 1. Storage & Infrastructure

```powershell
kubectl apply -f k8s/backup/backup-storage-class.yaml
kubectl apply -f k8s/backup/auth-db-backup-pvc.yaml
kubectl apply -f k8s/backup/auth-db-backup-cronjob.yaml
```

### 2. Core Services

```powershell
kubectl apply -f k8s/auth/
kubectl apply -f k8s/core/
```

### 3. Monitoring

```powershell
kubectl apply -f k8s/monitoring/health-configmap.yaml
kubectl apply -f k8s/monitoring/health-deployment.yaml  
kubectl apply -f k8s/monitoring/health-service-svc.yaml
```

### 4. Ingress Controller

```powershell
kubectl apply -f k8s/ingress/ingress-nginx-namespace.yaml
kubectl apply -f k8s/ingress/nginx-configuration.yaml
kubectl apply -f k8s/ingress/tcp-services.yaml
kubectl apply -f k8s/ingress/udp-services.yaml
kubectl apply -f k8s/ingress/nginx-ingress-controller-deployment.yaml
kubectl apply -f k8s/ingress/ingress-nginx-service.yaml
```

### 5. Application Routing

```powershell
kubectl apply -f k8s/ingress/microservices-ingress.yaml
```

### 6. Auto-Scaling

```powershell
kubectl apply -f k8s/hpa/hpa-auth-service.yaml
kubectl apply -f k8s/hpa/hpa-core-service.yaml
kubectl apply -f k8s/hpa/hpa-manage-service.yaml
```

## Benefits of This Structure

- **🔧 Modular**: Each Kubernetes resource has its own file
- **📋 Maintainable**: Easy to modify individual components
- **🔄 Reusable**: Components can be applied independently
- **🐛 Debuggable**: Easier to troubleshoot specific resources
- **📚 Organized**: Clear separation of concerns
- **🚀 Scalable**: Easy to add new components

## Quick Commands

```powershell
# Deploy everything
.\deploy-phase5.ps1

# Deploy specific component
kubectl apply -f k8s/monitoring/health-deployment.yaml

# Update only HPA
kubectl apply -f k8s/hpa/

# Restart ingress controller
kubectl rollout restart deployment/nginx-ingress-controller -n ingress-nginx
```
