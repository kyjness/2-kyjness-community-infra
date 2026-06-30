# ECS 서비스(Application Auto Scaling) — CPU 목표 추적. Fargate 서비스 한도 내에서 desired_count 조절.
resource "aws_appautoscaling_target" "be" {
  max_capacity       = var.ecs_service_max_capacity
  min_capacity       = var.ecs_service_min_capacity
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.be.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "be_cpu" {
  name               = "${var.project_name}-be-cpu-tt"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.be.resource_id
  scalable_dimension = aws_appautoscaling_target.be.scalable_dimension
  service_namespace  = aws_appautoscaling_target.be.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = var.ecs_autoscaling_cpu_target
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}
