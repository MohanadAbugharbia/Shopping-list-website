# Creating an ACM Certificate

resource "aws_acm_certificate" "API_Gateway" {
  domain_name       = "api.abugharbia.com"
  validation_method = "DNS"
}

# Creating a route53 record to validate the certificate

resource "aws_route53_record" "API_Gateway" {
  for_each = {
    for dvo in aws_acm_certificate.API_Gateway.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.abugharbia.id
}

# Certificate validation

resource "aws_acm_certificate_validation" "API_Gateway" {
  certificate_arn         = aws_acm_certificate.API_Gateway.arn
  validation_record_fqdns = [for record in aws_route53_record.API_Gateway : record.fqdn]
}