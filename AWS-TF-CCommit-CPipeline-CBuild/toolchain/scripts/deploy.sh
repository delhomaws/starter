#!/bin/bash

echo CODEBUILD_RESOLVED_SOURCE_VERSION: ${CODEBUILD_RESOLVED_SOURCE_VERSION} #BuildSHA1
echo CODEBUILD_SOURCE_VERSION: ${CODEBUILD_SOURCE_VERSION}
echo CODEBUILD_BUILD_ARN: ${CODEBUILD_BUILD_ARN}
echo AWS_REGION: ${AWS_REGION}
echo CODEBUILD_BUILD_NUMBER: ${CODEBUILD_BUILD_NUMBER}
echo CODEBUILD_SOURCE_REPO_URL: ${CODEBUILD_SOURCE_REPO_URL}



echo code_commit_name:          ${code_commit_name}
echo backend_config_bucket:     ${backend_config_bucket}



# # set -f                     # avoid globbing (expansion of *).
# array=(${CODEBUILD_BUILD_ARN//:/ })
# AccountId=${array[4]}
# echo AccountId: ${AccountId}
# # unset +f

# echo TargetRegion: ${AWS_REGION}
# BuildSHA1=${CODEBUILD_RESOLVED_SOURCE_VERSION}
# echo BuildSHA1: ${BuildSHA1}

# # Deploy the stack autoupdate
# FullStackName='autoupdate'
# aws cloudformation deploy \
#     --no-fail-on-empty-changeset \
#     --template-file ./toolchain/autoupdate.yml \
#     --stack-name $FullStackName \
#     --capabilities CAPABILITY_IAM CAPABILITY_AUTO_EXPAND CAPABILITY_NAMED_IAM \
#     --parameter-overrides \
#         BranchName=$BranchName \
#         CodeCommitName=$CodeCommitName \



