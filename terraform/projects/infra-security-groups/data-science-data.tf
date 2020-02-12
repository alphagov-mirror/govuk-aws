resource "aws_security_group" "data-science-data" {
  name = "data-science-data_access"

  vpc_id = "${data.terraform_remote_state.infra_vpc.vpc_id}"

  tags {
    Name = "data-science-data"
  }
}

resource "aws_security_group_rule" "data-science-data_ingress_ssh" {
  type        = "ingress"
  protocol    = "tcp"
  from_port   = 22
  to_port     = 22
  cidr_blocks = ["${var.office_ips}"]

  security_group_id = "${aws_security_group.data-science-data.id}"
}

resource "aws_security_group_rule" "data-science-data_egress_any_ssh" {
  type        = "egress"
  protocol    = "tcp"
  from_port   = 22
  to_port     = 22
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = "${aws_security_group.data-science-data.id}"
}
