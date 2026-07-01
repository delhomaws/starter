#!/bin/bash
set -e

echo CODEBUILD_RESOLVED_SOURCE_VERSION: ${CODEBUILD_RESOLVED_SOURCE_VERSION} #BuildSHA1
echo CODEBUILD_SOURCE_VERSION: ${CODEBUILD_SOURCE_VERSION}
echo CODEBUILD_BUILD_ARN: ${CODEBUILD_BUILD_ARN}
echo AWS_REGION: ${AWS_REGION}
echo CODEBUILD_BUILD_NUMBER: ${CODEBUILD_BUILD_NUMBER}
echo CODEBUILD_SOURCE_REPO_URL: ${CODEBUILD_SOURCE_REPO_URL}

echo BranchName:            ${BranchName}
echo ArtifactsS3Bucket:     ${ArtifactsS3Bucket}
echo StackName:             ${StackName}




# set -f                     # avoid globbing (expansion of *).
array=(${CODEBUILD_BUILD_ARN//:/ })
AccountId=${array[4]}
echo AccountId: ${AccountId}
# unset +f

echo TargetRegion: ${AWS_REGION}
BuildSHA1=${CODEBUILD_RESOLVED_SOURCE_VERSION}
echo BuildSHA1: ${BuildSHA1}

# Deploy the stack autoupdate.
# The stack name is injected by the pipeline (CodeBuild env var) so the self-update
# targets the same repo-scoped stack that init-deploy.sh created.
FullStackName="${StackName}"
if [ -z "$FullStackName" ]; then
    echo "ERROR: StackName environment variable is not set. Cannot determine which stack to update." >&2
    exit 1
fi

# The self-update path must only ever UPDATE an existing stack, never bootstrap a new
# one. If the stack is missing, fail loudly rather than silently creating a fork.
if ! aws cloudformation describe-stacks --stack-name "$FullStackName" >/dev/null 2>&1; then
    echo "ERROR: CloudFormation stack '$FullStackName' does not exist." >&2
    echo "       The autoupdate pipeline can only update an existing stack created by init-deploy.sh. Aborting." >&2
    exit 1
fi

aws cloudformation deploy \
    --no-fail-on-empty-changeset \
    --template-file ./toolchain/autoupdate.yml \
    --stack-name $FullStackName \
    --capabilities CAPABILITY_IAM CAPABILITY_AUTO_EXPAND CAPABILITY_NAMED_IAM \
    --parameter-overrides \
        BranchName=$BranchName \
        GitHubOwner=$GitHubOwner \
        GitHubRepo=$GitHubRepo \


# echo "aws cloudformation package ./master.yml"
# aws cloudformation package \
#   --template-file         ./master.yml \
#   --output-template-file  ./master.yml \
#   --s3-bucket ${ArtifactsS3Bucket} \
#   --s3-prefix ${BranchName}/${BuildSHA1} \




# echo "aws cloudformation master.yml"
# FullStackName='master'
# aws cloudformation deploy \
#     --no-fail-on-empty-changeset \
#     --template-file ./master.yml \
#     --stack-name $FullStackName \
#     --capabilities CAPABILITY_IAM CAPABILITY_AUTO_EXPAND CAPABILITY_NAMED_IAM \
#     --parameter-overrides \
#         BranchName=$BranchName \
#         BuildSHA1=$BuildSHA1 \


# # # # pip install aws-sam-cli
# # # # USER_BASE_PATH=$(python -m site --user-base)
# # # # export PATH=$PATH:$USER_BASE_PATH/bin
# # # # sam build -t ./test.yml
# # # # sam package  \
# # # #   --template-file         ./test.yml \
# # # #   --output-template-file  ./test.yml \
# # # #   --s3-bucket ${ArtifactsS3Bucket} \
# # # #   --s3-prefix ${BranchName}/${BuildSHA1} \
    