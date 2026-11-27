#!/bin/bash
# Renders every store image from these sources: ./render.sh
set -e; cd "$(dirname "$0")"; OUT=..; mkdir -p $OUT/screenshots
B=../../brand
rsvg-convert -w 512 $B/icon.svg -o $OUT/icon-512.png
rsvg-convert -w 512 $B/icon_rounded.svg -o $OUT/icon-512-rounded.png
chrome() { google-chrome-stable --headless --disable-gpu --hide-scrollbars --allow-file-access-from-files "$@" 2>/dev/null; }
chrome --window-size=1024,500 --screenshot="$PWD/$OUT/banner-1024x500.png" "file://$PWD/banner.html"
chrome --window-size=1024,500 --force-device-scale-factor=2 --screenshot="$PWD/$OUT/banner-2048x1000.png" "file://$PWD/banner.html"
while IFS=$'\t' read -r n theme shot title sub; do
  sed -e "s|__THEME__|$theme|" -e "s|__SHOT__|$shot|" -e "s|__TITLE__|$title|" -e "s|__SUB__|$sub|" slide.tpl > .slide.html
  chrome --window-size=540,960 --force-device-scale-factor=2 --screenshot="$PWD/$OUT/screenshots/$n.png" "file://$PWD/.slide.html"
done < slides.tsv
rm -f .slide.html
