plugin "aws" {
  enabled = true
  version = "0.31.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

config {
  format = "default"
  module = true
  force  = false
}

rule "terraform_required_version" {
  enabled = true
}
