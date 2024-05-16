#!/bin/bash


# Usage info
show_help() {
cat << EOF
Usage: ${0##*/} [-h] [-c <repo-name> -p <path> [-P <Profile>] [-f]]
This script helps customer to deploy this DevOps starter kit in an AWS Account.
    -h              display this help and exit
    -c <repo>       codecommit name
    -p <path>       path where to checkout the local copy of the repository
    -P <Profile>    aws cli profile
    -f              force repository fresh checkout even local copy found
EOF
}

run_init_deploy() {

    if [ "$awscliprofile" != "" ]; then
        echo "export aws profile $awscliprofile"
        export AWS_PROFILE=$awscliprofile
        echo aws cli use profile $AWS_PROFILE
        echo test with aws s3 ls commande
        aws s3 ls
        # exit 0

    else
        echo no aws cli profile provided, use the current one, $AWS_PROFILE
        echo test with aws s3 ls commande
        aws s3 ls
        # exit 0

    fi

    FoundRepo=$(aws codecommit list-repositories --query "repositories[?repositoryName=='$cc_name']" | jq -r .[].repositoryName)    
    echo "repo found is $FoundRepo"

    if [ "$FoundRepo" = "$cc_name" ]; then


        cd $path

        echo "Repository $cc_name already exists in the target account."
        if [ -d "$path/$cc_name" ]; then
            echo "Local copy in $path/$cc_name found"
            if [ "$force" == "true" ]; then
                echo "option -f, then remove existing local copy and checkout from remote"
                rm -rfv "$path/$cc_name"
                git clone codecommit::eu-central-1://$cc_name
            else
                echo "update local copy found in $path/$cc_name"
                cd "$path/$cc_name"
                git checkout "main"
                git pull
            fi
        else
            echo "Local copy not found, then checkout from remote"
            git clone codecommit::eu-central-1://$cc_name
        fi

        yes | cp -rf "$SCRIPT_DIR/toolchain" "$path/$cc_name"
        cd "$path/$cc_name"
        git add toolchain/*
        git commit -m "add/update autoupdate CI/CD toolchain"
        git push

    else
        echo "Repositiry $cc_name do not exist yet"
        echo "Create S3 bucket and zip file for repo initialization"
        cd $SCRIPT_DIR

        uuid=$(od -x /dev/urandom | head -1 | awk '{OFS="-"; print $2$3,$4,$5,$6,$7$8$9}')
        bucket_name="tmp-${uuid//-/}"
        aws s3 mb s3://$bucket_name
        
        # echo "git archive -o source.zip HEAD"
        # cd $SCRIPT_DIR
        # echo "current directory is $(pwd)"
        # git archive -o source.zip HEAD
        # aws s3 cp ./source.zip s3://$bucket_name
        # rm -f source.zip

        # zip -r source.zip $SCRIPT_DIR/ -x ".git*"
        zip -r source.zip ./toolchain -x ".git*"
        aws s3 cp ./source.zip s3://$bucket_name
        rm -f source.zip


        echo "Deploy autoupdate stack"
        aws cloudformation deploy \
            --no-fail-on-empty-changeset \
            --template-file ./toolchain/autoupdate.yml \
            --stack-name "autoupdate" \
            --capabilities CAPABILITY_IAM CAPABILITY_AUTO_EXPAND CAPABILITY_NAMED_IAM \
            --parameter-overrides \
            BranchName="main" \
            CodeInitBucketName="$bucket_name" \
            CodeCommitName="$cc_name" \



        deletebucket=$(aws s3 rb s3://$bucket_name --force)
        echo $deletebucket

        echo "Checkout local copy of the newly created repositiry"
        cd $path
        git clone codecommit::eu-central-1://$cc_name

        echo "done"

    fi

}

# Initialize context:
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
echo "SCRIPT_DIR is $SCRIPT_DIR"

OPTIND=1
# Resetting OPTIND is necessary if getopts was used previously in the script.
# It is a good idea to make OPTIND local if you process options in a function.

cc_name=""
path=""
force="false"
awscliprofile=""

while getopts "hfc:p:P::" opt; do
    case $opt in
        h)
            show_help
            exit 0
            ;;

        f)
            force="true"
            ;;

        c)  
            cc_name=$OPTARG
            ;;

        p)  
            path=$OPTARG
            ;;
        
        P)
            awscliprofile=$OPTARG
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





