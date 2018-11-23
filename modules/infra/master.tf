resource "aws_launch_template" "master" {
  name_prefix = "${var.platform_name}-master-"

  block_device_mappings {
    device_name = "${local.base_image_root_device_name}"

    ebs {
      volume_size = 32
    }
  }

  image_id = "${local.base_image_id}"

  instance_market_options {
    market_type = "${var.use_spot ? "spot" : ""}"
  }

  instance_type = "m4.large"

  iam_instance_profile {
    arn = "${aws_iam_instance_profile.master.arn}"
  }

  key_name = "${aws_key_pair.platform.id}"

  tag_specifications {
    resource_type = "instance"

    tags = "${map(
      "kubernetes.io/cluster/${var.platform_name}", "owned",
      "Name", "${var.platform_name}-master",
      "Role", "master"
    )}"
  }

  user_data = "${base64encode(data.template_file.master.rendered)}"

  vpc_security_group_ids = ["${aws_security_group.node.id}", "${aws_security_group.master_public.id}"]
}

locals {
  master_target_groups       = ["${aws_lb_target_group.master_public.arn}"]
  master_infra_target_groups = ["${aws_lb_target_group.master_public.arn}", "${aws_lb_target_group.http.arn}", "${aws_lb_target_group.https.arn}"]
}

resource "aws_autoscaling_group" "master" {
  name                = "${var.platform_name}-master"
  vpc_zone_identifier = ["${data.aws_subnet.private.*.id}"]
  desired_capacity    = "${var.master_count}"
  max_size            = "${var.master_count}"
  min_size            = "${var.master_count}"

  # TODO workaround
  target_group_arns = ["${split(",", var.infra_node_count > 0 ? join(",", local.master_target_groups) : join(",", local.master_infra_target_groups))}"]

  launch_template = {
    id      = "${aws_launch_template.master.id}"
    version = "$$Latest"
  }
}