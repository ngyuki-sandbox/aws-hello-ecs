////////////////////////////////////////////////////////////////////////////////
// VPC

data "aws_vpc" "default" {
  default = true
}

locals {
  // Data Source だと 1b が含まれて失敗するのでベタで定義
  availability_zones = [
    "ap-northeast-1a",
    "ap-northeast-1c",
  ]
}

data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.default.id
}

data "aws_security_group" "default" {
  name = "default"
}
