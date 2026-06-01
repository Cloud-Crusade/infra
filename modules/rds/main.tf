resource "aws_db_subnet_group" "db_sg" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = var.subnet_ids
}

# Primary DB #1
resource "aws_db_instance" "primary_1" {
  identifier        = "${var.project_name}-primary-1"
  allocated_storage = var.allocated_storage
  engine            = "postgres"
  engine_version    = var.engine_version
  instance_class    = var.instance_class

  availability_zone = var.azs[0]

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.db_sg.name
  vpc_security_group_ids = var.vpc_security_group_ids

  publicly_accessible      = false
  skip_final_snapshot      = true
  backup_retention_period  = 1
}

# Replica #1
resource "aws_db_instance" "replica_1" {
  identifier          = "${var.project_name}-replica-1"
  instance_class      = var.instance_class
  replicate_source_db = aws_db_instance.primary_1.id

  availability_zone = var.azs[0]

  db_subnet_group_name   = aws_db_subnet_group.db_sg.name
  vpc_security_group_ids = var.vpc_security_group_ids

  publicly_accessible = false
  skip_final_snapshot = true
}


# Primary DB #2
resource "aws_db_instance" "primary_2" {
  identifier        = "${var.project_name}-primary-2"
  allocated_storage = var.allocated_storage
  engine            = "postgres"
  engine_version    = var.engine_version
  instance_class    = var.instance_class

  availability_zone = var.azs[1]

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.db_sg.name
  vpc_security_group_ids = var.vpc_security_group_ids

  publicly_accessible     = false
  skip_final_snapshot     = true
  backup_retention_period = 1
}


# Replica 2a
resource "aws_db_instance" "replica_2a" {
  identifier          = "${var.project_name}-replica-2a"
  instance_class      = var.instance_class
  replicate_source_db = aws_db_instance.primary_2.id

  availability_zone = var.azs[1]

  db_subnet_group_name   = aws_db_subnet_group.db_sg.name
  vpc_security_group_ids = var.vpc_security_group_ids

  publicly_accessible = false
  skip_final_snapshot = true
}


# Replica 2b
resource "aws_db_instance" "replica_2b" {
  identifier          = "${var.project_name}-replica-2b"
  instance_class      = var.instance_class
  replicate_source_db = aws_db_instance.primary_2.id

  availability_zone = var.azs[1]

  db_subnet_group_name   = aws_db_subnet_group.db_sg.name
  vpc_security_group_ids = var.vpc_security_group_ids

  publicly_accessible = false
  skip_final_snapshot = true
}