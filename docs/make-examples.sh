#!/usr/bin/env bash
# Draws the README's example output as a terminal shows it, in colour: each docs/example-*.txt
# in, the .svg beside it out. The colour comes from rad-prune's own filter, so run this again
# after changing the filter or an example.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)

# The filter's colour codes, patterns and colour_line, read out of the script itself, from its
# first colour code down to the line before colourise().
eval "$(sed -n '/^c_dim=/,/^colourise()/{/^colourise()/!p;}' "$here/../rad-prune")"
if ! declare -F colour_line >/dev/null; then
  echo "colour_line was not found in rad-prune; this script reads it between c_dim= and" \
       "colourise()." >&2
  exit 1
fi

for txt in "$here"/example-*.txt; do
  while IFS= read -r line || [ -n "$line" ]; do colour_line "$line"; done < "$txt" \
    | awk -f "$here/ansi-to-svg.awk" > "${txt%.txt}.svg"
  echo "wrote ${txt%.txt}.svg"
done
