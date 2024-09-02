resource "aws_subnet" "kubernetes_public" {
  vpc_id = var.vpc_id

  availability_zone       = var.public_subnets[count.index].zone
  cidr_block              = var.public_subnets[count.index].cidr
  map_public_ip_on_launch = true

  tags = {
    Name                                        = "k8s-${var.cluster_name}-public-${var.public_subnets[count.index].zone}"
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = ""
  }

  count = 2
}

resource "aws_route_table_association" "kubernetes_public" {
  subnet_id      = aws_subnet.kubernetes_public[count.index].id
  route_table_id = var.main_route_table_id

  count = 2
}

resource "aws_subnet" "kubernetes_private" {
  vpc_id = var.vpc_id

  availability_zone = var.private_subnets[count.index].zone
  cidr_block        = var.private_subnets[count.index].cidr

  tags = {
    Name                                        = "k8s-${var.cluster_name}-private-${var.public_subnets[count.index].zone}"
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = ""
    "karpenter.sh/discovery"                    = "${var.cluster_name}"
  }

  count = 2
}

resource "aws_eip" "kubernetes_nat" {
  count = 2
}

resource "aws_nat_gateway" "kubernetes" {
  allocation_id     = aws_eip.kubernetes_nat[count.index].id
  subnet_id         = aws_subnet.kubernetes_public[count.index].id
  connectivity_type = "public"

  tags = {
    Name = "k8s-${var.cluster_name}-nat-${count.index + 1}"
  }

  count = 2
}

resource "aws_route_table" "kubernetes_private" {
  vpc_id = var.vpc_id

  tags = {
    Name = "k8s-${var.cluster_name}-private-${count.index + 1}"
  }

  depends_on = [
    aws_nat_gateway.kubernetes
  ]

  count = 2
}

resource "aws_route" "kubernetes_private" {
  route_table_id         = aws_route_table.kubernetes_private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.kubernetes[count.index].id
  depends_on             = [aws_route_table.kubernetes_private]

  count = 2
}

resource "aws_route_table_association" "kubernetes_private" {
  subnet_id      = aws_subnet.kubernetes_private[count.index].id
  route_table_id = aws_route_table.kubernetes_private[count.index].id

  count = 2
}
