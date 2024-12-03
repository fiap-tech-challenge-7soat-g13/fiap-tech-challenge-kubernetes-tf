data "aws_lb" "default" {
  tags = {
    "kubernetes.io/service-name" = "istio-ingress/istio-ingressgateway"
  }
}
resource "aws_api_gateway_vpc_link" "default" {
  name        = "default"
  target_arns = [data.aws_lb.default.arn]
}
resource "aws_api_gateway_rest_api" "default" {
  name = "default"
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}
resource "aws_api_gateway_resource" "default" {
  rest_api_id = aws_api_gateway_rest_api.default.id
  parent_id   = aws_api_gateway_rest_api.default.root_resource_id
  path_part   = "{proxy+}"
}
resource "aws_api_gateway_method" "default" {
  rest_api_id   = aws_api_gateway_rest_api.default.id
  resource_id   = aws_api_gateway_resource.default.id
  http_method   = "ANY"
  authorization = "NONE"
  request_parameters = {
    "method.request.path.proxy" = true
  }
}
resource "aws_api_gateway_integration" "default" {
  rest_api_id             = aws_api_gateway_rest_api.default.id
  resource_id             = aws_api_gateway_resource.default.id
  http_method             = "ANY"
  integration_http_method = "ANY"
  type                    = "HTTP_PROXY"
  uri                     = "http://${data.aws_lb.default.dns_name}/{proxy}"
  passthrough_behavior    = "WHEN_NO_MATCH"
  content_handling        = "CONVERT_TO_TEXT"
  request_parameters = {
    "integration.request.path.proxy"    = "method.request.path.proxy"
    "integration.request.header.Accept" = "'application/json'"
  }
  connection_type = "VPC_LINK"
  connection_id   = aws_api_gateway_vpc_link.default.id
}
resource "aws_api_gateway_deployment" "default" {
  rest_api_id = aws_api_gateway_rest_api.default.id
  depends_on = [
    aws_api_gateway_integration.default
  ]
}
resource "aws_api_gateway_stage" "default" {
  deployment_id = aws_api_gateway_deployment.default.id
  rest_api_id   = aws_api_gateway_rest_api.default.id
  stage_name    = "dev"
}