
resource "aws_arczonalshift_zonal_autoshift_configuration" "this" {
    resource_arn = var.lb_arn
    zonal_autoshift_status = var.zonal_autoshift_status
    
    dynamic "outcome_alarms" {
        for_each = var.outcome_alarms

        content {
            type = outcome_alarms.value.type
            alarm_identifier = outcome_alarms.value.alarm_identifier
        }
    }
}