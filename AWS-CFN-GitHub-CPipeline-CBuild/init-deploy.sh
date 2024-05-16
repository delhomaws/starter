#!/bin/bash

# Usage info
show_help() {
cat << EOF
Usage: ${0##*/} [-h] [-t <token> -o <owner> -r <repo> -p <path>] 
This script helps customer to deploy this DevOps starter kit in an AWS Account.
    -h          display this help and exit
    -t <token>  github token
    -o <owner>  github owner
    -r <repo>   github repo name
    -b <branch> github branch name
    -p <path>   github local clone path

EOF
}

run_init_deploy() {

    echo "Copy files to the Github local clone of the repo, add, commit and push"
    yes | cp -rf "$SCRIPT_DIR/toolchain" "$github_path"
    cd $github_path
    git add toolchain/*
    git commit -m "add autoupdate CI/CD toolchain"
    git push


    echo "Add or update the Github token into an AWS secret"
    FoundSecretName=$(aws secretsmanager list-secrets | jq -r '.SecretList[] |  select(.Name=="GitHubSecret") | .Name')
    if [ "$FoundSecretName" != "GitHubSecret" ]; then
        echo "GitHubSecret doesn't exist yet, Let's create it!"
        response=$(
            aws secretsmanager create-secret \
            --name GitHubSecret \
            --description "My token to access my gitbub repositiry." \
            --kms-key-id "alias/aws/secretsmanager" \
            --secret-string "{\"token\":\"$github_token\"}" \
        )
        echo "secretsmanager create-secret result is $response"

    else
        echo "GitHubSecret exists, Let's update it!"
        response=$(
            aws secretsmanager update-secret \
            --secret-id GitHubSecret \
            --description "My token to access my gitbub repositiry." \
            --kms-key-id "alias/aws/secretsmanager" \
            --secret-string "{\"token\":\"$github_token\"}" \
        )
        echo "secretsmanager update-secret result is $response"
    fi




    echo "Deploy autoupdate stack to manage CI/CD"
    aws cloudformation deploy \
        --no-fail-on-empty-changeset \
        --template-file ./toolchain/autoupdate.yml \
        --stack-name "autoupdate" \
        --capabilities CAPABILITY_IAM CAPABILITY_AUTO_EXPAND CAPABILITY_NAMED_IAM \
        --parameter-overrides \
        BranchName=$github_branch \
        GitHubOwner=$github_owner \
        GitHubRepo=$github_repo \
        
}

# Initialize context:
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
echo "SCRIPT_DIR is $SCRIPT_DIR"


github_token=""
github_owner=""
github_repo=""
github_branch=""
github_path=""

OPTIND=1
# Resetting OPTIND is necessary if getopts was used previously in the script.
# It is a good idea to make OPTIND local if you process options in a function.

while getopts "ht:o:r:p:b:" opt; do
    case $opt in
        h)
            show_help
            exit 0
            ;;

        t)  
            github_token=$OPTARG
            ;;
        
        o)
            github_owner=$OPTARG
            ;;

        r)
            github_repo=$OPTARG
            ;;

        b)
            github_branch=$OPTARG
            ;;


        p)
            github_path=$OPTARG
            ;;

        \?)
            echo "$OPTARG : option invalide"
            show_help
            exit 1
            ;;

        *)
            show_help
            exit 1
            ;;    
    esac
done
shift "$((OPTIND-1))"   # Discard the options and sentinel --
run_init_deploy

# Everything that's left in "$@" is a non-option.
# printf '<%s>\n' "$@"

