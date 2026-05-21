resource "aws_db_subnet_group" "main" {
  name       = "${var.environment}-db-subnet-group"
  subnet_ids = var.subnet_ids

  tags = {
    Name        = "${var.environment}-db-subnet-group"
    Environment = var.environment
  }
}

resource "aws_db_instance" "main" {
  #checkov:skip=CKV_AWS_118:Enhanced monitoring adds cost; not needed for dev
  #checkov:skip=CKV_AWS_353:Performance insights adds cost for extended retention
  #checkov:skip=CKV_AWS_293:Deletion protection intentionally disabled for dev teardown
  #checkov:skip=CKV_AWS_157:Multi-AZ doubles cost; single-AZ acceptable for dev
  #checkov:skip=CKV_AWS_161:IAM auth adds complexity; password auth via CI variable sufficient for dev
  #checkov:skip=CKV2_AWS_30:Query logging requires parameter group; out of scope for dev
  identifier = "${var.environment}-notes-db"

  engine         = "postgres"
  engine_version = "15"
  instance_class = "db.t3.micro"

  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name       = aws_db_subnet_group.main.name
  vpc_security_group_ids     = [var.security_group_id]
  publicly_accessible        = false
  multi_az                   = false
  auto_minor_version_upgrade = true
  copy_tags_to_snapshot      = true

  enabled_cloudwatch_logs_exports = ["postgresql"]

  skip_final_snapshot = true
  deletion_protection = false

  tags = {
    Name        = "${var.environment}-notes-db"
    Environment = var.environment
  }
}
