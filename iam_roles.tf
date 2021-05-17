# Creating iam roles for the 3 lambda functions

resource "aws_iam_role" "SLW_lambda_functions_iam" {
  count = length(var.functions)
  name = "${var.functions[count.index]}_iam_role"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        
      {
        "Action": "sts:AssumeRole",
        "Principal": {
        "Service": "lambda.amazonaws.com"
      },
        "Effect": "Allow",
        "Sid": ""
    }
  ]
}
EOF
}

# Creating iam policies to allow the lambda functions to log into amazon cloudwatch

resource "aws_iam_policy" "SLW_log_group_permissions" {
  count = length(var.functions)
  name = "SLW_log_group_permissions_${var.functions[count.index]}"
  policy = jsonencode(
    {
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "logs:CreateLogGroup",
            "Resource": "arn:aws:logs:eu-central-1:${data.aws_caller_identity.current.account_id}:*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": [
                "${aws_cloudwatch_log_group.SLW_lambda_function_log_groups[count.index].arn}:*"
            ]
        }
      ]
    }
  )
}

# Attaching every iam policy to its corresponding iam role

resource "aws_iam_policy_attachment" "SLW_log_group_iam_attachment" {
  count = length(var.functions)
  name = "aws_iam_policy_attachment.SLW_log_group_iam_attachment"
  roles = [aws_iam_role.SLW_lambda_functions_iam[count.index].name]
  policy_arn = aws_iam_policy.SLW_log_group_permissions[count.index].arn
  
}

# Create log groups for the lambda functions to log into

resource "aws_cloudwatch_log_group" "SLW_lambda_function_log_groups" {
  count = length(var.functions)
  name              = "/aws/lambda/${var.functions[count.index]}"
  retention_in_days = 0
}