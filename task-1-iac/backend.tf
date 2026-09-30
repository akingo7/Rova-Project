terraform {

  backend "s3" {
    bucket         = "rova-sept-production-bucket"
    key            = "rova-project-iac/terraform.tfstate"
    region         = "eu-central-1"
    use_lockfile   = true
    encrypt        = true
  }
}