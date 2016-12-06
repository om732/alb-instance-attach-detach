#!/bin/bash

usage() {
    echo "usage: $0 -i [INSTANCE_ID] -n [ALB_NAME] -a [ACTION]"
    echo "  -i, --instance-id: EC2 Instance Id"
    echo "  -n, --alb-name   : ALB Name"
    echo "  -a, --action     : attach or detach"
    echo "  -h, --help       : Print Help (this message) and exit"
    exit 1
}

info() {
    local message=$1
    echo $message 2>&1
}

warn() {
    local message=$1
    echo "[WARN] $message" 2>&1
}

fail() {
    local message=$1
    echo "[ERROR] $message" 2>&1
    exit 1
}

valid_env_defined() {
    local name=$1
    local env=$2

    if [ -z $env ]; then
        fail "$name not set"
        usage
    fi
}

valid_action_param() {
    local action=$1

    if [ "$action" != "attach" ] && [ $action != "detach" ]; then
        fail "$action not defined"
        usage
    fi
}

valid_attach_state() {
    local instance_id=$1
    local target_group_arn=$2
    local state=$3

    if [ $state == "attach" ]; then
        local result=$(aws elbv2 describe-target-health --target-group-arn $target_group_arn --targets Id=$instance_id --query 'TargetHealthDescriptions[?TargetHealth.State!=`unused`].Target[].Id' --output text)
    elif [ $state == "detach" ]; then
        local result=$(aws elbv2 describe-target-health --target-group-arn $target_group_arn --targets Id=$instance_id --query 'TargetHealthDescriptions[?TargetHealth.State==`unused`].Target[].Id' --output text)
    fi

    if [ -z $result ]; then
        return 1
    else
        return 0
    fi
}

check_target_health_state() {
    local time=0
    local timeout=60
    local instance_id=$1
    local target_group_arn=$2
    local ok_state=$3

    while :
    do
        sleep 2
        local result=$(aws elbv2 describe-target-health --target-group-arn $target_group_arn --targets Id=$instance_id --query 'TargetHealthDescriptions[].TargetHealth[].State' --output text)

        if [ "$result" == "$ok_state" ]; then
            return 0
        fi

        time=`expr $time + 2`
        if [ $time -gt $timeout ]; then
            return 1
        fi
    done

}


while [ ! -z $1 ]; do
    case $1 in
        '-i'|'--instance-id' )
            INSTANCE_ID="$2"
            shift 2 || break
            ;;
        '-n'|'--alb-name' )
            ALB_NAME="$2"
            shift 2 || break
            ;;
        '-a'|'--action' )
            ACTION=$2
            shift 2 || break
            ;;
        '-h'|'--help' )
            usage
            ;;
        * )
            echo "illegal argument $1" 1>&2
            usage
            ;;
    esac
done

valid_env_defined "Instance ID" $INSTANCE_ID
valid_env_defined "ALB Name"    $ALB_NAME
valid_env_defined "Action"      $ACTION
valid_action_param $ACTION

## get alb arn
ALB_ARN=$(aws elbv2 describe-load-balancers --name $ALB_NAME --query "LoadBalancers[].LoadBalancerArn|[0]" --output text)
if [ $? -ne 0 ]; then
    fail "Couldn't describe ALB named '$ALB_NAME'"
fi

## get target gorups arn
TARGET_GROUPS_ARN=$(aws elbv2 describe-target-groups --load-balancer-arn $ALB_ARN --query "TargetGroups[].TargetGroupArn" --output text)

for arn in $TARGET_GROUPS_ARN;
do
    case $ACTION in
        'attach')
            valid_attach_state $INSTANCE_ID $arn "detach"
            if [ $? -ne 0 ]; then
                warn "Already attached '$INSTANCE_ID' Target Group $arn. skip process"
                continue
            fi

            info "Attach '$INSTANCE_ID' for $arn"
            aws elbv2 register-targets --target-group-arn $arn --targets Id=$INSTANCE_ID
            if [ $? -ne 0 ]; then
                warn "Failed attach step"
            fi

            check_target_health_state $INSTANCE_ID $arn "healthy"
            if [ $? -ne 0 ]; then
                fail "Attach timeout"
            fi
            ;;
        'detach')
            valid_attach_state $INSTANCE_ID $arn "attach"
            if [ $? -ne 0 ]; then
                warn "Already detachd '$INSTANCE_ID' Target Group $arn. skip process"
                continue
            fi

            info "Detach '$INSTANCE_ID' for $arn"
            aws elbv2 deregister-targets --target-group-arn $arn --targets Id=$INSTANCE_ID
            if [ $? -ne 0 ]; then
                warn "Failed detach step"
            fi

            check_target_health_state $INSTANCE_ID $arn "unused"
            if [ $? -ne 0 ]; then
                fail "Detach timeout"
            fi
            ;;
    esac
done
