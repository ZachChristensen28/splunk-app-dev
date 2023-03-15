#!/bin/bash
#
# Validate Splunk apps
#
# Updated by zTs: March 14, 2023
#
# Use at your own risk :)
#
# Required Vars:
# ----------------------------
# ## Set through Environment Variables
# API_USER: User for API call
# API_PASS: Password for API call
# APP_PATH: Path to Splunk App/Add-on

# Usage:
# ------
# ./appinspect.sh

# Example:
# --------
# API_USER=zTs API_PASS=supersecretstuff APP_PATH=./SA-CrowdstrikeDevices ./appinspect.sh
#
set -o errexit   # abort on nonzero exitstatus
set -o pipefail  # don't hide errors within pipes

IFS=$'\t\n'   # Split on newlines and tabs (but not on spaces)
readonly API_LOGIN_URL='https://api.splunk.com/2.0/rest/login/splunk'
readonly API_VAL_URL='https://appinspect.splunk.com/v1/app/validate'
readonly API_STATUS_URL='https://appinspect.splunk.com/v1/app/validate/status'
readonly API_REPORT_URL='https://appinspect.splunk.com/v1/app/report'
# Removes path and .tgz/tar.gz extension
app_name_tmp=${APP_PATH##*/}
APP_NAME=${app_name_tmp%%.t*}
REPORT_DIR="${HOME}/reports"
readonly APP_NAME REPORT_DIR

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly AQUA='\033[1;36m'
readonly PURPLE='\033[35m'
readonly LIGHT_PURPLE='\033[1;35m'
readonly LIGHT_BLUE='\033[1;34m'
readonly RESET='\033[00m'

if [[ -z "${DEBUG}" ]]; then
        CURL_OPTS='-sSL'
else
        CURL_OPTS='-vL'
        set -x
fi
readonly CURL_OPTS

main() {
    # Preflight Check
    [[ ! -f $APP_PATH ]] && log_err 'Specify valid "APP_PATH"' && help
    [[ -z $API_USER ]] && log_err 'Specify "API_USER" using environment variable' && help
    [[ -z $API_PASS ]] && log_err 'Specify "API_PASS" using environment variable' && help
    log_success "Preflight Checks passed."

    authenticate
    sleep 1

    submit_app
    sleep 3

    check_status
}

help() {
cat <<'HELPMSG'

Verify apps through Appinspect.

Required Authentication Vars:
----------------------------
## Set through Environment Variables
API_USER: User for API call
API_PASS: Password for API call
APP_PATH: Path to Splunk App/Add-on

Usage:
------
    ./appinspect.sh

Example:
--------
    # Variables can be passed before argument or be set beforehand as environment variables.
    API_USER=zTs API_PASS=supersecretstuff APP_PATH=SA-CrowdstrikeDevices ./appinspect.sh
HELPMSG

exit 0
}

log_success() {
    printf "[${GREEN}\u2714${RESET}] %s\\n" "${*}"
}

log_err() {
    printf "[${RED}\u2718${RESET}] %s\\n" "${*}" 1>&2
}

log_info() {
    printf "[${AQUA}i${RESET}] %s\\n" "${*}"
}

finish() {
    local result=$?
    exit ${result}
}
trap finish EXIT ERR

authenticate() {
    local basic_auth auth_response status_code
    basic_auth=$(echo -n "${API_USER}:${API_PASS}" | base64)
    auth_response=$(curl ${CURL_OPTS}\
        --request GET\
        --header "Authorization: Basic ${basic_auth}"\
        --url "${API_LOGIN_URL}")
    status_code=$(echo "${auth_response}" | jq -r .status_code)
    [[ "${status_code}" -ne 200 ]] && log_err "$(echo "${auth_response}" | jq -r .errors)" && exit "${status_code}"
    API_TOK=$(echo "${auth_response}" | jq -r .data.token)
    readonly API_TOK
    log_success "Authentication successful."
}

submit_app() {
    local submit_response
    submit_response=$(curl ${CURL_OPTS}\
        --request POST\
        --header "Authorization: bearer ${API_TOK}"\
        --form 'included_tags="cloud"'\
        --form 'app_package=@'"${APP_PATH}"\
        --url "${API_VAL_URL}")
    REQUEST_ID=$(echo "${submit_response}" | jq -r .request_id)
    [[ -z "${REQUEST_ID}" ]] && log_err "$(echo "${submit_response}" | jq -r .message)" && exit 11
    readonly REQUEST_ID
    log_success "$(echo "${submit_response}" | jq -r .message)"
}

check_status() {
    local check_count sleep_time check_status status fail error warn output_file
    check_count=0
    sleep_time=15
    output_file="${REPORT_DIR}/${APP_NAME}.html"
    log_info "Checking status every ${sleep_time} seconds."
    while :; do
        check_count=$((check_count + 1))
        check_status=$(curl ${CURL_OPTS}\
            --request GET\
            --header "Authorization: bearer ${API_TOK}"\
            --url "${API_STATUS_URL}/${REQUEST_ID}")
        status=$(echo "${check_status}" | jq -r .status)

        if [[ "${status}" == "PROCESSING" ]] || [[ "${status}" == "PREPARING" ]]; then
            log_info "Appinspect processing request - ${check_count}"
        elif [[ "${status}" == "SUCCESS" ]]; then
            log_success "Appinspect completed validation - checks: ${check_count}"
            curl ${CURL_OPTS}\
                --request GET\
                --header "Authorization: bearer ${API_TOK}"\
                --header 'Content-Type: text/html'\
                --create-dirs\
                --output "${output_file}"\
                --url "${API_REPORT_URL}/${REQUEST_ID}"
            fail=$(echo "${check_status}" | jq -r .info.failure)
            error=$(echo "${check_status}" | jq -r .info.error)
            warn=$(echo "${check_status}" | jq -r .info.warning)
            if [[ "${fail}" -gt 0 ]] || [[ "${error}" -gt 0 ]]; then
                log_err "Failure count: ${fail}, Error count: ${error}"
                exit 12
            else
                log_success "No errors found! Warning count: ${warn}"
                log_info "Report written to ${output_file}"
                exit 0
            fi
        else
            log_err "An error occured."
            echo "${check_status}" | jq -r
            exit 13
        fi

        sleep "${sleep_time}"
    done
}

main "${@}"
