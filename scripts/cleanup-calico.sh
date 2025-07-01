#!/bin/bash
# Calico Complete Cleanup Script

set -e

echo "🧹 Starting Calico complete cleanup..."

# Function to force delete resource with finalizer removal
force_delete_resource() {
    local resource_type=$1
    local resource_name=$2
    local namespace=${3:-""}
    
    if [ -n "$namespace" ]; then
        local resource_path="$resource_type/$resource_name -n $namespace"
        local kubectl_path="-n $namespace"
    else
        local resource_path="$resource_type/$resource_name"
        local kubectl_path=""
    fi
    
    echo "Attempting to delete $resource_type/$resource_name..."
    
    # Check if resource exists
    if ! kubectl get $resource_path 2>/dev/null >/dev/null; then
        echo "  ✅ $resource_type/$resource_name does not exist"
        return 0
    fi
    
    # Remove finalizers
    echo "  🔧 Removing finalizers from $resource_type/$resource_name..."
    kubectl patch $resource_type $resource_name $kubectl_path --type='json' -p='[{"op": "replace", "path": "/metadata/finalizers", "value": []}]' 2>/dev/null || true
    
    # Force delete
    echo "  🗑️  Force deleting $resource_type/$resource_name..."
    kubectl delete $resource_type $resource_name $kubectl_path --force --grace-period=0 2>/dev/null || true
    
    # Wait and verify
    for i in {1..30}; do
        if ! kubectl get $resource_path 2>/dev/null >/dev/null; then
            echo "  ✅ $resource_type/$resource_name successfully deleted"
            return 0
        fi
        echo "  ⏳ Waiting for deletion... ($i/30)"
        sleep 2
    done
    
    echo "  ⚠️  $resource_type/$resource_name may still exist"
}

# 1. Delete Installation resources
echo "📋 Deleting Installation resources..."
for installation in $(kubectl get installation --all-namespaces --no-headers 2>/dev/null | awk '{print $2":"$1}' || true); do
    if [ -n "$installation" ]; then
        name=$(echo $installation | cut -d: -f1)
        ns=$(echo $installation | cut -d: -f2)
        if [ "$ns" != "NAME" ]; then
            force_delete_resource "installation" "$name" "$ns"
        fi
    fi
done

# 2. Delete APIServer resources
echo "🔌 Deleting APIServer resources..."
for apiserver in $(kubectl get apiserver --no-headers 2>/dev/null | awk '{print $1}' || true); do
    if [ -n "$apiserver" ] && [ "$apiserver" != "NAME" ]; then
        force_delete_resource "apiserver" "$apiserver"
    fi
done

# 3. Delete pods forcefully
echo "🔄 Deleting Calico/Tigera pods..."
kubectl delete pods -A -l k8s-app=calico-node --force --grace-period=0 2>/dev/null || true
kubectl delete pods -A -l k8s-app=calico-kube-controllers --force --grace-period=0 2>/dev/null || true
kubectl delete pods -A -l k8s-app=tigera-operator --force --grace-period=0 2>/dev/null || true

# 4. Delete other Kubernetes resources
echo "🎛️  Deleting Kubernetes resources..."
kubectl delete daemonset -A -l k8s-app=calico-node --force --grace-period=0 2>/dev/null || true
kubectl delete deployment -A -l k8s-app=calico-kube-controllers --force --grace-period=0 2>/dev/null || true
kubectl delete deployment -A -l k8s-app=tigera-operator --force --grace-period=0 2>/dev/null || true

# 5. Delete namespaces
echo "🏠 Deleting namespaces..."
for ns in calico-system tigera-operator calico-apiserver; do
    if kubectl get namespace "$ns" 2>/dev/null >/dev/null; then
        echo "Deleting namespace $ns..."
        kubectl patch namespace "$ns" --type='json' -p='[{"op": "replace", "path": "/metadata/finalizers", "value": []}]' 2>/dev/null || true
        kubectl delete namespace "$ns" --force --grace-period=0 2>/dev/null || true
    fi
done

# 6. Delete CRDs (careful!)
echo "📊 Deleting CRDs..."
crd_list=$(kubectl get crd --no-headers 2>/dev/null | grep -E "(calico|tigera)" | awk '{print $1}' || true)
for crd in $crd_list; do
    if [ -n "$crd" ]; then
        echo "Deleting CRD $crd..."
        kubectl patch crd "$crd" --type='json' -p='[{"op": "replace", "path": "/metadata/finalizers", "value": []}]' 2>/dev/null || true
        kubectl delete crd "$crd" --force --grace-period=0 2>/dev/null || true
    fi
done

# 7. Wait for cleanup
echo "⏳ Waiting for cleanup completion..."
sleep 10

# 8. Verification
echo "🔍 Verifying cleanup..."
echo "=== Remaining Calico/Tigera resources ==="
kubectl get pods -A 2>/dev/null | grep -E "(calico|tigera)" || echo "✅ No pods found"
kubectl get namespaces 2>/dev/null | grep -E "(calico|tigera)" || echo "✅ No namespaces found"  
kubectl get crd 2>/dev/null | grep -E "(calico|tigera)" || echo "✅ No CRDs found"
kubectl get installation -A 2>/dev/null || echo "✅ No Installation resources found"

echo "🎉 Calico cleanup completed!"
echo "📝 You can now reinstall Calico with a clean state."