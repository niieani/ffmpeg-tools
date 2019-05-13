#!/usr/bin/env bash

# example usage:
# FILTER=".*(Red|Orange|Yellow).*" \
# ./bulk-ffmpeg.sh copy-without-audio ./target-dir ./2017/2017-09-21/*.MOV

declare ffmpeg=/usr/local/bin/ffmpeg
declare tag=/usr/local/bin/tag

run.ffmpeg() {
  echo "Running ${ffmpeg} $*"
  "${ffmpeg}" "$@"
}

file.fullPath() {
  [[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}"
}

file.getTags() {
  local file="$1"
  "${tag}" --list --no-name "$file"
}

file.addTags() {
  local file="$1"
  local tags="$2"

  "${tag}" --add "$tags" "$file"
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

  run.ffmpeg -i \
    "$file" -c copy -metadata:s:v:0 rotate=180 \
    "$outputFile"
}

video.copyWithoutAudio() {
  local file="$1"
  local outputFile="$2"

  run.ffmpeg -i \
    "$file" -c copy -an \
    "$outputFile"
}

video.toAV1() {
  local VIDEO="$1"
  local SUFFIX="$2"
  shift; shift;

  # if you need audio, replace -an with: -c:a libopus \

  run.ffmpeg \
    -ignore_chapters 1 \
    -i "$VIDEO" \
    -map_metadata -1 \
    -c:v libaom-av1 \
    -crf 34 \
    -b:v 0 \
    -pix_fmt yuv420p \
    -movflags +faststart \
    -strict experimental \
    "$@" \
    "${VIDEO%%.*}${SUFFIX}.mp4"
}

video.toHEVC() {
  local VIDEO="$1"
  local SUFFIX="$2"
  shift; shift;

  # if you need audio, replace -an with -c:a libfdk_aac
  # if your video is non-standard ratio, use: -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" \

  run.ffmpeg \
    -ignore_chapters 1 \
    -i "$VIDEO" \
    -map_metadata -1 \
    -an \
    -c:v libx265 \
    -crf 24 \
    -preset veryslow \
    -pix_fmt yuv420p \
    -movflags +faststart \
    -tag:v hvc1 \
    "$@" \
    "${VIDEO%%.*}${SUFFIX}.mp4"
}

video.toH264() {
  # https://gist.github.com/Vestride/278e13915894821e1d6f
  # https://evilmartians.com/chronicles/better-web-video-with-av1-codec
  local VIDEO="$1"
  local SUFFIX="$2"
  shift; shift;
  # rest are args passed to ffmpeg

  # h264, no audio, full size:
  run.ffmpeg \
    -ignore_chapters 1 \
    -i "$VIDEO" \
    -map_metadata -1 \
    -an \
    -c:v libx264 \
    -crf 24 \
    -preset veryslow \
    -profile:v main \
    -pix_fmt yuv420p \
    -movflags +faststart \
    "$@" \
    "${VIDEO%%.*}${SUFFIX}.mp4"
}

video.toWebm() {
  local VIDEO="$1"
  local SUFFIX="$2"
  # local BITRATE="$3"
  shift;
  shift;
  # shift;

  # rest are args passed to ffmpeg

  # https://github.com/deterenkelt/Nadeshiko/wiki/Tests.-VP9:-row%E2%80%91mt-on-and%C2%A0off
  # https://blog.programster.org/VP9-encoding

  # http://wiki.webmproject.org/ffmpeg/vp9-encoding-guide

  # was: -threads 1
  # -b:v "${BITRATE}" \

  # crf is the quality value (0-63 for VP9)

  # pass 1
  ffmpeg \
    -y \
    -ignore_chapters 1 \
    -i "$VIDEO" \
    -c:v libvpx-vp9 \
    -pass 1 \
    -passlogfile "${VIDEO%%.*}" \
    -b:v 0 \
    -crf 40 \
    -threads 16 \
    -row-mt 1 \
    -speed 4 \
    -tile-columns 0 \
    -frame-parallel 0 \
    -auto-alt-ref 1 \
    -lag-in-frames 25 \
    -g 9999 \
    -aq-mode 0 \
    -an -f webm \
    "$@" \
    /dev/null

  # pass 2
  ffmpeg \
    -ignore_chapters 1 \
    -i "$VIDEO" \
    -c:v libvpx-vp9 \
    -pass 2 \
    -passlogfile "${VIDEO%%.*}" \
    -b:v 0 \
    -crf 40 \
    -threads 16 \
    -row-mt 1 \
    -speed 0 \
    -tile-columns 0 \
    -frame-parallel 0 \
    -auto-alt-ref 1 \
    -lag-in-frames 25 \
    -g 9999 \
    -aq-mode 0 \
    -an -f webm \
    "$@" \
    "${VIDEO%%.*}${SUFFIX}.webm"
}

video.encodeForWeb() {
  local VIDEO="$1"
  shift;

  video.toHEVC "${VIDEO}" "@1x.hevc" -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" "$@"
  video.toHEVC "${VIDEO}" "@0.5x.hevc" -vf "scale=trunc(iw/1.5/2)*2:trunc(ih/1.5/2)*2" "$@"
  video.toAV1 "${VIDEO}" "@1x.av1" -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" "$@"
  video.toAV1 "${VIDEO}" "@0.5x.av1" -vf "scale=trunc(iw/1.5/2)*2:trunc(ih/1.5/2)*2" "$@"
  # h264, no audio, full size:
  video.toH264 "${VIDEO}" "@1x.h264" -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" "$@"
  # h264, no audio, half size:
  video.toH264 "${VIDEO}" "@0.5x.h264" -vf "scale=-1:ih/1.5" "$@"

  video.toWebm "${VIDEO}" "@1x.vp9@crf40" "$@"
  video.toWebm "${VIDEO}" "@0.5x.vp9@crf40" -vf "scale=-1:ih/1.5" "$@"
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

system.onInterrupt() {
  echo "Caught SIG_INT, exiting..."
  exit 0
}

declare COMMAND="$1"
shift

trap system.onInterrupt INT

case $COMMAND in
  copy-without-audio) bulk.copyWithoutAudio "$@";;
  rotate) bulk.rotateVideos "$@";;
  encode-for-web) video.encodeForWeb "$@";;
esac
