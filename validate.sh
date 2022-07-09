#!/bin/bash
#
# Validate Splunk apps
#
# Updated by zTs: July 9, 2022
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


# Create report directory
if [[ ! -d $REPORT_DIR ]]; then
        mkdir -p $REPORT_DIR
fi

check_path() {
        test ! -f $1 && echo "Please enter valid path to App" && exit 1
        echo $1 > $REQUEST_APP
}

validate() {
        if [[ -z $API_PASS ]]; then
                curl -X GET -u "${API_USER}" --url "$API_LOGIN_URL" | jq -r .data.token > $TOKEN_FILE
        else
                curl -X GET -u "${API_USER}:${API_PASS}" --url "$API_LOGIN_URL" | jq -r .data.token > $TOKEN_FILE
        fi
}

submit() {
        check_path $1
        token=$(<$TOKEN_FILE)
        curl -X POST -H "Authorization: bearer $token" -H "Cache-Control: no-cache" -F "app_package=@\"$1\"" --url "${API_VAL_URL}" | jq -r .links[1].href | awk -F / '{ print $5 }' > $REQUEST_FILE
}

submit_cloud() {
        check_path $1
        token=$(<$TOKEN_FILE)
        curl -X POST -H "Authorization: bearer $token" -H "Cache-Control: no-cache" -F "app_package=@\"$1\"" -F "included_tags=cloud" --url "${API_VAL_URL}" | jq -r .links[1].href | awk -F / '{ print $5 }' > $REQUEST_FILE
}

get_status() {
        token=$(<$TOKEN_FILE)
        request=$(<$REQUEST_FILE)
        curl -X GET -H "Authorization: bearer $token" --url "${API_VAL_URL}/status/$request"
}

get_report() {
        token=$(<$TOKEN_FILE)
        request=$(<$REQUEST_FILE)
        curl -X GET -H "Authorization: bearer $token" -H "Cache-Control: no-cache" -H "Content-Type: text/html" --url "${API_REPORT_URL}/${request}" > ${REPORT_DIR}/${request}.html
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
