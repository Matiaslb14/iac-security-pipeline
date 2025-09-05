plugin "aws" {
  enabled = true
  version = "0.34.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

config {
  format = "default"
  force  = false
}

rule "terraform_required_version" {
  enabled = true
}
