output "API_Gateway_invoke_URL" {
    description = "The invoke URL from the API-Gateway"
    value       = "https://${aws_api_gateway_rest_api.SLW_API_terraform.id}.execute-api.${var.myregion}.amazonaws.com"
}