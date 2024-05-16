#!/bin/bash

# Usage info
show_help() {
cat << EOF
Usage: ${0##*/} [-h] [-c <repo-name> -p <path> [-f]]
This script helps customer to deploy this DevOps starter kit in an AWS Account.
    -h          display this help and exit
    -c <repo>   codecommit name
    -p <path>   path where to checkout the local copy of the repository
    -f          force repository fresh checkout even local copy found
    -d          destroy stack         

EOF
}

run_init_deploy() {

    CurrentRegion=$(aws configure get region)
    TargetAccountId=$(aws sts get-caller-identity | jq -r .Account)
    
    s3_bucket_name=tfstate-$TargetAccountId-$CurrentRegion

    if [ "$destroy" == "true" ]; then
        if [[ -z $path || -z $cc_name ]]; then
            echo "Missing arguments : both -p and -c arguments must be valued when using -d option !"
            exit 1
        elif [ -d "$path/$cc_name" ]; then
            echo "Destroying the stack"

            cd "$path/$cc_name/toolchain"
            terraform init \
            -backend-config="bucket=$s3_bucket_name" \
            -backend-config="region=$CurrentRegion" \

            export AWS_DEFAULT_REGION="$CurrentRegion"
            export TF_VAR_code_commit_name="$cc_name"
            export TF_VAR_backend_config_bucket="$s3_bucket_name"

            terraform destroy

            tf_resource_count=$(aws s3 cp s3://$s3_bucket_name/toolchain - | jq '.resources | length')
            echo "tf_resource_count : $tf_resource_count"
            if [ $tf_resource_count == '0' ]; then
                echo "Clearing S3 TF state as there is no more tf resources in tf state file !"
                aws s3 rm s3://$s3_bucket_name/toolchain
                echo "TF state file deleted !"
                aws s3 rb s3://$s3_bucket_name
                echo "S3 TF state bucket deleted !"
            else 
                echo "Do not clear s3 bucket because tf state file still reference $tf_resource_count resources !"
            fi

            exit 0
        else
            echo "Chech values of -p and -c arguments because [-p value]/[-c value] should lead to a local project DIRECTORY containing the toolchain DIRECTORY !"
            exit 1
         fi
    fi

    
    echo "create S3 bucket for Terraform backend if not yet exists ($s3_bucket_name)"
    
    bucketstatus=$(aws s3api head-bucket --bucket "${s3_bucket_name}" 2>&1)
    if echo "${bucketstatus}" | grep 'Not Found'; then
        echo "bucket doesn't exist";
        aws s3 mb s3://$s3_bucket_name --region $CurrentRegion
        aws s3api wait bucket-exists --bucket s3_bucket_name

    elif echo "${bucketstatus}" | grep 'Forbidden'; then
        echo "Bucket exists but not owned"
        exit 1
    elif echo "${bucketstatus}" | grep 'Bad Request'; then
        echo "Bucket name specified is less than 3 or greater than 63 characters"
        exit 1
    else
        echo "Bucket owned and exists"
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
                git clone codecommit::$CurrentRegion://$cc_name
            else
                echo "update local copy found in $path/$cc_name"
                cd "$path/$cc_name"
                git checkout "main"
                git pull
            fi
        else
            echo "Local copy not found, then checkout from remote"
            git clone codecommit::$CurrentRegion://$cc_name
        fi

        # yes | cp -rf "$SCRIPT_DIR/toolchain" "$path/$cc_name"
        rsync -av --exclude='.terraform*' --exclude='tfplan**' "$SCRIPT_DIR/toolchain" "$path/$cc_name"
        cd "$path/$cc_name"
        git add toolchain/*
        git commit -m "add/update autoupdate CI/CD toolchain"
        git push

    else
        echo "Repository $cc_name do not exist yet, than deploy the stack"

        cd $SCRIPT_DIR/toolchain
        terraform fmt
        terraform init \
            -backend-config="bucket=$s3_bucket_name" \
            -backend-config="region=$CurrentRegion" \

        export AWS_DEFAULT_REGION="$CurrentRegion"
        export TF_VAR_code_commit_name="$cc_name"
        export TF_VAR_backend_config_bucket="$s3_bucket_name"

        terraform validate
        
        terraform plan -out="tfplan.binary"
        # -var="code_commit_name=$cc_name" \

        terraform show tfplan.binary > tfplan.txt
        cat tfplan.txt

        # terraform apply "tfplan.binary"
        #  -auto-approve
        # -var="code_commit_name=$cc_name" \

        terraform apply -auto-approve
        #     -var="code_commit_name=$cc_name" \
        #     -auto-approve \



        
        echo "Checkout local copy of the newly created repositiry"
        cd $path
        if [ -d "$path/$cc_name" ]; then
            echo "Local copy in $path/$cc_name found"
            if [ "$force" == "true" ]; then
                echo "option -f, then remove existing local copy and checkout from remote"
                rm -rfv "$path/$cc_name"
            else
                echo "Use option -f to clean the existing local copy"
            fi
        fi

        git clone codecommit::$CurrentRegion://$cc_name

        # yes | cp -rf "$SCRIPT_DIR/toolchain" "$path/$cc_name"
        rsync -av --exclude='.terraform*' --exclude='tfplan**' "$SCRIPT_DIR/toolchain" "$path/$cc_name"
        cd "$path/$cc_name"
        git add toolchain/*
        git commit -m "add/update autoupdate CI/CD toolchain"
        git push


        echo "done"

    fi

}



# Initialize context:
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
echo "SCRIPT_DIR is $SCRIPT_DIR"


cc_name=""
path=""
force="false"
destroy="false"

while getopts "hfc:p:d" opt; do
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

        d)  
            destroy="true"
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