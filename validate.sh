#!/bin/bash
#
# Validate Splunk apps
#
script_path=$(realpath $0)
BASE_DIR=$(dirname $script_path)
TOKEN_FILE="${BASE_DIR}/token.txt"
REQUEST_FILE="${BASE_DIR}/request.txt"
REPORT_DIR="${HOME}/github/reports"
temp=${2##*/}
APP=${temp//./-}

# Create report directory
if [[ ! -d $REPORT_DIR ]]; then
        mkdir -p $REPORT_DIR
fi

check_path() {
        test ! -f $1 && echo "Please enter valid path to App" && exit 1
}

validate() {
        if [[ -z $SPLUNK_PASS ]]; then
                curl -X GET -u "${API_USER}" --url "https://api.splunk.com/2.0/rest/login/splunk" | jq -r .data.token > $TOKEN_FILE
        else
                curl -X GET -u "${API_USER}:$SPLUNK_PASS" --url "https://api.splunk.com/2.0/rest/login/splunk" | jq -r .data.token > $TOKEN_FILE
        fi
}

submit() {
        check_path $1
        token=$(<$TOKEN_FILE)
        curl -X POST -H "Authorization: bearer $token" -H "Cache-Control: no-cache" -F "app_package=@\"$1\"" --url "https://appinspect.splunk.com/v1/app/validate" | jq -r .links[1].href | awk -F / '{ print $5 }' > $REQUEST_FILE
}

submit_cloud() {
        check_path $1
        token=$(<$TOKEN_FILE)
        curl -X POST -H "Authorization: bearer $token" -H "Cache-Control: no-cache" -F "app_package=@\"$1\"" -F "included_tags=cloud" --url "https://appinspect.splunk.com/v1/app/validate" | jq -r .links[1].href | awk -F / '{ print $5 }' > $REQUEST_FILE
}

get_status() {
        token=$(<$TOKEN_FILE)
        request=$(<$REQUEST_FILE)
        curl -X GET -H "Authorization: bearer $token" --url https://appinspect.splunk.com/v1/app/validate/status/$request
}

get_report() {
        token=$(<$TOKEN_FILE)
        request=$(<$REQUEST_FILE)
        curl -X GET -H "Authorization: bearer $token" -H "Cache-Control: no-cache" -H "Content-Type: text/html" --url "https://appinspect.splunk.com/v1/app/report/$request" > ${REPORT_DIR}/${request}.html
}

help() {
        cat <<EOF

Validate and submit apps to be verified
$0 [validate|v|submit|cloud|status|report] [app_path]

Parameters
----------
-v, validate    Get token from Splunk. Password required.
submit          Submit an app. App path required.
cloud           Submit an app to be cloud verified. App path required.
status          Get status of verification.
report          Get Report.
app_path        Path to App.

EOF

exit 0
}

case $1 in
        "-v" | "validate" ) validate ;;
        "submit" ) submit $2 ;;
        "cloud" ) submit_cloud $2 ;;
        "status" ) get_status ;;
        "report" ) get_report ;;
        * ) help ;;
esac
