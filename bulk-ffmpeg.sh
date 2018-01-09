#!/usr/bin/env bash

file.fullPath() {
  [[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}"
}

file.getTags() {
  local file="$1"
  /usr/local/bin/tag --list --no-name "$file"
}

file.addTags() {
  local file="$1"
  local tags="$2"

  /usr/local/bin/tag --add "$tags" "$file"
}

file.getTimestamp() {
  local file="$1"
  stat -f "%Sm" -t "%Y%m%d%H%M.%S" "$file"
}

file.copyTimestamp() {
  local file="$1"
  local outputFile="$2"
  touch -t "$(file.getTimestamp "$file")" "$outputFile"
}

video.copyRotated() {
  local file="$1"
  local outputFile="$2"

  /usr/local/bin/ffmpeg -i \
    "$file" -c copy -metadata:s:v:0 rotate=180 \
    "$outputFile"
}

video.copyWithoutAudio() {
  local file="$1"
  local outputFile="$2"

  /usr/local/bin/ffmpeg -i \
    "$file" -c copy -an \
    "$outputFile"
}

bulk.rotateVideos() {
  for VIDEO in "$@"
  do
    declare EXTENSION="${VIDEO##*.}"
    declare OUTPUT="${VIDEO%%.*}-rotated.${EXTENSION}"

    if [[ -z "$DRY_RUN" ]]
    then
      video.copyRotated "$VIDEO" "$OUTPUT"
      file.addTags "$OUTPUT" "$(file.getTags "$VIDEO")"
      file.copyTimestamp "$VIDEO" "$OUTPUT"
    else
      echo "Would rotate from: ${VIDEO}"
      echo "               as: ${OUTPUT}"
    fi
  done
}

bulk.copyWithoutAudio() {
  local TARGETDIR=$(file.fullPath "$1")
  shift
  for VIDEO in "$@"
  do
    local VIDEO=$(file.fullPath "$VIDEO")
    local BASENAME=$(basename $VIDEO)

    local EXTENSION="${BASENAME##*.}"
    local FILENAME="${BASENAME%%.*}"

    local TAGS=$(file.getTags "$VIDEO")
    local RATING
    RATING="${TAGS/*Red*/⭐️⭐️⭐️}"
    RATING="${TAGS/*Orange*/⭐️⭐️}"
    RATING="${TAGS/*Yellow*/⭐️}"
    RATING="${TAGS/*Purple*/}"
    RATING="${TAGS/*Green*/🤡}"

    local TIMESTAMP=$(file.getTimestamp "$VIDEO")
    local OUTPUT="${TARGETDIR}/${TIMESTAMP}-${RATING}-${FILENAME}.${EXTENSION}"

    if [[ -z "$DRY_RUN" ]]
    then
      video.copyWithoutAudio "$VIDEO" "$OUTPUT"
      file.copyTimestamp "$VIDEO" "$OUTPUT"
      file.addTags "$OUTPUT" "$(file.getTags "$VIDEO")"
    else
      echo "Would copy from: ${VIDEO}"
      echo "             as: ${OUTPUT}"
    fi
  done
}

declare COMMAND="$1"
shift

case $COMMAND in
  copy-without-audio) bulk.copyWithoutAudio "$@";;
  rotate) bulk.rotateVideos "$@";;
esac
