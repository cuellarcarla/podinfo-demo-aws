resource "aws_security_group" "ecs_tasks" {
  name   = "${var.app_name}-ecs-tasks-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 9898
    to_port         = 9898
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id] # Solo permite tráfico del ALB
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_ecs_cluster" "main" {
  name = "${var.app_name}-cluster"
}

resource "aws_ecs_task_definition" "app" {
  family                   = var.app_name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  
  # MAGIA DE AWS ACADEMY: Usamos el LabRole existente para evitar errores de IAM
  execution_role_arn       = var.aws_academy_labrole_arn
  task_role_arn            = var.aws_academy_labrole_arn

  container_definitions = jsonencode([{
    name      = "podinfo"
    image     = "ghcr.io/stefanprodan/podinfo:latest"
    essential = true
    portMappings = [{
      containerPort = 9898
      hostPort      = 9898
    }]
  }])
}

resource "aws_ecs_service" "main" {
  name            = "${var.app_name}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  launch_type     = "FARGATE"
  desired_count   = 2 # Alta Disponibilidad: Mínimo 2 instancias vivas siempre.

  network_configuration {
    security_groups  = [aws_security_group.ecs_tasks.id]
    subnets          = [aws_subnet.public_1.id, aws_subnet.public_2.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "podinfo"
    container_port   = 9898
  }

  depends_on = [aws_lb_listener.front_end]
}

output "alb_dns_name" {
  value = aws_lb.main.dns_name
}
