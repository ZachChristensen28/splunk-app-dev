# App Dev

For building and publishing Splunk Apps and Add-ons

## Validate & Package

1. slim validate <package>
1. slim package -o <output_dir> <package>

    ```shell
    #i.e.
    slim package -o ~/build/pacakage TA-linux_iptables
    ```

## Submit to Appinspect

export API_USER='api-username'

export API_PASS='api-password'

export APP_PATH='/path/to/App'

./appinspect.sh
