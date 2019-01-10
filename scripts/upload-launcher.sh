#!/usr/bin/env bash
set -eu

if [[ ${TRAVIS_TAG} != v* ]]; then
  echo "Not on a git tag"
  exit 1
fi

export VERSION="$(echo "$TRAVIS_TAG" | sed 's@^v@@')"

# adapted fro https://github.com/almond-sh/almond/blob/d9f838f74dbc95965032e8b51568f7c1c7f2e71b/scripts/upload-launcher.sh

# config
REPO="coursier/coursier"
NAME="coursier"
CMD="./scripts/generate-launcher.sh -f --bat=true" # will work once sync-ed to Maven Central

# initial check with Sonatype releases
cd "$(dirname "${BASH_SOURCE[0]}")"
mkdir -p target/launcher
export OUTPUT="target/launcher/$NAME"
$CMD -r sonatype:releases


# actual script
RELEASE_ID="$(http "https://api.github.com/repos/$REPO/releases?access_token=$GH_TOKEN" | jq -r '.[] | select(.name == "v'"$VERSION"'") | .id')"

echo "Release ID is $RELEASE_ID"

# wait for sync to Maven Central
ATTEMPT=0
while ! $CMD; do
  if [ "$ATTEMPT" -ge 25 ]; then
    echo "Not synced to Maven Central after $ATTEMPT minutes, exiting"
    exit 1
  else
    echo "Not synced to Maven Central after $ATTEMPT minutes, waiting 1 minute"
    ATTEMPT=$(( $ATTEMPT + 1 ))
    sleep 60
  fi
done

echo "Uploading launcher"

curl \
  --data-binary "@$OUTPUT" \
  -H "Content-Type: application/zip" \
  "https://uploads.github.com/repos/$REPO/releases/$RELEASE_ID/assets?name=$NAME&access_token=$GH_TOKEN"

echo "Uploading bat file"

curl \
  --data-binary "@$OUTPUT.bat" \
  -H "Content-Type: text/plain" \
  "https://uploads.github.com/repos/$REPO/releases/$RELEASE_ID/assets?name=$NAME.bat&access_token=$GH_TOKEN"
