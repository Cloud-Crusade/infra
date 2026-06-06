
# DB 서브넷 그룹 — 모든 RDS 인스턴스가 공유 (프라이빗 서브넷)
resource "aws_db_subnet_group" "db_sg" {
  name       = "${var.PROJECT_NAME}-db-subnet-group"
  subnet_ids = var.SUBNET_IDS
}

# Primary DB
resource "aws_db_instance" "primary" {
  identifier        = "${var.PROJECT_NAME}-primary"
  allocated_storage = var.ALLOCATED_STORAGE
  engine            = "postgres"
  engine_version    = var.ENGINE_VERSION
  instance_class    = var.INSTANCE_CLASS

  availability_zone = var.AZS[0]

  db_name  = var.DB_NAME
  username = var.DB_USERNAME
  password = var.DB_PASSWORD

  db_subnet_group_name   = aws_db_subnet_group.db_sg.name
  vpc_security_group_ids = var.VPC_SECURITY_GROUP_IDS

  publicly_accessible     = false
  skip_final_snapshot     = true
  backup_retention_period = 1
}

# Primary DB_replica
resource "aws_db_instance" "primary_replica" {
  identifier          = "${var.PROJECT_NAME}-primary-replica"
  instance_class      = var.INSTANCE_CLASS
  replicate_source_db = aws_db_instance.primary.id

  availability_zone = var.AZS[0]

  db_subnet_group_name   = aws_db_subnet_group.db_sg.name
  vpc_security_group_ids = var.VPC_SECURITY_GROUP_IDS

  publicly_accessible = false
  skip_final_snapshot = true
}


# Reservation
resource "aws_db_instance" "reservation" {
  identifier        = "${var.PROJECT_NAME}-reservation"
  allocated_storage = var.ALLOCATED_STORAGE
  engine            = "postgres"
  engine_version    = var.ENGINE_VERSION
  instance_class    = var.INSTANCE_CLASS

  availability_zone = var.AZS[1]

  db_name  = var.DB_NAME
  username = var.DB_USERNAME
  password = var.DB_PASSWORD

  db_subnet_group_name   = aws_db_subnet_group.db_sg.name
  vpc_security_group_ids = var.VPC_SECURITY_GROUP_IDS

  publicly_accessible     = false
  skip_final_snapshot     = true
  backup_retention_period = 1
}


# Reservation_replica
resource "aws_db_instance" "reservation_replica" {
  identifier          = "${var.PROJECT_NAME}-reservation-replica"
  instance_class      = var.INSTANCE_CLASS
  replicate_source_db = aws_db_instance.reservation.id

  availability_zone = var.AZS[1]

  db_subnet_group_name   = aws_db_subnet_group.db_sg.name
  vpc_security_group_ids = var.VPC_SECURITY_GROUP_IDS

  publicly_accessible = false
  skip_final_snapshot = true
}


# Reservation_replica_2
resource "aws_db_instance" "reservation_replica_2" {
  identifier          = "${var.PROJECT_NAME}-reservation-replica-2"
  instance_class      = var.INSTANCE_CLASS
  replicate_source_db = aws_db_instance.reservation.id

  availability_zone = var.AZS[1]

  db_subnet_group_name   = aws_db_subnet_group.db_sg.name
  vpc_security_group_ids = var.VPC_SECURITY_GROUP_IDS

  publicly_accessible = false
  skip_final_snapshot = true
}