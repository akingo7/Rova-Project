resource "aws_s3_bucket" "rova_backend" {
  bucket = var.bucket_name_backend

  tags = merge(
    var.tags,
    { 
      Name = "${var.tags.project}-sept-${var.tags.environment}-bucket"
    }
  )
}
