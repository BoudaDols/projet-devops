#!/bin/bash
set -e

cd "$(dirname "$0")"

# Import a resource only if it's not already in state
import_if_missing() {
  local resource=$1
  local id=$2

  if terraform state show "$resource" > /dev/null 2>&1; then
    echo "  SKIP $resource (already in state)"
  else
    echo "  IMPORT $resource"
    terraform import "$resource" "$id"
  fi
}

echo "==> Importing Kubernetes resources into Terraform state..."

import_if_missing module.k8s_apps.kubernetes_secret.api_gateway              default/api-gateway-secret
import_if_missing module.k8s_apps.kubernetes_secret.abonnement               default/abonnement-secrets
import_if_missing module.k8s_apps.kubernetes_secret.mysql                    default/mysql-secrets
import_if_missing module.k8s_apps.kubernetes_config_map.api_gateway          default/api-gateway-config
import_if_missing module.k8s_apps.kubernetes_config_map.abonnement           default/abonnement-config
import_if_missing module.k8s_apps.kubernetes_service.api_gateway             default/api-gateway-service
import_if_missing module.k8s_apps.kubernetes_service.abonnement              default/abonnement
import_if_missing module.k8s_apps.kubernetes_service.api_gateway_mysql       default/api-gateway-mysql-service
import_if_missing module.k8s_apps.kubernetes_service.abonnement_mysql        default/mysql
import_if_missing module.k8s_apps.kubernetes_persistent_volume_claim.api_gateway_mysql  default/api-gateway-mysql-pvc
import_if_missing module.k8s_apps.kubernetes_persistent_volume_claim.abonnement_mysql   default/mysql-pvc
import_if_missing module.k8s_apps.kubernetes_network_policy.abonnement       default/abonnement-network-policy
import_if_missing module.k8s_apps.kubernetes_network_policy.abonnement_mysql default/mysql-network-policy
import_if_missing module.k8s_apps.kubernetes_deployment.api_gateway_mysql   default/api-gateway-mysql
import_if_missing module.k8s_apps.kubernetes_deployment.abonnement_mysql    default/mysql
import_if_missing module.k8s_apps.kubernetes_deployment.api_gateway         default/api-gateway
import_if_missing module.k8s_apps.kubernetes_deployment.abonnement          default/abonnement
import_if_missing module.k8s_apps.kubernetes_deployment.api_gateway_mysql   default/api-gateway-mysql
import_if_missing module.k8s_apps.kubernetes_deployment.abonnement_mysql    default/mysql


echo ""
echo "==> All resources imported. Run 'terraform apply' to reconcile state."
