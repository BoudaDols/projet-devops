output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_ca" {
  description = "EKS cluster certificate authority data"
  value       = module.eks.cluster_certificate_authority_data
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "frontend_s3_bucket" {
  description = "S3 bucket name for frontend deployment"
  value       = module.frontend.s3_bucket_name
}

output "frontend_cloudfront_id" {
  description = "CloudFront distribution ID (needed for cache invalidation in CI)"
  value       = module.frontend.cloudfront_distribution_id
}

output "frontend_url" {
  description = "Frontend URL (update CORS_ALLOWED_ORIGINS in api-gateway configmap with this)"
  value       = module.frontend.frontend_url
}
