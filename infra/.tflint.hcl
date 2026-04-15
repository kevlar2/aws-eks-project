plugin "aws" {
  enabled = true
  version = "0.47.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

# Enforce variable best practices
rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_typed_variables" {
  enabled = true
}

rule "terraform_unused_declarations" {
  enabled = true
}

# Enforce required tags on AWS resources
rule "aws_resource_missing_tags" {
  enabled = true
  tags    = ["Environment"]
}
