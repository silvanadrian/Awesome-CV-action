#!/bin/bash

set -e

main() {
  echo "" # see https://github.com/actions/toolkit/issues/168

  sanitize "${GITHUB_TOKEN}" "GITHUB_TOKEN"
  sanitize "${INPUT_FILE_NAME}" "INPUT_FILE_NAME"
  sanitize "${INPUT_FILE_NAME2}" "INPUT_FILE_NAME2"

  TAG_NAME=v$(date +%m-%d-%Y.%H.%M)


  INPUT_EXTENSION="tex"
  OUTPUT_EXTENSION="pdf"
  OUTPUT_FILE=${INPUT_FILE_NAME/$INPUT_EXTENSION/$OUTPUT_EXTENSION}
  OUTPUT_FILE2=${INPUT_FILE_NAME2/$INPUT_EXTENSION/$OUTPUT_EXTENSION}

  if ! uses "${INPUT_LATEST_TAG}"; then
    INPUT_LATEST_TAG="true"
  fi



  echo "=====> INPUTS <====="
  echo "FILE_NAME: $INPUT_FILE_NAME"
  echo "FILE_NAME2: $INPUT_FILE_NAME2"
  echo "GENERATED TAG_NAME: $TAG_NAME"
  echo "GITHUB REPOSITORY: $GITHUB_REPOSITORY"
  echo "INPUT_EXTENSION: $INPUT_EXTENSION"
  echo "OUTPUT_EXTENSION: $OUTPUT_EXTENSION"
  echo "OUTPUT_FILE: $OUTPUT_FILE"
  echo "OUTPUT_FILE2: $OUTPUT_FILE2"
  echo "=====> / INPUTS <====="
  echo ""

  set +e
    echo "==> TRYING TO GENERATE THE DOCUMENT"
    xelatex -file-line-error -halt-on-error  -interaction=nonstopmode $INPUT_FILE_NAME
    if [ ! $? -eq 0 ]; then
      echo "ERROR : ❌ > THE PDF DOCUMENT CAN'T BE GENERATED‼️"
      exit 1
    else
      echo "✅   $OUTPUT_FILE was successfully generated"
    fi
  set -e

  set +e
    echo "==> TRYING TO GENERATE THE DOCUMENT"
    xelatex -file-line-error -halt-on-error  -interaction=nonstopmode $INPUT_FILE_NAME2
    if [ ! $? -eq 0 ]; then
      echo "ERROR : ❌ > THE PDF DOCUMENT CAN'T BE GENERATED‼️"
      exit 1
    else
      echo "✅   $OUTPUT_FILE2 was successfully generated"
    fi
  set -e

  createRelease $GITHUB_REPOSITORY $GITHUB_TOKEN $TAG_NAME $OUTPUT_FILE $OUTPUT_FILE2

  if usesBoolean "${INPUT_LATEST_TAG}"; then
    cleanLatest $GITHUB_REPOSITORY $GITHUB_TOKEN
    createRelease $GITHUB_REPOSITORY $GITHUB_TOKEN "latest" $OUTPUT_FILE $OUTPUT_FILE2
  fi

   echo "::set-output name=TAG_NAME::${TAG_NAME}" 

}

cleanLatest() {
  echo "====> CLEANING LATEST RELEASE <===="
  LATEST_RELEASE_ID=$(curl -s -X GET --url https://api.github.com/repos/$1/releases/tags/latest --header "authorization: token $2" | jq -r ".id")
  if [ ! -z "${LATEST_RELEASE_ID}" ]; then
    echo "-> DELETE latest tag"
    curl -sS -X DELETE --url https://api.github.com/repos/$1/git/refs/tags/latest --header "authorization: token $2" 
    echo "-> DELETE latest release $LATEST_RELEASE_ID"
    curl -sS -X DELETE --url https://api.github.com/repos/$1/releases/$LATEST_RELEASE_ID --header "authorization: token $2" 
  fi
}

createRelease() {
  
  echo "==> CREATE TAG $3"
  OUTPUT_TAG="$(curl -sS -X POST --url https://api.github.com/repos/$1/git/refs --header "authorization: token $2" --header 'content-type: application/json' \
  --data '{
    "ref": "refs/tags/'"$3"'",
    "sha": "'"$GITHUB_SHA"'"
  }')"
  responseHandler "$OUTPUT_TAG" 

  echo "===> CREATE RELEASE $3"
  OUTPUT_RELEASE="$(curl -sS -X POST --url https://api.github.com/repos/$1/releases --header "authorization: token $2" --header 'content-type: application/json' \
  --data '{
    "tag_name": "'"$3"'",
    "name": "'"$3"'",
    "body": "Document generated at '"$(date +%m-%d-%Y.%H:%M)"'"
  }')"
  responseHandler "$OUTPUT_RELEASE" 
  RELEASE_ID=$(echo $OUTPUT_RELEASE | jq -r '.id')

  echo "====> UPLOAD ASSETS TO RELEASE $RELEASE_ID ($3)"
  UPLOAD_URL="https://uploads.github.com/repos/$1/releases/$RELEASE_ID/assets?name=$4"
  OUTPUT_UPLOAD=$(curl -sS -X POST --header "authorization: token $2" --header 'content-type: application/pdf' --url $UPLOAD_URL -F "data=@$4")
  responseHandler "$OUTPUT_UPLOAD"

  UPLOAD_URL="https://uploads.github.com/repos/$1/releases/$RELEASE_ID/assets?name=$5"
  OUTPUT_UPLOAD=$(curl -sS -X POST --header "authorization: token $2" --header 'content-type: application/pdf' --url $UPLOAD_URL -F "data=@$5")
  responseHandler "$OUTPUT_UPLOAD"


  ASSET_URL="https://github.com/$1/releases/download/$3/$4"
  ASSET_URL2="https://github.com/$1/releases/download/$3/$5"

  ROCKET_EMOJI="🚀"

  echo -e "=====> $ROCKET_EMOJI -> Your Document is available at the addres $ASSET_URL"
  echo -e "=====> $ROCKET_EMOJI -> Your Document is available at the addres $ASSET_URL2"
}

responseHandler() {
  if echo "${1}" | jq -e 'has("message")' > /dev/null; then
    MSG=$(echo ${1} | jq -r '.message')
    >&2 echo -e "-> ERROR the receive message is : \\n ${MSG}"
    exit 1
  fi
}

uses() {
  [ ! -z "${1}" ]
}

usesBoolean() {
  [ ! -z "${1}" ] && [ "${1}" = "true" ]
}

sanitize() {
  if [ -z "${1}" ]; then
    >&2 echo "Unable to find the ${2}. Did you set with.${2}?"
    exit 1
  fi
}

main
