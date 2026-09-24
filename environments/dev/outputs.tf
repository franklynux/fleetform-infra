output "hub_cluster_name" {
  value       = module.hub_eks.cluster_name
  description = "Name of Hub Cluster"
}

output "hub_cluster_endpoint" {
  value       = module.hub_eks.cluster_endpoint
  description = "Hub cluster API endpoint"
}

output "hub_cluster_certificate_authority_data" {
  value       = module.hub_eks.cluster_certificate_authority_data
  description = "Hub cluster CA data for kubeconfig"
  sensitive   = true
}

output "spoke_cluster_name" {
  value       = module.spoke_eks.cluster_name
  description = "Name of Spoke Cluster"
}

output "spoke_cluster_endpoint" {
  value       = module.spoke_eks.cluster_endpoint
  description = "Spoke cluster API endpoint — used by Argo CD to register spoke"
}

output "spoke_cluster_certificate_authority_data" {
  value       = module.spoke_eks.cluster_certificate_authority_data
  description = "Spoke cluster CA data for Argo CD cluster secret"
  sensitive   = true
}
