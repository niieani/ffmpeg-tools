#!/usr/bin/env bash

# example usage:
# FILTER=".*(Red|Orange|Yellow).*" \
# ./bulk-ffmpeg.sh copy-without-audio ./target-dir ./2017/2017-09-21/*.MOV

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
  local format="${2:-%Y%m%d%H%M.%S}"
  stat -f "%Sm" -t "$format" "$file"
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
  mkdir -p "$TARGETDIR"
  shift
  for VIDEO in "$@"
  do
    if [[ ! -f "$VIDEO" ]]
    then
      echo "No such file: $VIDEO"
      break
    fi
    local VIDEO=$(file.fullPath "$VIDEO")
    local BASENAME=$(basename "$VIDEO")

    local EXTENSION="${BASENAME##*.}"
    local FILENAME="${BASENAME%%.*}"

    local TAGS=$(file.getTags "$VIDEO")
    local RATING
    RATING="${TAGS/*Red*/⭐️⭐️⭐️}"
    RATING="${RATING/*Orange*/⭐️⭐️}"
    RATING="${RATING/*Yellow*/⭐️}"
    RATING="${RATING/*Purple*/}"
    RATING="${RATING/*Green*/🤡}"

    local TIMESTAMP=$(file.getTimestamp "$VIDEO" "%Y-%m-%d-%H.%M")
    local OUTPUT="${TARGETDIR}/${TIMESTAMP}-${FILENAME}${RATING}.${EXTENSION,,}"

    if [[ "$TAGS" =~ ${FILTER-.*} ]]
    then
      if [[ -z "$DRY_RUN" ]]
      then
        video.copyWithoutAudio "$VIDEO" "$OUTPUT"
        file.copyTimestamp "$VIDEO" "$OUTPUT"
        file.addTags "$OUTPUT" "$(file.getTags "$VIDEO")"
      else
        echo "Would copy from: ${VIDEO}"
        echo "             as: ${OUTPUT}"
        echo "         rating: ${RATING}"
        echo "           tags: ${TAGS}"
      fi
    fi
  done
}

declare COMMAND="$1"
shift

case $COMMAND in
  copy-without-audio) bulk.copyWithoutAudio "$@";;
  rotate) bulk.rotateVideos "$@";;
esac
