
data "aws_caller_identity" "current_caller_identity" {}
data "aws_region" "current_region" {}

variable "code_commit_name" {
  type        = string
  description = "Name of the repository to create"
}

variable "backend_config_bucket" {
  type        = string
  description = "Name of the backend config bucket for terraform"
}


resource "aws_codecommit_repository" "LocalCodeCommit" {
  repository_name = var.code_commit_name
  description     = "Repository used to store the organisation configuration"
}

resource "aws_s3_bucket" "ArtifactsS3Bucket" {
  bucket = join("-", ["toolchain-artifacts", data.aws_caller_identity.current_caller_identity.account_id, data.aws_region.current_region.name])
  provisioner "local-exec" {
    when    = destroy
    command = "aws s3 rm s3://${self.bucket} --recursive"

  }
}

resource "aws_iam_role" "AutoUpdateCodePipelineRole" {
  name = "toolchain_autoupdatecodepipelinerole"

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
          Service = "codepipeline.amazonaws.com"
        }
      },
    ]
  })
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AdministratorAccess"
  ]
}

resource "aws_iam_role" "AutoUpdateCodeBuildRole" {
  name = "toolchain_autoupdatecodebuildrole"

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
          Service = "codebuild.amazonaws.com"
        }
      },
    ]
  })
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AdministratorAccess"
  ]
}

data "local_file" "BuildspecAutoUpdateCodeBuildProject" {
  filename = "${path.module}/scripts/autoupdate-buildspec.yml"
}
resource "aws_codebuild_project" "AutoUpdateCodeBuildProject" {
  name         = "toolchain-autoupdatecodebuildproject"
  description  = "update the current infra"
  service_role = resource.aws_iam_role.AutoUpdateCodeBuildRole.arn
  artifacts {
    type = "CODEPIPELINE"
  }
  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/amazonlinux2-x86_64-standard:3.0"
    type         = "LINUX_CONTAINER"

    environment_variable {
      name  = "backend_config_bucket"
      value = var.backend_config_bucket
    }

    environment_variable {
      name  = "code_commit_name"
      value = var.code_commit_name
    }

  }

  source {
    type                = "CODEPIPELINE"
    buildspec           = data.local_file.BuildspecAutoUpdateCodeBuildProject.content
    git_clone_depth     = 0
    insecure_ssl        = false
    report_build_status = false
  }

}

data "local_file" "BuildspecValidateCodeBuildProject" {
  filename = "${path.module}/scripts/validate-buildspec.yml"
}
resource "aws_codebuild_project" "ValidateCodeBuildProject" {
  name         = "toolchain-validatecodebuildproject"
  description  = "update the current infra"
  service_role = resource.aws_iam_role.AutoUpdateCodeBuildRole.arn
  artifacts {
    type = "CODEPIPELINE"
  }
  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/amazonlinux2-x86_64-standard:3.0"
    type         = "LINUX_CONTAINER"

    environment_variable {
      name  = "backend_config_bucket"
      value = var.backend_config_bucket
    }

    environment_variable {
      name  = "code_commit_name"
      value = var.code_commit_name
    }

  }

  source {
    type                = "CODEPIPELINE"
    buildspec           = data.local_file.BuildspecValidateCodeBuildProject.content
    git_clone_depth     = 0
    insecure_ssl        = false
    report_build_status = false
  }

}




data "local_file" "BuildspecDeployCodeBuildProject" {
  filename = "${path.module}/scripts/deploy-buildspec.yml"
}
resource "aws_codebuild_project" "DeployCodeBuildProject" {
  name         = "toolchain-deploycodebuildproject"
  description  = "update the current infra"
  service_role = resource.aws_iam_role.AutoUpdateCodeBuildRole.arn
  artifacts {
    type = "CODEPIPELINE"
  }
  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/amazonlinux2-x86_64-standard:3.0"
    type         = "LINUX_CONTAINER"

    environment_variable {
      name  = "backend_config_bucket"
      value = var.backend_config_bucket
    }

    environment_variable {
      name  = "code_commit_name"
      value = var.code_commit_name
    }

  }

  source {
    type                = "CODEPIPELINE"
    buildspec           = data.local_file.BuildspecDeployCodeBuildProject.content
    git_clone_depth     = 0
    insecure_ssl        = false
    report_build_status = false
  }

}


resource "aws_codepipeline" "AutoUpdateCodePipeline" {
  name     = "toolchain-autoupdatecodepipeline"
  role_arn = resource.aws_iam_role.AutoUpdateCodePipelineRole.arn

  artifact_store {
    location = resource.aws_s3_bucket.ArtifactsS3Bucket.bucket
    type     = "S3"
  }
  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        RepositoryName       = resource.aws_codecommit_repository.LocalCodeCommit.repository_name
        PollForSourceChanges = true
        BranchName           = "master"
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name             = "Validate"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["Validate_output"]
      version          = "1"
      run_order        = "1"

      configuration = {
        ProjectName = "toolchain-validatecodebuildproject"
      }
    }

    action {
      name             = "AutoUpdate"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["AutoUpdate_output"]
      version          = "1"
      run_order        = "2"

      configuration = {
        ProjectName = "toolchain-autoupdatecodebuildproject"
      }
    }

    action {
      name             = "Deploy"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["Deploy_output"]
      version          = "1"
      run_order        = "3"

      configuration = {
        ProjectName = "toolchain-deploycodebuildproject"
      }
    }


  }
}
