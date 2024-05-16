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




# set -f                     # avoid globbing (expansion of *).
array=(${CODEBUILD_BUILD_ARN//:/ })
AccountId=${array[4]}
echo AccountId: ${AccountId}
# unset +f

echo TargetRegion: ${AWS_REGION}
BuildSHA1=${CODEBUILD_RESOLVED_SOURCE_VERSION}
echo BuildSHA1: ${BuildSHA1}


echo "###################################"
echo "###################################"
echo "###################################"
echo "###################################"
echo "###################################"
echo "###################################"

pip install --upgrade pip
pip install cfn-lint
cfn-lint ./**/*.y*ml -i W2,W1020

echo "###################################"
echo "###################################"
echo "###################################"
echo "###################################"
echo "###################################"
echo "###################################"

