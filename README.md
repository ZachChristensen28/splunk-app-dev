# App Dev

For building and publishing Splunk Apps and Add-ons

## Validate & Package

1. slim validate <package>
1. slim package -o <output_dir> <package>

    ```shell
    #i.e.
    slim package -o ~/build/pacakage TA-linux_iptables
    ```

## Submit to Splunk

1. validate -v
1. validate submit <package>
1. validate status
1. validate report
