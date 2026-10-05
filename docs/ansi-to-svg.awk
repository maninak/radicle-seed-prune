# Turns lines carrying the colour codes rad-prune prints (bold, dim, red, green, yellow, cyan)
# into an SVG of a terminal window. The palette follows the reader's light or dark theme.
BEGIN {
  cw = 8.43; lh = 19; pad = 18; top = 40   # character width and line height at 14px
  esc = sprintf("%c", 27)
}
{
  # A terminal's other controls (the progress bar's carriage return and line erase) have no
  # place in an SVG, and would make it invalid XML.
  gsub("\r|" esc "\\[K", "")
  line[NR] = $0
  plain = $0; gsub(esc "\\[[0-9;]*m", "", plain)
  if (length(plain) > cols) cols = length(plain)
}
function xml(s) { gsub(/&/, "\\&amp;", s); gsub(/</, "\\&lt;", s); gsub(/>/, "\\&gt;", s); return s }
# The class of a run of text, from the codes in force: a colour wins over dim, and bold alone
# is the brightest plain text.
function cls(   c) {
  c = colour != "" ? colour : (dim ? "d" : (bold ? "w" : ""))
  if (bold) c = c " b"
  return c
}
END {
  w = int(cols * cw + 2 * pad + 1); h = top + NR * lh + pad
  printf "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"%d\" height=\"%d\" viewBox=\"0 0 %d %d\">\n", w, h, w, h
  print "<style>"
  print "  svg { --bg: #151a17; --fg: #d6ddd8; --d: #78847d; --w: #ffffff; --r: #ef7b74;"
  print "        --g: #8fcf8a; --y: #e2c06a; --c: #6cc6c9; --bar: #2a312d }"
  print "  @media (prefers-color-scheme: light) {"
  print "    svg { --bg: #fbfbf8; --fg: #2a2f2c; --d: #8a928d; --w: #000000; --r: #b3261e;"
  print "          --g: #2c7a2c; --y: #9a6a00; --c: #00707a; --bar: #e6e8e3 } }"
  print "  text { font: 14px ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', monospace;"
  print "         fill: var(--fg); white-space: pre }"
  print "  .d { fill: var(--d) } .w { fill: var(--w) } .b { font-weight: 700 } .r { fill: var(--r) }"
  print "  .g { fill: var(--g) } .y { fill: var(--y) } .c { fill: var(--c) }"
  print "  .bg { fill: var(--bg) } .bar { fill: var(--bar) }"
  print "</style>"
  printf "<rect class=\"bg\" width=\"%d\" height=\"%d\" rx=\"8\"/>\n", w, h
  printf "<rect class=\"bar\" width=\"%d\" height=\"28\" rx=\"8\"/>\n", w
  printf "<rect class=\"bar\" y=\"20\" width=\"%d\" height=\"8\"/>\n", w
  print "<circle cx=\"18\" cy=\"14\" r=\"5\" fill=\"#ef6b5f\"/><circle cx=\"36\" cy=\"14\" r=\"5\" fill=\"#f5bd4f\"/><circle cx=\"54\" cy=\"14\" r=\"5\" fill=\"#61c454\"/>"
  for (i = 1; i <= NR; i++) {
    printf "<text x=\"%d\" y=\"%d\" xml:space=\"preserve\">", pad, top + i * lh - 5
    s = line[i]; bold = 0; dim = 0; colour = ""
    while (match(s, esc "\\[[0-9;]*m")) {
      if (RSTART > 1) out(substr(s, 1, RSTART - 1))
      n = split(substr(s, RSTART + 2, RLENGTH - 3), codes, ";")
      for (k = 1; k <= n; k++) {
        if (codes[k] == 0)  { bold = 0; dim = 0; colour = "" }
        if (codes[k] == 1)  bold = 1
        if (codes[k] == 2)  dim = 1
        if (codes[k] == 31) colour = "r"
        if (codes[k] == 32) colour = "g"
        if (codes[k] == 33) colour = "y"
        if (codes[k] == 36) colour = "c"
      }
      s = substr(s, RSTART + RLENGTH)
    }
    if (s != "") out(s)
    print "</text>"
  }
  print "</svg>"
}
function out(t,   c) {
  c = cls()
  if (c == "") printf "%s", xml(t)
  else printf "<tspan class=\"%s\">%s</tspan>", c, xml(t)
}
