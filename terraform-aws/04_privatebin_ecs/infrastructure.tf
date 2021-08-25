# TERRAFORM & AWS CONFIG
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.36"
    }
  }
}

provider "aws" {
  region  = "eu-west-1"
}

###########################################################################
# VARIABLES
variable "r53_endpoint_url" {
  description = "URL of endpoint to be used"
  type        = string
}

variable "r53_hosted_zone_id" {
  description = "URL of endpoint to be used"
  type        = string
}

variable "subnets_id_a" {
  description = "Subnet AZ A"
  type        = string
}

variable "subnets_id_b" {
  description = "Subnet AZ B"
  type        = string
}

variable "vpc_id" {
  description = "VPC Id"
  type        = string
}

variable "acm_certificate_mydomain" {
  description = "ACM Certificate ARN for the HTTPS listener"
  type        = string
}

variable "running_containers_min" {
  description = "Total running containers"
  type        = string
}

variable "running_containers_max" {
  description = "Total running containers"
  type        = string
}

variable "tags" {
  description = "A map of tags to add to all resources."
  type        = map(string)
}

###########################################################################
# RESOURCES
# DNS record
resource "aws_route53_record" "www" {
  zone_id = var.r53_hosted_zone_id
  name    = var.r53_endpoint_url
  type    = "CNAME"
  ttl     = "300"
  records = [aws_lb.alb.dns_name]
}

# App Load Balancer Security Group
resource "aws_security_group" "sg_allow_https" {
  name        = "sg_allow_https"
  description = "Allow TLS inbound traffic"
  vpc_id      = var.vpc_id

  ingress {
    description      = "HTTPS access from anywhere"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "HTTP access from anywhere"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags    = var.tags
}

resource "aws_security_group" "service_security_group" {
  name        = "service_security"
  description = "Allow inbound traffic from ALB"
  vpc_id      = var.vpc_id

  ingress {
    description      = "TLS from VPC"
    from_port        = 8080
    to_port          = 8080
    protocol         = "tcp"
    security_groups  = [aws_security_group.sg_allow_https.id]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags    = var.tags
}

# App Load balancer 
resource "aws_lb" "alb" {
  name               = "sendsecrets-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.sg_allow_https.id]
  subnets            = [var.subnets_id_a, var.subnets_id_b]

  tags    = var.tags
}

# App Load balancer Target Group
resource "aws_lb_target_group" "sendsecrets_alb_tg" {
  name     = "sendsecrets-alb-tg"
  port     = 8080
  protocol = "HTTP"
  target_type    = "ip"
  vpc_id   = var.vpc_id

  stickiness {
    type = "lb_cookie"
    enabled = true
    cookie_duration = 604800
  }

  tags    = var.tags
}

# App Load balancer listener http & https
resource "aws_lb_listener" "sendsecrets_alb_https" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.acm_certificate_mydomain

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.sendsecrets_alb_tg.arn
  }
}

resource "aws_lb_listener" "sendsecrets_alb_http_redirected" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

}

# ECS Cluster
resource "aws_ecs_cluster" "sendssecrets_cluster" {
  name = "sendssecrets-public"
  tags    = var.tags
}

resource "aws_cloudwatch_log_group" "sendssecrets_cluster_log_group" {
  name = "sendssecrets_cluster"

  tags    = var.tags
}

# ECS_POLICY
resource "aws_iam_policy" "sendssecrets_fargate_service_policy" {
  name        = "serverless-es-replica-flush-policy"
  path        = "/"
  description = "Serverless policy to execute AWS actions on the sendssecrets ECS service"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ecs:RegisterContainerInstance",
          "ecs:DeregisterContainerInstance",
          "ecs:UpdateContainerInstancesState"
        ]
        Effect   = "Allow"
        Resource = aws_ecs_cluster.sendssecrets_cluster.arn
      },
      {
        Action = [
          "ecs:DiscoverPollEndpoint",
          "ecs:Submit*",
          "ecs:Poll",
          "ecs:StartTelemetrySession",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Action = [
          "s3:Get*"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:s3:::my-secrets-bucket-state-eu-west-1/terraform/my-secrets/*"
      }
    ]
  })
}

# ECS_ROLE
resource "aws_iam_role" "sendssecrets_fargate_execution_role" {
  depends_on = [ aws_iam_policy.sendssecrets_fargate_service_policy]
  name = "sendssecrets_fargate_execution_role"
  managed_policy_arns = [
      aws_iam_policy.sendssecrets_fargate_service_policy.arn
  ]

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

}

resource "aws_iam_role" "sendssecrets_fargate_service_role" {
  depends_on = [aws_iam_policy.sendssecrets_fargate_service_policy]
  name = "sendssecrets_fargate_service_role"
  managed_policy_arns = [
      aws_iam_policy.sendssecrets_fargate_service_policy.arn
  ]

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

}

# In case is needed to test locally
# docker run -d --restart="always" --read-only -p 8080:8080 -v privatebin-data:/srv/data privatebin/nginx-fpm-alpine:1.3.1
# MORE INFO: https://github.com/PrivateBin/PrivateBin/wiki/Docker

resource "aws_ecs_task_definition" "sendssecrets_fargate_task" {
   family                   = "sendssecrets_service"
   task_role_arn            = aws_iam_role.sendssecrets_fargate_service_role.arn
   execution_role_arn       = aws_iam_role.sendssecrets_fargate_execution_role.arn
   network_mode             = "awsvpc"
   cpu                      = "256" # NOTE: Supported CPU/mem values detailed at https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-cpu-memory-error.html
   memory                   = "512"
   requires_compatibilities = ["FARGATE"]
   container_definitions =  jsonencode([
     {
       "image": "privatebin/nginx-fpm-alpine:1.3.1",
       "name": "privatebin",
       "cpu": 128,
       "memory": 256,
       "essential": true,
       "portMappings": [{
         "containerPort": 8080,
         "hostPort": 8080
       }],
       "mountPoints": [
         {
           "sourceVolume": "privatebin-data",
           "containerPath": "/srv/data",
           "readOnly": false
         },
         {
           "sourceVolume": "privatebin-data",
           "containerPath": "/srv/cfg",
           "readOnly": false
         }
       ],
       "logConfiguration": {
         "logDriver": "awslogs",
         "options": {
           "awslogs-group": aws_cloudwatch_log_group.sendssecrets_cluster_log_group.id,
           "awslogs-region": "eu-west-1",
           "awslogs-stream-prefix": "pastebin"
         }
       }
     },
     {
       "image": "amazonlinux",
       "name": "privatebin-conf",
       "essential": false,
       "cpu": 128,
       "memory": 256,
       "command": [
         "sh",
         "-c",
         "yum -y install aws-cli && aws s3 cp s3://my-secrets-bucket-state-eu-west-1/terraform/my-secrets/conf.sample.php /srv/cfg/conf.php && aws s3 cp s3://my-secrets-bucket-state-eu-west-1/terraform/my-secrets/bootstrap.php /srv/cfg/bootstrap.php && echo $OUTPUT" ],
       "environment": [
            {"name": "OUTPUT", "value": "privatebin-conf run succesfully"}
        ],
       "mountPoints": [
         {
           "sourceVolume": "privatebin-data",
           "containerPath": "/srv/cfg",
           "readOnly": false
         }
       ],
       "logConfiguration": {
         "logDriver": "awslogs",
         "options": {
           "awslogs-group": aws_cloudwatch_log_group.sendssecrets_cluster_log_group.id,
           "awslogs-region": "eu-west-1",
           "awslogs-stream-prefix": "pastebin-conf"
         }
       }
     }
     
   ])
   volume {
     name      = "privatebin-data"
   }
  tags    = var.tags
}

# ECS Service
resource "aws_ecs_service" "sendssecrets_fargate_service" {
  name            = "sendssecrets_service"
  cluster         = aws_ecs_cluster.sendssecrets_cluster.id
  task_definition = aws_ecs_task_definition.sendssecrets_fargate_task.arn
  #desired_count   = var.running_containers
  health_check_grace_period_seconds = 300
  launch_type = "FARGATE"
  scheduling_strategy = "REPLICA"
  enable_execute_command = true # NOTE: aws ecs execute-command --cluster sendssecrets-public --command "ls" --interactive --task <TASK_ID> && read -p "Press any key" && reset

  network_configuration {
    assign_public_ip = true
    subnets = [var.subnets_id_a, var.subnets_id_b]
    security_groups = [aws_security_group.service_security_group.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.sendsecrets_alb_tg.arn
    container_name   = "privatebin"
    container_port   = 8080
  }

  lifecycle {
    ignore_changes = [
      desired_count
    ]
  }

  tags    = var.tags
}

# Fargate Auto Scaling based on memory consuption, thresold at 70%

resource "aws_appautoscaling_target" "privatebin_service_target" {
  min_capacity       = var.running_containers_min
  max_capacity       = var.running_containers_max
  resource_id        = join("/", ["service", aws_ecs_cluster.sendssecrets_cluster.name, aws_ecs_service.sendssecrets_fargate_service.name])
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "privatebin_service_target_policy" {
  name               = "privatebin_service_target_policy"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.privatebin_service_target.resource_id
  scalable_dimension = aws_appautoscaling_target.privatebin_service_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.privatebin_service_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value = 70 # i.e. If the service consumes as an average 70% or more of the Memory in use a new task will be running
  }
}

###############################################################

# OUTPUTS
output "privatebin_address" {
  value = join("", ["https://", var.r53_endpoint_url])
}

output "privatebin_service_name" {
  value = aws_ecs_service.sendssecrets_fargate_service.name
}

output "privatebin_service_name_ok" {
  value = join("/", ["service", aws_ecs_cluster.sendssecrets_cluster.name, aws_ecs_service.sendssecrets_fargate_service.name])
}
