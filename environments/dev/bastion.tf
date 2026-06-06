resource "tls_private_key" "bastion" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "bastion" {
  key_name   = "${var.PROJECT_NAME}-${var.ENVIRONMENT}-bastion-key"
  public_key = tls_private_key.bastion.public_key_openssh
}

resource "local_file" "bastion_private_key" {
  content         = tls_private_key.bastion.private_key_pem
  filename        = "${path.module}/bastion-key.pem"
  file_permission = "0600"
}

resource "aws_instance" "bastion" {
  ami                         = var.BASTION_AMI
  instance_type               = var.BASTION_INSTANCE_TYPE
  subnet_id                   = module.vpc.public_subnet_ids[0]
  vpc_security_group_ids      = [module.security_groups.bastion_sg_id]
  key_name                    = aws_key_pair.bastion.key_name
  associate_public_ip_address = true

  tags = {
    Name = "${var.PROJECT_NAME}-${var.ENVIRONMENT}-bastion"
  }
}