#!/bin/bash
#
# Validate Splunk apps
#
# Updated by zTs: Aug 25, 2022
#
# =======================================
# Customize
#
script_path=$(realpath $0)
BASE_DIR=$(dirname $script_path)
TOKEN_FILE="${BASE_DIR}/token.txt"
REQUEST_FILE="${BASE_DIR}/request.txt"
REQUEST_APP="${BASE_DIR}/request-app.txt"
REPORT_DIR="${HOME}/build/reports"
API_LOGIN_URL='https://api.splunk.com/2.0/rest/login/splunk'
API_VAL_URL='https://appinspect.splunk.com/v1/app/validate'
API_REPORT_URL='https://appinspect.splunk.com/v1/app/report'
temp=${2##*/}
APP=${temp//./-}
#
# End Customization
# =======================================

if [[ -z $DEBUG ]]; then
        CURL_OPTS='-sS'
else
        CURL_OPTS='-v'
fi

# Create report directory
if [[ ! -d $REPORT_DIR ]]; then
        mkdir -p $REPORT_DIR
fi

check_path() {
        test ! -f $1 && echo "Please enter valid path to App" && exit 1

        if [[ -z $2 ]]; then
                echo "${1%.tar.gz}" > $REQUEST_APP
        else
                echo "${1%.tar.gz}-${2}" > $REQUEST_APP
        fi
}

check_run() {
        if [[ $1 -gt 0 ]]; then
                echo "previous action failed - $2"
                exit 1
        fi
}

validate() {
        echo "Validating Credentials"
        if [[ -z $API_PASS ]]; then
                curl $CURL_OPTS -u "${API_USER}" --url "$API_LOGIN_URL" | jq -r .data.token > $TOKEN_FILE
        else
                echo "Validating with username and password"
                curl $CURL_OPTS -u "${API_USER}:${API_PASS}" --url "$API_LOGIN_URL" | jq -r .data.token > $TOKEN_FILE
        fi
        check_run $?
}

submit() {
        echo "Submitting app"
        check_path $1
        token=$(<$TOKEN_FILE)
        check_run $? "token file"
        curl $CURL_OPTS -X POST -H "Authorization: bearer $token" -H "Cache-Control: no-cache" -F "app_package=@\"$1\"" --url "${API_VAL_URL}" | jq -r .links[1].href | awk -F / '{ print $5 }' > $REQUEST_FILE
        check_run $?
}


submit_cloud() {
        echo "Submitting app for cloud vetting"
        check_path $1 cloud
        token=$(<$TOKEN_FILE)
        curl $CURL_OPTS -X POST -H "Authorization: bearer $token" -H "Cache-Control: no-cache" -F "app_package=@\"$1\"" -F "included_tags=cloud" --url "${API_VAL_URL}" | jq -r .links[1].href | awk -F / '{ print $5 }' > $REQUEST_FILE
        check_run $?
}

get_report() {
        echo "Fetching report"
        token=$(<$TOKEN_FILE)
        request=$(<$REQUEST_FILE)
        request_app=$(<$REQUEST_APP)
        curl $CURL_OPTS -X GET -H "Authorization: bearer $token" -H "Cache-Control: no-cache" -H "Content-Type: text/html" --url "${API_REPORT_URL}/${request}" > ${REPORT_DIR}/${request_app}.html
        check_run
        echo
        echo -e "\tReport downloaded to ${REPORT_DIR}/${request_app}.html"
        echo
}

check_count=0
check_limit=20
get_status() {
        check_count=$((check_count + 1))
        if [[ $check_count -gt $check_limit ]]; then
                echo "check limit exceeded" && exit 1
        fi
        echo "Fetching status (check_count=$check_count)"
        token=$(<$TOKEN_FILE)
        check_run $? 'token file'
        request=$(<$REQUEST_FILE)
        check_run $? 'request file'
        status=$(curl -sS -H "Authorization: bearer $token" --url "${API_VAL_URL}/status/$request")
        check_run $? 'status request'

        status_info=$(echo $status | jq .info)

        if [[ $status_info ==  "null" ]]; then
                echo "processing"
                sleep 20
                get_status
        else
                get_report
                errors=$(echo $status_info | jq ".error")
                failures=$(echo $status_info | jq ".failure")
                if [[ $errors -gt 0 ]]; then
                        touch ~/errors.txt
                elif [[ $failures -gt 0 ]]; then
                        touch ~/failures.txt
                fi
                exit 0

        fi

}

get_errors() {
        if [[ -f ~/errors.txt ]]; then
                echo "Errors exist" && exit 1
        elif [[ -f ~/failures.txt ]]; then
                echo "Failures exist" && exit 1
        else
                echo "No errors found" && exit 0
        fi
}

help() {
        cat <<EOF

Validate and submit apps to be verified
$0 [validate|v|submit|cloud|status|report] [app_path]

Parameters
----------
-v, validate    Get token from Splunk. Password required.
-s, submit          Submit an app. App path required.
-c, cloud           Submit an app to be cloud verified. App path required.
status          Get status of verification.
report          Get Report.
app_path        Path to App.
errors          Get errors from appinspect results.

EOF

exit 0
}

case $1 in
        "-v" | "validate" ) validate ;;
        "-s" | "submit" ) submit $2 ;;
        "-c" | "cloud" ) submit_cloud $2 ;;
        "status" ) get_status ;;
        "report" ) get_report ;;
        "get_errors" ) get_errors ;;
        * ) help ;;
esac
