terraform {

  backend "s3" {
    bucket         = "rova-project-bucket"
    key            = "terraform.tfstate"
    region         = "eu-central-1"
    use_lockfile   = true
    encrypt        = true
  }
}   