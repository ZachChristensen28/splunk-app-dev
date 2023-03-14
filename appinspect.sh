#!/bin/bash
#
# Validate Splunk apps
#
# Updated by zTs: March 13, 2022
#
# Use at your own risk :)
#
script_path=$(realpath $0)
BASE_DIR=$(dirname $script_path)
REPORT_DIR="${HOME}/reports"
API_LOGIN_URL='https://api.splunk.com/2.0/rest/login/splunk'
API_VAL_URL='https://appinspect.splunk.com/v1/app/validate'
API_STATUS_URL='https://appinspect.splunk.com/v1/app/validate/status'
API_REPORT_URL='https://appinspect.splunk.com/v1/app/report'
APP_PATH=$1
# Removes path and .tgz/tar.gz extension
app_name_tmp=${APP_PATH##*/}
APP_NAME=${app_name_tmp%%.t*}

if [[ -z $DEBUG ]]; then
        CURL_OPTS='-sSL'
else
        CURL_OPTS='-vL'
fi

help() {
echo "

Verify apps through Appinspect.

Required Authentication Vars:
----------------------------
## Set through Environment Variables
API_USER: User for API call
API_PASS: Password for API call


Usage:
------
    $0 [app_path]

Example:
--------
    $0 SA-CrowdstrikeDevices
"

exit 0
}

log_success() {
    echo "[✓] $1"
}

log_failure() {
    echo "[✗] $1"
}

log_info() {
    echo "[i] $1"
}

# Preflight Check
[[ ! -f $APP_PATH ]] && log_failure "Specify valid app path" && help
[[ -z $API_USER ]] && log_failure 'Specify `API_USER` using environment variable' && help
[[ -z $API_PASS ]] && log_failure 'Specify `API_PASS` using environment variable' && help
log_success "Preflight Checks passed"

# Authenticate
basic_auth=$(echo -n "${API_USER}:${API_PASS}" | base64)
auth_response=$(curl $CURL_OPTS\
    --request GET\
    --header "Authorization: Basic $basic_auth"\
    --url "$API_LOGIN_URL")
status_code=$(echo $auth_response | jq -r .status_code)
[[ $status_code -gt 200 ]] && log_failure "$(echo $auth_response | jq -r .errors)" && exit $status_code
API_TOK=$(echo $auth_response | jq -r .data.token)
log_success "Authentication successful"
sleep 1

# Submit app
submit_response=$(curl $CURL_OPTS\
    --request POST\
    --header "Authorization: bearer $API_TOK"\
    --form 'included_tags="cloud"'\
    --form 'app_package=@'$APP_PATH\
    --url "$API_VAL_URL")
REQUEST_ID=$(echo $submit_response | jq -r .request_id)
[[ -z $REQUEST_ID ]] && log_failure "$(echo $submit_response | jq -r .message)" && exit 11
log_success "$(echo $submit_response | jq -r .message)"
sleep 3

# Check Status
check_count=0
sleep_time=15
log_info "checking status every $sleep_time seconds"
while :; do
    check_count=$((check_count + 1))
    CHECK_STATUS=$(curl $CURL_OPTS\
        --request GET\
        --header "Authorization: bearer $API_TOK"\
        --url "${API_STATUS_URL}/${REQUEST_ID}")
    STATUS=$(echo $CHECK_STATUS | jq -r .status)

    if [[ "$STATUS" == "PROCESSING" ]] || [[ "$STATUS" == "PREPARING" ]]; then
        log_info "Appinspect processing request - $check_count"
    elif [[ "$STATUS" == "SUCCESS" ]]; then
        log_success "Appinspect completed validation - checks: $check_count"
        curl $CURL_OPTS\
            --request GET\
            --header "Authorization: bearer $API_TOK"\
            --header 'Content-Type: text/html'\
            --create-dirs\
            --output "${REPORT_DIR}/${APP_NAME}.html"\
            --url "${API_REPORT_URL}/${REQUEST_ID}"
        FAIL=$(echo $CHECK_STATUS | jq -r .info.failure)
        ERROR=$(echo $CHECK_STATUS | jq -r .info.error)
        WARN=$(echo $CHECK_STATUS | jq -r .info.warning)
        if [[ $FAIL -gt 0 ]] || [[ $ERROR -gt 0 ]]; then
            log_failure "Failure count: $FAIL, Error count: $ERROR"
            exit 12
        else
            log_success "No errors found! Warning count: $WARN"
            log_info "report written to $REPORT_DIR"
            exit 0
        fi
    else
        log_failure "An error occured."
        echo $CHECK_STATUS | jq -r
        exit 13
    fi

    sleep $sleep_time
done

exit 0
