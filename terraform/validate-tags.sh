#!/bin/bash

# Script to validate consistent tagging across Terraform files
echo "🏷️  Validating Terraform tags..."

# Check for any remaining uppercase "Project" tags
echo "Checking for uppercase 'Project' tags..."
UPPERCASE_COUNT=$(grep -r "Project.*=" terraform/ --include="*.tf" | wc -l)
if [ $UPPERCASE_COUNT -gt 0 ]; then
    echo "❌ Found $UPPERCASE_COUNT uppercase 'Project' tags:"
    grep -r "Project.*=" terraform/ --include="*.tf"
    echo ""
else
    echo "✅ No uppercase 'Project' tags found"
fi

# Check for consistent project value
echo "Checking for consistent project values..."
NON_ORDER_SYSTEM=$(grep -r "project.*=" terraform/ --include="*.tf" | grep -v "order-system" | wc -l)
if [ $NON_ORDER_SYSTEM -gt 0 ]; then
    echo "❌ Found $NON_ORDER_SYSTEM inconsistent project values:"
    grep -r "project.*=" terraform/ --include="*.tf" | grep -v "order-system"
    echo ""
else
    echo "✅ All project tags use 'order-system'"
fi

# Count total project tags
TOTAL_TAGS=$(grep -r "project.*=.*order-system" terraform/ --include="*.tf" | wc -l)
echo "📊 Total project tags found: $TOTAL_TAGS"

# Show summary by environment
echo ""
echo "📋 Tags by environment:"
echo "Development tags:"
grep -r "Environment.*=.*dev" terraform/ --include="*.tf" | wc -l | xargs echo "  "
echo "Production tags:"
grep -r "Environment.*=.*production" terraform/ --include="*.tf" | wc -l | xargs echo "  "

echo ""
echo "🎉 Tag validation complete!"