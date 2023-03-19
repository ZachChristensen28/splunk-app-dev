# App Dev

For building and publishing Splunk Apps and Add-ons

Use at your own risk :)

## Submit to Appinspect

```shell
export API_USER='api-username'

export API_PASS='api-password'

export APP_PATH='/path/to/App'

./appinspect.sh
```

### Example using GiHub Actions

```shell
curl -sSL https://raw.githubusercontent.com/ZachChristensen28/splunk-app-dev/master/appinspect.sh\
| API_USER='${{ secrets.API_USER }}'\
API_PASS='${{ secrets.API_PASS }}'\
APP_PATH=$(ls)\
bash
```

See full [GitHub actions example](https://github.com/ZachChristensen28/splunk-github-wfa/blob/main/.github/workflows/appinspect.yml).
