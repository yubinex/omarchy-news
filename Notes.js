// A deliberately small, non-interactive Markdown renderer. Escape everything
// upstream, then emit only our own formatting: no images, links, or raw HTML.
function escape(text) {
  return text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;")
}
function inline(text) {
  return escape(text.replace(/\[([^\]]+)\]\(([^)]+)\)/g, "$1"))
    .replace(/`([^`]+)`/g, "<code>$1</code>")
    .replace(/\*\*([^*]+)\*\*/g, "<b>$1</b>")
}
function render(body) {
  var lines = (body || "No official release notes available.").replace(/\r/g, "")
    .replace(/!\[[^\]]*\]\([^\n]*\)/g, "").replace(/<img[^>]*>/gi, "").split("\n")
  var out = [], paragraph = [], list = false, code = false, codeLines = []
  function flush() {
    if (paragraph.length) { out.push("<p>" + inline(paragraph.join(" ")) + "</p>"); paragraph = [] }
    if (list) { out.push("</ul>"); list = false }
  }
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i], heading = /^(#{1,6})\s+(.+)$/.exec(line)
    if (/^\s*```/.test(line)) {
      flush()
      if (code) { out.push("<pre>" + escape(codeLines.join("\n")) + "</pre>"); codeLines = [] }
      code = !code
    } else if (code) codeLines.push(line)
    else if (!line.trim()) flush()
    else if (heading) { flush(); out.push("<h3>" + inline(heading[2]) + "</h3>") }
    else if (/^\s*[-*]\s+/.test(line)) {
      if (paragraph.length) flush()
      if (!list) { out.push("<ul>"); list = true }
      out.push("<li>" + inline(line.replace(/^\s*[-*]\s+/, "")) + "</li>")
    } else { if (list) flush(); paragraph.push(line) }
  }
  flush()
  if (codeLines.length) out.push("<pre>" + escape(codeLines.join("\n")) + "</pre>")
  return out.join("\n")
}
