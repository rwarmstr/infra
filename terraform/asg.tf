locals {
  subnets      = local.all_subnet_ids
  // As of Oct 3 2022, startups started taking >2m
  grace_period = 160
  cooldown     = 180
}

resource "aws_autoscaling_group" "prod-mixed" {
  lifecycle {
    create_before_destroy = true
  }

  default_cooldown          = local.cooldown
  health_check_grace_period = local.grace_period
  health_check_type         = "ELB"
  max_size                  = 16
  min_size                  = 2
  // Made two after @apmorton suggestion to cover edge cases of "last node unhealthy"
  name                      = "prod"
  vpc_zone_identifier       = local.subnets

  mixed_instances_policy {
    instances_distribution {
      // This base value is zero so we don't have any non-spot instances. We may wish to bump this if we have issues
      // getting spot capacity.
      on_demand_allocation_strategy            = "lowest-price"
      on_demand_base_capacity                  = 0
      on_demand_percentage_above_base_capacity = 0
      spot_allocation_strategy                 = "price-capacity-optimized"
      spot_instance_pools                      = 0
    }
    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.CompilerExplorer-prod.id
        version            = "$Latest"
      }
      override {
        instance_type = "c6a.large"
      }
      override {
        instance_type = "c6i.large"
      }
      override {
        instance_type = "c5.large"
      }
      override {
        instance_type = "c5n.large"
      }
      override {
         instance_type = "c5a.large"
      }
      override {
         instance_type = "c5ad.large"
      }
    }
  }

  enabled_metrics = [
    "GroupDesiredCapacity",
    "GroupInServiceCapacity",
    "GroupInServiceInstances",
    "GroupMaxSize",
    "GroupMinSize",
    "GroupPendingCapacity",
    "GroupPendingInstances",
    "GroupStandbyCapacity",
    "GroupStandbyInstances",
    "GroupTerminatingCapacity",
    "GroupTerminatingInstances",
    "GroupTotalCapacity",
    "GroupTotalInstances",
  ]

  target_group_arns = [aws_alb_target_group.ce["prod"].arn]
}

resource "aws_autoscaling_policy" "prod-mixed" {
  lifecycle {
    create_before_destroy = true
  }

  autoscaling_group_name    = aws_autoscaling_group.prod-mixed.name
  name                      = "cpu-tracker"
  policy_type               = "TargetTrackingScaling"
  estimated_instance_warmup = local.grace_period + 30
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 50.0
  }
}

resource "aws_autoscaling_group" "beta" {
  lifecycle {
    create_before_destroy = true
  }

  default_cooldown          = local.cooldown
  health_check_grace_period = local.grace_period
  health_check_type         = "ELB"
  launch_template {
    id      = aws_launch_template.CompilerExplorer-beta.id
    version = "$Latest"
  }

  max_size            = 4
  min_size            = 0
  name                = "spot-beta"
  vpc_zone_identifier = local.subnets

  target_group_arns = [aws_alb_target_group.ce["beta"].arn]
}

resource "aws_autoscaling_group" "staging" {
  lifecycle {
    create_before_destroy = true
  }

  default_cooldown          = local.cooldown
  health_check_grace_period = local.grace_period
  health_check_type         = "ELB"
  launch_template {
    id      = aws_launch_template.CompilerExplorer-staging.id
    version = "$Latest"
  }
  max_size            = 4
  min_size            = 0
  name                = "staging"
  vpc_zone_identifier = local.subnets

  target_group_arns = [aws_alb_target_group.ce["staging"].arn]
}

resource "aws_autoscaling_group" "wintest" {
  lifecycle {
    create_before_destroy = true
  }

  default_cooldown          = local.cooldown
  // override grace period until everything works
  health_check_grace_period = 300
  health_check_type         = "ELB"
  launch_template {
    id      = aws_launch_template.CompilerExplorer-wintest.id
    version = "$Latest"
  }
  max_size            = 4
  min_size            = 0
  name                = "wintest"
  vpc_zone_identifier = local.subnets

  target_group_arns = [aws_alb_target_group.ce["wintest"].arn]
}

resource "aws_autoscaling_group" "winstaging" {
  lifecycle {
    create_before_destroy = true
  }

  default_cooldown          = local.cooldown
  // override grace period until everything works
  health_check_grace_period = 300
  health_check_type         = "ELB"
  launch_template {
    id      = aws_launch_template.CompilerExplorer-winstaging.id
    version = "$Latest"
  }
  max_size            = 4
  min_size            = 0
  name                = "winstaging"
  vpc_zone_identifier = local.subnets

  target_group_arns = [aws_alb_target_group.ce["winstaging"].arn]
}

resource "aws_autoscaling_group" "gpu" {
  lifecycle {
    create_before_destroy = true
  }

  default_cooldown          = local.cooldown
  health_check_grace_period = local.grace_period
  health_check_type         = "ELB"
  max_size                  = 2
  min_size                  = 1
  name                      = "gpu"
  vpc_zone_identifier       = local.subnets

  mixed_instances_policy {
    instances_distribution {
      on_demand_allocation_strategy            = "prioritized"
      // This base value is zero so we don't have any non-spot instances. We may wish to bump this if we have issues
      // getting spot capacity.
      on_demand_base_capacity                  = 0
      on_demand_percentage_above_base_capacity = 0
      spot_allocation_strategy                 = "price-capacity-optimized"
      spot_instance_pools                      = 0
    }
    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.CompilerExplorer-prod-gpu.id
        version            = "$Latest"
      }
    }
  }

  enabled_metrics = [
    "GroupDesiredCapacity",
    "GroupInServiceCapacity",
    "GroupInServiceInstances",
    "GroupMaxSize",
    "GroupMinSize",
    "GroupPendingCapacity",
    "GroupPendingInstances",
    "GroupStandbyCapacity",
    "GroupStandbyInstances",
    "GroupTerminatingCapacity",
    "GroupTerminatingInstances",
    "GroupTotalCapacity",
    "GroupTotalInstances",
  ]

  target_group_arns = [aws_alb_target_group.ce["gpu"].arn]
}


resource "aws_autoscaling_policy" "gpu" {
  lifecycle {
    create_before_destroy = true
  }

  autoscaling_group_name    = aws_autoscaling_group.gpu.name
  name                      = "cpu-tracker"
  policy_type               = "TargetTrackingScaling"
  estimated_instance_warmup = local.grace_period + 30
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 75.0
  }
}

resource "aws_sns_topic" "elb-instance-terminate" {
  name = "ElbInstanceTerminate"
}

resource "aws_autoscaling_notification" "notify" {
  group_names = [
    aws_autoscaling_group.prod-mixed.name,
    aws_autoscaling_group.gpu.name,
    aws_autoscaling_group.staging.name,
    aws_autoscaling_group.beta.name,
  ]
  notifications = [
    "autoscaling:EC2_INSTANCE_TERMINATE"
  ]

  topic_arn = aws_sns_topic.elb-instance-terminate.arn
}
