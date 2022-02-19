output "image_id" {
  value = data.aws_ami.ami.image_id
}

output "instance_id" {
  value = aws_instance.instance.id
}

output "private_ip" {
  value = aws_instance.instance.private_ip
}

output "s3_bucket" {
  value = var.s3_bucket
}

output "secondary_volume_id" {
  value = var.secondary_block_device ? aws_ebs_volume.secondary_volume[0].id : "NONE"
}

output "public_ip" {
  value = aws_instance.instance.public_ip
}
