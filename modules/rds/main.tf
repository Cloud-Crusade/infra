
# DB 서브넷 그룹 — 모든 RDS 인스턴스가 공유 (프라이빗 서브넷)
resource "aws_db_subnet_group" "db_sg" {
  name       = "${var.project_name}-${var.environment}-db-subnet-group"
  subnet_ids = var.subnet_ids
}

# Primary DB
resource "aws_db_instance" "primary" {
  identifier        = "${var.project_name}-${var.environment}-primary"
  allocated_storage = var.allocated_storage
  engine            = "postgres"
  engine_version    = 13.23
  instance_class    = var.instance_class

  availability_zone = var.azs[0]

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.db_sg.name
  vpc_security_group_ids = var.vpc_security_group_ids

  publicly_accessible     = false
  skip_final_snapshot     = true
  backup_retention_period = 1
}

# Primary DB_replica
resource "aws_db_instance" "primary_replica" {
  identifier          = "${var.project_name}-${var.environment}-primary-replica"
  instance_class      = var.instance_class
  replicate_source_db = aws_db_instance.primary.arn

  # core 읽기: AZ1 은 primary(쓰기와 동일), AZ2 는 이 replica → AZ2 배치
  availability_zone = var.azs[1]

  db_subnet_group_name   = aws_db_subnet_group.db_sg.name
  vpc_security_group_ids = var.vpc_security_group_ids

  publicly_accessible = false
  skip_final_snapshot = true
}


# Reservation
resource "aws_db_instance" "reservation" {
  identifier        = "${var.project_name}-${var.environment}-reservation"
  allocated_storage = var.allocated_storage
  engine            = "postgres"
  engine_version    = 13.23
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


# Reservation_replica
resource "aws_db_instance" "reservation_replica" {
  identifier          = "${var.project_name}-${var.environment}-reservation-replica"
  instance_class      = var.instance_class
  replicate_source_db = aws_db_instance.reservation.arn

  # 예약 읽기: AZ1 은 이 replica → AZ1 배치 (AZ2 는 reservation_replica_2)
  availability_zone = var.azs[0]

  db_subnet_group_name   = aws_db_subnet_group.db_sg.name
  vpc_security_group_ids = var.vpc_security_group_ids

  publicly_accessible = false
  skip_final_snapshot = true
}


# Reservation_replica_2
resource "aws_db_instance" "reservation_replica_2" {
  identifier          = "${var.project_name}-${var.environment}-reservation-replica-2"
  instance_class      = var.instance_class
  replicate_source_db = aws_db_instance.reservation.arn

  availability_zone = var.azs[1]

  db_subnet_group_name   = aws_db_subnet_group.db_sg.name
  vpc_security_group_ids = var.vpc_security_group_ids

  publicly_accessible = false
  skip_final_snapshot = true
}