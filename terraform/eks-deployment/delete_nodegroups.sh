#!/bin/bash

# Configuration
CLUSTER_NAME="order-system-cluster"
TARGET_NODE="ip-172-2-3-173.ec2.internal"

# Get all nodegroups
echo "Getting list of nodegroups..."
NODEGROUPS=($(aws eks list-nodegroups --cluster-name "$CLUSTER_NAME" --query 'nodegroups[]' --output text))

if [ ${#NODEGROUPS[@]} -eq 0 ]; then
    echo "No nodegroups found for cluster $CLUSTER_NAME"
    exit 1
fi

echo "Found nodegroups: ${NODEGROUPS[*]}"

# Find which nodegroup contains the target node using kubectl
echo "Finding nodegroup for node $TARGET_NODE..."
TARGET_NODEGROUP=""

# Get the nodegroup label from the node directly
NODE_LABELS=$(kubectl get node "$TARGET_NODE" -o json 2>/dev/null)

if [ $? -ne 0 ]; then
    echo "❌ Could not find node $TARGET_NODE in the cluster"
    echo "Available nodes:"
    kubectl get nodes
    exit 1
fi

# Extract nodegroup name from labels
TARGET_NODEGROUP=$(echo "$NODE_LABELS" | jq -r '.metadata.labels["eks.amazonaws.com/nodegroup"] // .metadata.labels["alpha.eksctl.io/nodegroup-name"] // empty')

if [ -z "$TARGET_NODEGROUP" ] || [ "$TARGET_NODEGROUP" = "null" ]; then
    echo "❌ Could not determine nodegroup for node $TARGET_NODE"
    echo "Node labels:"
    kubectl get node "$TARGET_NODE" --show-labels
    exit 1
fi

echo "✅ Found target node in nodegroup: $TARGET_NODEGROUP"

# Verify this nodegroup exists in our list
if [[ ! " ${NODEGROUPS[@]} " =~ " ${TARGET_NODEGROUP} " ]]; then
    echo "❌ Nodegroup $TARGET_NODEGROUP not found in cluster nodegroups list"
    echo "Available nodegroups: ${NODEGROUPS[*]}"
    exit 1
fi

echo "🎯 Will keep nodegroup: $TARGET_NODEGROUP"
echo "🗑️  Will delete nodegroups:"

# Show which nodegroups will be deleted
NODEGROUPS_TO_DELETE=()
for ng in "${NODEGROUPS[@]}"; do
    if [ "$ng" != "$TARGET_NODEGROUP" ]; then
        # Check if nodegroup has any instances before adding to delete list
        INSTANCE_COUNT=$(aws eks describe-nodegroup --cluster-name "$CLUSTER_NAME" --nodegroup-name "$ng" \
                        --query 'length(nodegroup.instances[])' --output text 2>/dev/null)
        
        if [ "$INSTANCE_COUNT" = "0" ] || [ "$INSTANCE_COUNT" = "None" ]; then
            echo "   - $ng (empty - safe to delete)"
        else
            echo "   - $ng ($INSTANCE_COUNT instances)"
        fi
        NODEGROUPS_TO_DELETE+=("$ng")
    fi
done

if [ ${#NODEGROUPS_TO_DELETE[@]} -eq 0 ]; then
    echo "No nodegroups to delete. Only one nodegroup exists: $TARGET_NODEGROUP"
    exit 0
fi

# Confirm before deletion
echo ""
read -p "Are you sure you want to delete ${#NODEGROUPS_TO_DELETE[@]} nodegroups? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Deletion cancelled."
    exit 0
fi

# Delete nodegroups one by one
for ng in "${NODEGROUPS_TO_DELETE[@]}"; do
    echo "🗑️  Deleting nodegroup: $ng"
    
    aws eks delete-nodegroup --cluster-name "$CLUSTER_NAME" --nodegroup-name "$ng"
    
    if [ $? -eq 0 ]; then
        echo "✅ Initiated deletion of $ng"
        
        # Wait for deletion to complete before moving to next one
        echo "⏳ Waiting for $ng to be deleted..."
        while true; do
            STATUS=$(aws eks describe-nodegroup --cluster-name "$CLUSTER_NAME" --nodegroup-name "$ng" \
                    --query 'nodegroup.status' --output text 2>/dev/null)
            
            if [ $? -ne 0 ]; then
                echo "✅ Nodegroup $ng has been deleted"
                break
            fi
            
            echo "   Status: $STATUS - waiting..."
            sleep 30
        done
    else
        echo "❌ Failed to delete nodegroup: $ng"
        echo "Stopping deletion process for safety."
        exit 1
    fi
    
    # Verify your app is still running after each deletion
    echo "🔍 Checking if order-service is still running..."
    kubectl get pods -n order-service --no-headers | grep -E "(Running|Pending)" > /dev/null
    
    if [ $? -eq 0 ]; then
        echo "✅ Order-service pods are still healthy"
    else
        echo "⚠️  Warning: Order-service pods may have issues. Check with: kubectl get pods -n order-service"
    fi
    
    echo "---"
done

echo "🎉 Cleanup complete!"
echo "Remaining nodegroup: $TARGET_NODEGROUP"
echo ""
echo "Final verification:"
aws eks list-nodegroups --cluster-name "$CLUSTER_NAME"
kubectl get pods -n order-service
