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
        CURL_OPTS=''
else
        CURL_OPTS='-sS'
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
        test $? -ne 0 && echo "previous action failed" && exit 1
}

validate() {
        echo "Validating Credentials"
        if [[ -z $API_PASS ]]; then
                curl $CURL_OPTS -X GET -u "${API_USER}" --url "$API_LOGIN_URL" | jq -r .data.token > $TOKEN_FILE
        else
                echo "Validating with username and password"
                curl $CURL_OPTS -X GET -u "${API_USER}:${API_PASS}" --url "$API_LOGIN_URL" | jq -r .data.token > $TOKEN_FILE
        fi
        check_run
}

submit() {
        echo "Submitting app"
        check_path $1
        token=$(<$TOKEN_FILE)
        curl $CURL_OPTS -X POST -H "Authorization: bearer $token" -H "Cache-Control: no-cache" -F "app_package=@\"$1\"" --url "${API_VAL_URL}" | jq -r .links[1].href | awk -F / '{ print $5 }' > $REQUEST_FILE
        check_run
}


submit_cloud() {
        echo "Submitting app for cloud vetting"
        check_path $1 cloud
        token=$(<$TOKEN_FILE)
        curl $CURL_OPTS -X POST -H "Authorization: bearer $token" -H "Cache-Control: no-cache" -F "app_package=@\"$1\"" -F "included_tags=cloud" --url "${API_VAL_URL}" | jq -r .links[1].href | awk -F / '{ print $5 }' > $REQUEST_FILE
        check_run
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
        request=$(<$REQUEST_FILE)
        status=$(curl $CURL_OPTS -X GET -H "Authorization: bearer $token" --url "${API_VAL_URL}/status/$request" | jq ".info")
        check_run

        if [[ $status ==  "null" ]]; then
                echo "processing"
                sleep 20
                get_status
        else
                echo "$status"
                errors=$(echo $status | jq ".error")
                failures=$(echo $status | jq ".failure")
                if [[ $errors -gt 0 ]]; then
                        echo "Errors found" && exit 1
                elif [[ $failures -gt 0 ]]; then
                        echo "Failures found" && exit 1
                fi
                exit 0

        fi

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

EOF

exit 0
}

case $1 in
        "-v" | "validate" ) validate ;;
        "-s" | "submit" ) submit $2 ;;
        "-c" | "cloud" ) submit_cloud $2 ;;
        "status" ) get_status ;;
        "report" ) get_report ;;
        * ) help ;;
esac
