output "api_gateway_base_url" {
  value = length(module.serverless) > 0 ? module.serverless[0].api_gateway_base_url : null
}