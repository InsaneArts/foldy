#!/bin/sh
# Composite an iPhone frame into a screen recording.
#   Tools/frame-clip.sh input.MOV output-name
# Writes site/media/<name>.mp4, .webm, and .jpg. The recording is scaled to 630 x 1368 (half of
# the iPhone Air's 1260 x 2736), its corners rounded to the 55 pt radius, and the body placed around
# it. Outside the body's own rounded corners the canvas is the page color (#09090b), so the canvas
# corners never show as a rectangle on the dark pages.
set -e
here=$(cd "$(dirname "$0")" && pwd)
src=$1; name=$2
stage="[0:v]scale=630:1368,format=rgba[v];[1:v]format=gray[m];[v][m]alphamerge,pad=682:1426:26:29:color=0x09090b@1.0[screen];[screen][2:v]overlay=0:0:format=auto[body];[3:v]format=gray[o];[body][o]alphamerge[framed];[0:v]scale=682:1426,drawbox=c=0x09090b:t=fill[bg];[bg][framed]overlay=0:0:format=auto:shortest=1,format=yuv420p[out]"
ffmpeg -v error -y -i "$src" -i "$here/iphone-mask.png" -i "$here/iphone-frame.png" -i "$here/iphone-outer-mask.png" \
  -filter_complex "$stage" -map "[out]" -an -c:v libx264 -preset slow -crf 23 -movflags +faststart "$here/../site/media/$name.mp4"
ffmpeg -v error -y -i "$src" -i "$here/iphone-mask.png" -i "$here/iphone-frame.png" -i "$here/iphone-outer-mask.png" \
  -filter_complex "$stage" -map "[out]" -an -c:v libvpx-vp9 -crf 33 -b:v 0 -row-mt 1 "$here/../site/media/$name.webm"
ffmpeg -v error -y -i "$here/../site/media/$name.mp4" -frames:v 1 "$here/../site/media/$name.jpg"
echo "wrote site/media/$name.{mp4,webm,jpg}"
