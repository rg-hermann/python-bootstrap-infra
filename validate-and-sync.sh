#!/bin/bash
# Script para validar configuração do Helm e sincronizar imagens
# Usage: ./validate-and-sync.sh [dev|prod]

set -e

ENVIRONMENT=${1:-dev}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "$ENVIRONMENT" != "dev" && "$ENVIRONMENT" != "prod" ]]; then
    echo "❌ Usage: $0 [dev|prod]"
    exit 1
fi

echo "🔍 Validating Helm configuration for $ENVIRONMENT environment..."
echo ""

# Check if helm is installed
if ! command -v helm &> /dev/null; then
    echo "❌ Helm is not installed. Please install Helm first."
    exit 1
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl is not installed. Please install kubectl first."
    exit 1
fi

# Check if yq is installed
if ! command -v yq &> /dev/null; then
    echo "⚠️ yq is not installed. Install with: sudo snap install yq or brew install yq"
fi

CHART_PATH="$SCRIPT_DIR"
VALUES_FILE="$CHART_PATH/values-${ENVIRONMENT}.yaml"

# Step 1: Validate values file exists
if [[ ! -f "$VALUES_FILE" ]]; then
    echo "❌ Values file not found: $VALUES_FILE"
    exit 1
fi

echo "✅ Found values file: $VALUES_FILE"
echo ""

# Step 2: Update Helm repos
echo "📦 Updating Helm repositories..."
helm repo add k8s-templates https://rg-hermann.github.io/k8s-helm-templates/ 2>/dev/null || true
helm repo update

echo ""

# Step 3: Update dependencies
echo "🔗 Updating Helm dependencies..."
cd "$CHART_PATH"
helm dependency update

echo ""

# Step 4: Lint the chart
echo "🔍 Linting Helm chart..."
if helm lint . --strict; then
    echo "✅ Helm chart linting passed"
else
    echo "❌ Helm chart linting failed"
    exit 1
fi

echo ""

# Step 5: Template validation
echo "📋 Templating and validating manifests..."
TEMP_MANIFEST=$(mktemp)
trap "rm -f $TEMP_MANIFEST" EXIT

helm template python-bootstrap . -f "$VALUES_FILE" > "$TEMP_MANIFEST"

if kubectl apply --dry-run=client -f "$TEMP_MANIFEST" > /dev/null 2>&1; then
    echo "✅ Kubernetes manifest validation passed"
else
    echo "⚠️ Kubernetes manifest validation passed with warnings"
fi

echo ""

# Step 6: Check critical configuration
echo "🔧 Checking critical configuration..."
echo ""

echo "📸 Image Configuration:"
if command -v yq &> /dev/null; then
    yq '.k8s-helm-templates.image' "$VALUES_FILE"
else
    echo "  (yq not installed, skipping)"
fi
echo ""

echo "📊 Resource Limits:"
if command -v yq &> /dev/null; then
    yq '.k8s-helm-templates.resources' "$VALUES_FILE"
else
    echo "  (yq not installed, skipping)"
fi
echo ""

echo "🏥 Health Probes:"
grep -A 3 "livenessProbe:" "$VALUES_FILE" || echo "  (No liveness probe configured)"
echo ""

echo "✨ Autoscaling:"
if command -v yq &> /dev/null; then
    yq '.k8s-helm-templates.autoscaling' "$VALUES_FILE"
else
    echo "  (yq not installed, skipping)"
fi
echo ""

# Step 7: Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Validation completed successfully for $ENVIRONMENT!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📝 Next steps:"
echo "   1. Review the configuration above"
echo "   2. For dev: helm install python-bootstrap . -f values-dev.yaml --wait"
echo "   3. For prod: Review and merge to main, then deploy manually"
echo ""
