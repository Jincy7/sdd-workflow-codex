#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");
const { spawnSync } = require("child_process");

const DEFAULT_OUTPUT = path.join(".sdd-control", "previews", "latest.html");
const ARTIFACT_DIRS = [
  { parts: [".planning", "phases"], source: "gsd" },
  { parts: ["docs", "superpowers", "specs"], source: "superpowers" },
  { parts: ["docs", "superpowers", "plans"], source: "superpowers" },
];

function usage() {
  console.log(`usage: scripts/sdd-control-plane.sh preview [path] [--output FILE] [--open]

Generate a local HTML tree preview from GSD and Superpowers planning artifacts.

Options:
  --output FILE   write preview to FILE instead of .sdd-control/previews/latest.html
  --open          open the generated HTML file with the OS default browser
`);
}

function die(message) {
  console.error(`error: ${message}`);
  process.exit(1);
}

function parseArgs(argv) {
  let target = ".";
  let output = "";
  let open = false;
  let sawTarget = false;

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === "-h" || arg === "--help" || arg === "help") {
      usage();
      process.exit(0);
    }
    if (arg === "--output") {
      output = argv[index + 1] || die("missing value for --output");
      index += 1;
      continue;
    }
    if (arg === "--open") {
      open = true;
      continue;
    }
    if (arg.startsWith("-")) {
      die(`unknown option: ${arg}`);
    }
    if (sawTarget) {
      die(`unexpected positional argument: ${arg}`);
    }
    target = arg;
    sawTarget = true;
  }

  return { target, output, open };
}

function escapeHtml(value) {
  return String(value)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function slug(value) {
  return String(value)
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 80);
}

function stripMarkdown(value) {
  return String(value)
    .replace(/`([^`]+)`/g, "$1")
    .replace(/\*\*([^*]+)\*\*/g, "$1")
    .replace(/\*([^*]+)\*/g, "$1")
    .replace(/\[([^\]]+)\]\([^)]+\)/g, "$1")
    .trim();
}

function compactText(value) {
  return stripMarkdown(value).replace(/\s+/g, " ").trim();
}

function readText(file) {
  return fs.readFileSync(file, "utf8").replace(/\r\n/g, "\n");
}

function existsDir(dir) {
  try {
    return fs.statSync(dir).isDirectory();
  } catch {
    return false;
  }
}

function walkMarkdown(dir, files = [], predicate = () => true) {
  if (!existsDir(dir)) return files;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      walkMarkdown(full, files, predicate);
    } else if (entry.isFile() && entry.name.endsWith(".md") && predicate(full)) {
      files.push(full);
    }
  }
  return files;
}

function discoverArtifacts(targetDir) {
  const files = [];
  for (const artifactDir of ARTIFACT_DIRS) {
    const dir = path.join(targetDir, ...artifactDir.parts);
    walkMarkdown(dir, files, (file) => {
      if (artifactDir.source !== "gsd") return true;
      return /(?:SPEC|UI-SPEC|PLAN)\.md$/i.test(path.basename(file));
    });
  }
  return [...new Set(files)].sort((a, b) =>
    path.relative(targetDir, a).localeCompare(path.relative(targetDir, b)),
  );
}

function parseFrontmatter(text) {
  if (!text.startsWith("---\n")) {
    return { metadata: {}, body: text };
  }

  const end = text.indexOf("\n---", 4);
  if (end === -1) {
    return { metadata: {}, body: text };
  }

  const raw = text.slice(4, end).split("\n");
  const metadata = {};
  let currentKey = "";

  for (const line of raw) {
    const listMatch = line.match(/^\s+-\s+(.*)$/);
    if (listMatch && currentKey) {
      if (!Array.isArray(metadata[currentKey])) metadata[currentKey] = [];
      metadata[currentKey].push(cleanYamlValue(listMatch[1]));
      continue;
    }

    const keyMatch = line.match(/^([A-Za-z0-9_-]+):\s*(.*)$/);
    if (keyMatch) {
      currentKey = keyMatch[1];
      const value = cleanYamlValue(keyMatch[2]);
      metadata[currentKey] = value === "" ? [] : value;
    }
  }

  return {
    metadata,
    body: text.slice(end + "\n---".length).replace(/^\n+/, ""),
  };
}

function cleanYamlValue(value) {
  const trimmed = String(value || "").trim();
  if (
    (trimmed.startsWith('"') && trimmed.endsWith('"')) ||
    (trimmed.startsWith("'") && trimmed.endsWith("'"))
  ) {
    return trimmed.slice(1, -1);
  }
  return trimmed;
}

function firstMatch(text, regex) {
  const match = text.match(regex);
  return match ? compactText(match[1]) : "";
}

function classifyArtifact(relativePath) {
  if (relativePath.startsWith(".planning/phases/")) {
    if (/UI-SPEC\.md$/i.test(relativePath)) return { group: "GSD", kind: "UI Spec" };
    if (/SPEC\.md$/i.test(relativePath)) return { group: "GSD", kind: "Spec" };
    if (/PLAN\.md$/i.test(relativePath)) return { group: "GSD", kind: "Plan" };
    return { group: "GSD", kind: "Artifact" };
  }
  if (relativePath.startsWith("docs/superpowers/specs/")) {
    return { group: "Superpowers", kind: "Spec" };
  }
  if (relativePath.startsWith("docs/superpowers/plans/")) {
    return { group: "Superpowers", kind: "Plan" };
  }
  return { group: "Other", kind: "Artifact" };
}

function extractTitle(body, file) {
  return firstMatch(body, /^#\s+(.+)$/m) || path.basename(file, ".md");
}

function extractSummary(body) {
  const goal = body.match(/(?:^|\n)##\s+Goal\s*\n+([\s\S]*?)(?=\n##\s+|\n#\s+|$)/i);
  if (goal) return firstParagraph(goal[1]);

  const boldGoal = firstMatch(body, /^\*\*Goal:\*\*\s*(.+)$/m);
  if (boldGoal) return boldGoal;

  const purpose = body.match(/(?:^|\n)##\s+Purpose\s*\n+([\s\S]*?)(?=\n##\s+|\n#\s+|$)/i);
  if (purpose) return firstParagraph(purpose[1]);

  return "";
}

function firstParagraph(value) {
  const paragraph = String(value)
    .split(/\n\s*\n/)
    .map((part) => compactText(part))
    .find(Boolean);
  return paragraph || "";
}

function makeNode(label, detail = "", children = [], className = "") {
  return { label: compactText(label), detail: compactText(detail), children, className };
}

function metadataNodes(metadata) {
  const keys = Object.keys(metadata).filter((key) => {
    const value = metadata[key];
    return Array.isArray(value) ? value.length > 0 : String(value || "").trim() !== "";
  });
  if (!keys.length) return [];

  return [
    makeNode(
      "Metadata",
      "",
      keys.map((key) => {
        const value = metadata[key];
        if (Array.isArray(value)) {
          return makeNode(key, `${value.length} item(s)`, value.map((item) => makeNode(item)));
        }
        return makeNode(key, value);
      }),
      "metadata",
    ),
  ];
}

function parseMarkdownOutline(body) {
  const root = [];
  const stack = [{ level: 1, children: root }];
  const lines = body.split("\n");
  let current = null;

  for (const line of lines) {
    const heading = line.match(/^(#{2,4})\s+(.+)$/);
    if (heading) {
      const level = heading[1].length;
      const node = makeNode(heading[2], "", [], "section");
      while (stack.length > 1 && stack[stack.length - 1].level >= level) {
        stack.pop();
      }
      stack[stack.length - 1].children.push(node);
      stack.push({ level, children: node.children });
      current = node;
      continue;
    }

    if (!current) continue;

    const checkbox = line.match(/^\s*-\s+\[([ xX])\]\s+(.+)$/);
    if (checkbox) {
      current.children.push(
        makeNode(checkbox[2], checkbox[1].toLowerCase() === "x" ? "done" : "open", [], "check"),
      );
      continue;
    }

    const orderedBold = line.match(/^\s*\d+\.\s+\*\*([^*]+)\*\*:?\s*(.*)$/);
    if (orderedBold) {
      current.children.push(makeNode(orderedBold[1], orderedBold[2], [], "requirement"));
      continue;
    }

    const bulletBold = line.match(/^\s*-\s+\*\*([^*]+)\*\*:?\s*(.*)$/);
    if (bulletBold) {
      current.children.push(makeNode(bulletBold[1], bulletBold[2], [], "item"));
      continue;
    }

    const bullet = line.match(/^\s*-\s+(.+)$/);
    if (bullet && current.label.match(/criteria|requirements|tasks|files|non-goals|boundaries|decisions/i)) {
      current.children.push(makeNode(bullet[1], "", [], "item"));
      continue;
    }
  }

  return root.filter((node) => node.children.length || importantSection(node.label));
}

function importantSection(label) {
  return /goal|purpose|requirement|acceptance|task|plan|decision|boundary|scope|verification|success|file/i.test(label);
}

function tagText(block, tag) {
  const escaped = tag.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const match = block.match(new RegExp(`<${escaped}[^>]*>([\\s\\S]*?)<\\/${escaped}>`, "i"));
  return match ? match[1].trim() : "";
}

function parseListText(value) {
  return String(value)
    .split("\n")
    .map((line) => line.replace(/^\s*-\s+/, "").trim())
    .filter(Boolean);
}

function parseXmlTasks(body) {
  const taskBlocks = [...body.matchAll(/<task\b[^>]*>([\s\S]*?)<\/task>/gi)];
  if (!taskBlocks.length) return [];

  const tasks = taskBlocks.map((match) => {
    const block = match[1];
    const children = [];
    const files = parseListText(tagText(block, "files"));
    const verify = tagText(block, "verify");
    const acceptance = parseListText(tagText(block, "acceptance_criteria"));
    const done = tagText(block, "done");

    if (files.length) {
      children.push(makeNode("Files", `${files.length} item(s)`, files.map((item) => makeNode(item))));
    }
    if (verify) {
      children.push(makeNode("Verify", compactText(verify)));
    }
    if (acceptance.length) {
      children.push(
        makeNode(
          "Acceptance criteria",
          `${acceptance.length} item(s)`,
          acceptance.map((item) => makeNode(item)),
        ),
      );
    }
    if (done) {
      children.push(makeNode("Done", compactText(done)));
    }

    return makeNode(tagText(block, "name") || "Unnamed task", "", children, "task");
  });

  return [makeNode("Execution Tasks", `${tasks.length} task(s)`, tasks, "tasks")];
}

function parseXmlSections(body) {
  const sections = [];
  const objective = tagText(body, "objective");
  const verification = tagText(body, "verification");
  const success = tagText(body, "success_criteria");

  if (objective) {
    sections.push(makeNode("Objective", firstParagraph(objective), [], "objective"));
  }
  sections.push(...parseXmlTasks(body));
  if (verification) {
    const items = parseListText(verification);
    sections.push(makeNode("Verification", `${items.length} item(s)`, items.map((item) => makeNode(item))));
  }
  if (success) {
    const items = parseListText(success);
    sections.push(makeNode("Success Criteria", `${items.length} item(s)`, items.map((item) => makeNode(item))));
  }

  return sections;
}

function parseDocument(file, targetDir) {
  const relativePath = path.relative(targetDir, file);
  const text = readText(file);
  const parsed = parseFrontmatter(text);
  const classification = classifyArtifact(relativePath);
  const title = extractTitle(parsed.body, file);
  const summary = extractSummary(parsed.body);
  const created =
    parsed.metadata.created ||
    parsed.metadata.Created ||
    firstMatch(parsed.body, /^\*\*Created:\*\*\s*(.+)$/m) ||
    firstMatch(parsed.body, /^Date:\s*(.+)$/m);
  const children = [
    ...metadataNodes(parsed.metadata),
    ...parseXmlSections(parsed.body),
    ...parseMarkdownOutline(parsed.body),
  ];

  return {
    file,
    relativePath,
    title,
    summary,
    created,
    group: classification.group,
    kind: classification.kind,
    children,
  };
}

function documentScore(doc) {
  const order = { GSD: 0, Superpowers: 1, Other: 2 };
  const kindOrder = { Spec: 0, "UI Spec": 1, Plan: 2, Artifact: 3 };
  return `${order[doc.group] ?? 9}-${kindOrder[doc.kind] ?? 9}-${doc.relativePath}`;
}

function renderNode(node) {
  const childHtml = node.children && node.children.length
    ? `<ul>${node.children.map(renderNode).join("")}</ul>`
    : "";
  const detail = node.detail ? `<span class="detail">${escapeHtml(node.detail)}</span>` : "";
  const className = node.className ? ` ${escapeHtml(node.className)}` : "";

  if (childHtml) {
    return `<li class="node${className}"><details open><summary><span>${escapeHtml(node.label)}</span>${detail}</summary>${childHtml}</details></li>`;
  }

  return `<li class="leaf${className}"><span>${escapeHtml(node.label)}</span>${detail}</li>`;
}

function renderDocument(doc, index) {
  const id = `doc-${index}-${slug(doc.relativePath)}`;
  const children = doc.children.length
    ? `<ul class="tree">${doc.children.map(renderNode).join("")}</ul>`
    : `<p class="empty">No outline items found. The source file is still linked for review.</p>`;
  const summary = doc.summary ? `<p class="doc-summary">${escapeHtml(doc.summary)}</p>` : "";
  const created = doc.created ? `<span>${escapeHtml(doc.created)}</span>` : "";

  return `<article class="document" id="${id}">
  <details open>
    <summary>
      <span class="kind">${escapeHtml(doc.group)} ${escapeHtml(doc.kind)}</span>
      <span class="title">${escapeHtml(doc.title)}</span>
      <span class="path">${escapeHtml(doc.relativePath)}</span>
    </summary>
    <div class="doc-body">
      <div class="doc-meta">${created}<span>${doc.children.length} top-level item(s)</span></div>
      ${summary}
      ${children}
    </div>
  </details>
</article>`;
}

function renderSidebar(documents) {
  const items = documents
    .map((doc, index) => {
      const id = `doc-${index}-${slug(doc.relativePath)}`;
      return `<a href="#${id}"><span>${escapeHtml(doc.group)} ${escapeHtml(doc.kind)}</span><strong>${escapeHtml(doc.title)}</strong></a>`;
    })
    .join("");
  return `<nav class="sidebar" aria-label="Planning artifacts">${items}</nav>`;
}

function graphKind(value) {
  const raw = String(value || "item").toLowerCase();
  if (raw.includes("task")) return "task";
  if (raw.includes("requirement")) return "requirement";
  if (raw.includes("check")) return "check";
  if (raw.includes("metadata")) return "metadata";
  if (raw.includes("objective")) return "objective";
  if (raw.includes("section")) return "section";
  return raw.replace(/[^a-z0-9_-]+/g, "-") || "item";
}

function shortLabel(value, max = 72) {
  const text = compactText(value);
  return text.length > max ? `${text.slice(0, max - 1)}...` : text;
}

function buildGraph(documents) {
  const nodes = [
    {
      data: {
        id: "root",
        label: "SDD Planning Preview",
        fullLabel: "SDD Planning Preview",
        detail: `${documents.length} artifact(s)`,
        kind: "root",
        depth: 0,
      },
    },
  ];
  const edges = [];
  let sequence = 0;

  function addNode(parentId, node, depth, docId, pathParts) {
    const id = `n${sequence++}`;
    const kind = graphKind(node.className || "item");
    const fullLabel = node.label || "Untitled";
    const nextPath = [...pathParts, fullLabel];
    nodes.push({
      data: {
        id,
        label: shortLabel(fullLabel),
        fullLabel,
        detail: node.detail || "",
        kind,
        depth,
        docId,
        path: nextPath.join(" / "),
      },
    });
    edges.push({
      data: {
        id: `e-${parentId}-${id}`,
        source: parentId,
        target: id,
      },
    });
    for (const child of node.children || []) {
      addNode(id, child, depth + 1, docId, nextPath);
    }
  }

  documents.forEach((doc, index) => {
    const docId = `doc-${index}-${slug(doc.relativePath)}`;
    const nodeId = `docnode-${index}`;
    nodes.push({
      data: {
        id: nodeId,
        label: shortLabel(doc.title, 64),
        fullLabel: doc.title,
        detail: `${doc.group} ${doc.kind}`,
        kind: "document",
        depth: 1,
        docId,
        path: doc.relativePath,
      },
    });
    edges.push({
      data: {
        id: `e-root-${nodeId}`,
        source: "root",
        target: nodeId,
      },
    });

    for (const child of doc.children || []) {
      addNode(nodeId, child, 2, docId, [doc.title]);
    }
  });

  return { nodes, edges };
}

function scriptJson(value) {
  return JSON.stringify(value)
    .replace(/</g, "\\u003c")
    .replace(/>/g, "\\u003e")
    .replace(/&/g, "\\u0026")
    .replace(/\u2028/g, "\\u2028")
    .replace(/\u2029/g, "\\u2029");
}

function renderGraphPanel(graph) {
  return `<section class="graph-panel" aria-label="Graph tree preview">
    <div class="graph-toolbar">
      <div>
        <h2>Graph Tree</h2>
        <p>${graph.nodes.length} nodes / ${graph.edges.length} edges</p>
      </div>
      <div class="graph-actions">
        <button type="button" id="reset-overview">Overview</button>
        <button type="button" id="collapse-all">Collapse All</button>
        <button type="button" id="expand-all">Expand All</button>
        <button type="button" id="layout-tb">Top Down</button>
        <button type="button" id="layout-lr">Left Right</button>
        <button type="button" id="fit-graph">Fit</button>
        <button type="button" id="full-view">Full View</button>
      </div>
    </div>
    <div class="graph-grid">
      <div id="cy" role="img" aria-label="Interactive planning graph"></div>
      <aside class="graph-inspector" id="node-details" aria-live="polite">
        <span class="inspector-kind">Node</span>
        <strong>Select a node</strong>
        <p>Click a graph node to highlight its subtree and jump to the source document.</p>
        <div class="inspector-actions">
          <button type="button" id="expand-node">Expand</button>
          <button type="button" id="collapse-node">Collapse</button>
          <button type="button" id="focus-node">Focus</button>
          <button type="button" id="clear-focus">Clear</button>
        </div>
      </aside>
    </div>
    <p class="graph-status" id="graph-status"></p>
  </section>`;
}

function renderHtml(targetDir, documents) {
  const now = new Date().toISOString();
  const title = "SDD Planning Preview";
  const graph = buildGraph(documents);
  const grouped = documents.reduce((acc, doc) => {
    acc[doc.group] = (acc[doc.group] || 0) + 1;
    return acc;
  }, {});
  const stats = Object.entries(grouped)
    .map(([key, count]) => `<span><strong>${count}</strong> ${escapeHtml(key)}</span>`)
    .join("");

  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${title}</title>
  <link rel="icon" href="data:,">
  <style>
    :root {
      color-scheme: light;
      --bg: #f4f6f8;
      --panel: #ffffff;
      --ink: #1d2328;
      --muted: #667078;
      --line: #d8dee4;
      --accent: #0f766e;
      --accent-2: #9f580a;
      --accent-3: #4d6f28;
      --blue: #2563eb;
      --soft: #f8fafc;
      --shadow: 0 18px 45px rgba(31, 35, 40, 0.12);
      font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      background: var(--bg);
      color: var(--ink);
      line-height: 1.5;
    }
    header {
      position: sticky;
      top: 0;
      z-index: 2;
      border-bottom: 1px solid var(--line);
      background: rgba(244, 246, 248, 0.95);
      backdrop-filter: blur(10px);
    }
    .header-inner {
      max-width: 1440px;
      margin: 0 auto;
      padding: 22px 28px;
      display: grid;
      grid-template-columns: 1fr auto;
      gap: 18px;
      align-items: end;
    }
    h1 {
      margin: 0;
      font-size: 28px;
      line-height: 1.15;
      font-weight: 760;
      letter-spacing: 0;
    }
    .subtitle {
      margin: 8px 0 0;
      color: var(--muted);
      font-size: 14px;
    }
    .stats {
      display: flex;
      flex-wrap: wrap;
      gap: 8px;
      justify-content: flex-end;
    }
    .stats span {
      border: 1px solid var(--line);
      background: var(--panel);
      padding: 7px 10px;
      font-size: 13px;
      white-space: nowrap;
    }
    .graph-panel {
      max-width: 1440px;
      margin: 28px auto 0;
      padding: 0 28px;
    }
    .graph-panel.fullscreen {
      position: fixed;
      inset: 0;
      z-index: 20;
      max-width: none;
      margin: 0;
      padding: 18px;
      background: var(--bg);
      display: grid;
      grid-template-rows: auto minmax(0, 1fr) auto;
    }
    body.graph-fullscreen {
      overflow: hidden;
    }
    .graph-toolbar {
      display: grid;
      grid-template-columns: minmax(0, 1fr) auto;
      gap: 18px;
      align-items: end;
      padding: 16px 18px;
      border: 1px solid var(--line);
      border-bottom: 0;
      background: var(--panel);
      box-shadow: var(--shadow);
    }
    .graph-toolbar h2 {
      margin: 0;
      font-size: 20px;
      line-height: 1.2;
      letter-spacing: 0;
    }
    .graph-toolbar p {
      margin: 5px 0 0;
      color: var(--muted);
      font-size: 13px;
    }
    .graph-actions {
      display: flex;
      flex-wrap: wrap;
      gap: 8px;
      justify-content: flex-end;
    }
    .graph-actions button,
    .inspector-actions button {
      appearance: none;
      border: 1px solid var(--line);
      background: var(--soft);
      color: var(--ink);
      padding: 8px 10px;
      min-height: 36px;
      font: inherit;
      font-size: 13px;
      cursor: pointer;
    }
    .graph-actions button:hover,
    .inspector-actions button:hover {
      border-color: var(--accent);
      color: var(--accent);
    }
    .graph-grid {
      display: grid;
      grid-template-columns: minmax(0, 1fr) minmax(220px, 300px);
      border: 1px solid var(--line);
      background: var(--panel);
      box-shadow: var(--shadow);
    }
    .fullscreen .graph-grid {
      min-height: 0;
    }
    #cy {
      width: 100%;
      height: 680px;
      min-height: 420px;
      background:
        linear-gradient(rgba(216, 222, 228, 0.35) 1px, transparent 1px),
        linear-gradient(90deg, rgba(216, 222, 228, 0.35) 1px, transparent 1px),
        #ffffff;
      background-size: 28px 28px;
    }
    .fullscreen #cy {
      height: 100%;
      min-height: 0;
    }
    .graph-inspector {
      border-left: 1px solid var(--line);
      padding: 16px;
      background: var(--soft);
      min-width: 0;
    }
    .graph-inspector strong {
      display: block;
      margin-top: 8px;
      font-size: 16px;
      line-height: 1.3;
      overflow-wrap: anywhere;
    }
    .graph-inspector p {
      margin: 8px 0 0;
      color: var(--muted);
      font-size: 13px;
      overflow-wrap: anywhere;
    }
    .inspector-kind {
      display: inline-flex;
      border: 1px solid var(--line);
      background: var(--panel);
      color: var(--accent);
      padding: 4px 7px;
      font-size: 11px;
      font-weight: 740;
      text-transform: uppercase;
      letter-spacing: 0.06em;
    }
    .inspector-actions {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 8px;
      margin-top: 14px;
    }
    .inspector-actions button {
      width: 100%;
    }
    .graph-status {
      min-height: 22px;
      margin: 8px 0 0;
      color: var(--muted);
      font-size: 12px;
    }
    main {
      max-width: 1440px;
      margin: 0 auto;
      padding: 28px;
      display: grid;
      grid-template-columns: minmax(220px, 280px) minmax(0, 1fr);
      gap: 22px;
    }
    .sidebar {
      position: sticky;
      top: 104px;
      align-self: start;
      display: grid;
      gap: 8px;
    }
    .sidebar a {
      display: grid;
      gap: 3px;
      padding: 10px 12px;
      color: var(--ink);
      text-decoration: none;
      border-left: 3px solid var(--accent);
      background: rgba(255, 255, 255, 0.75);
    }
    .sidebar span {
      color: var(--muted);
      font-size: 11px;
      text-transform: uppercase;
      letter-spacing: 0.06em;
    }
    .sidebar strong {
      font-size: 13px;
      font-weight: 650;
    }
    .content {
      display: grid;
      gap: 14px;
      min-width: 0;
    }
    .document {
      border: 1px solid var(--line);
      background: var(--panel);
      box-shadow: var(--shadow);
    }
    .document.document-highlight {
      outline: 3px solid rgba(37, 99, 235, 0.24);
      outline-offset: 2px;
    }
    .document > details > summary {
      list-style: none;
      cursor: pointer;
      padding: 16px 18px;
      display: grid;
      grid-template-columns: auto minmax(0, 1fr);
      gap: 5px 12px;
      align-items: center;
      border-bottom: 1px solid var(--line);
    }
    .document > details > summary::-webkit-details-marker { display: none; }
    .kind {
      grid-row: span 2;
      align-self: center;
      color: #fff;
      background: var(--accent);
      padding: 5px 8px;
      font-size: 12px;
      font-weight: 700;
      white-space: nowrap;
    }
    .title {
      font-size: 18px;
      font-weight: 760;
      min-width: 0;
      overflow-wrap: anywhere;
    }
    .path {
      color: var(--muted);
      font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
      font-size: 12px;
      overflow-wrap: anywhere;
    }
    .doc-body {
      padding: 16px 18px 20px;
    }
    .doc-meta {
      display: flex;
      flex-wrap: wrap;
      gap: 8px;
      color: var(--muted);
      font-size: 12px;
    }
    .doc-meta span {
      border: 1px solid var(--line);
      padding: 4px 7px;
      background: var(--soft);
    }
    .doc-summary {
      max-width: 900px;
      margin: 12px 0 4px;
      color: #374148;
      font-size: 14px;
    }
    ul {
      list-style: none;
      margin: 0;
      padding: 0;
    }
    .tree {
      margin-top: 14px;
      display: grid;
      gap: 7px;
    }
    .tree ul {
      margin-left: 18px;
      padding-left: 14px;
      border-left: 1px solid var(--line);
      display: grid;
      gap: 6px;
    }
    .node > details > summary {
      cursor: pointer;
      display: flex;
      flex-wrap: wrap;
      gap: 8px;
      align-items: baseline;
      min-height: 30px;
      padding: 4px 0;
      color: var(--ink);
      font-weight: 680;
    }
    .leaf {
      position: relative;
      display: flex;
      flex-wrap: wrap;
      gap: 8px;
      min-height: 28px;
      align-items: baseline;
      padding: 4px 0 4px 16px;
      color: #2c343a;
    }
    .leaf::before {
      content: "";
      position: absolute;
      left: 0;
      top: 15px;
      width: 7px;
      border-top: 1px solid var(--line);
    }
    .detail {
      color: var(--muted);
      font-size: 12px;
      font-weight: 500;
      overflow-wrap: anywhere;
    }
    .requirement > span:first-child,
    .task > details > summary span:first-child {
      color: var(--accent-2);
    }
    .check .detail {
      color: var(--accent-3);
      font-weight: 700;
    }
    .empty {
      margin: 14px 0 0;
      color: var(--muted);
      font-size: 14px;
    }
    footer {
      max-width: 1440px;
      margin: 0 auto;
      padding: 0 28px 36px;
      color: var(--muted);
      font-size: 12px;
    }
    .back-to-graph {
      position: fixed;
      right: 24px;
      bottom: 24px;
      z-index: 15;
      border: 1px solid var(--accent);
      background: var(--accent);
      color: #ffffff;
      padding: 12px 14px;
      min-height: 44px;
      box-shadow: var(--shadow);
      font: inherit;
      font-size: 13px;
      font-weight: 740;
      cursor: pointer;
    }
    .back-to-graph:hover {
      background: #0b5f59;
      border-color: #0b5f59;
    }
    @media (max-width: 860px) {
      .header-inner,
      main,
      .graph-toolbar,
      .graph-grid {
        grid-template-columns: 1fr;
      }
      .stats {
        justify-content: flex-start;
      }
      .sidebar {
        position: static;
      }
      .graph-inspector {
        border-left: 0;
        border-top: 1px solid var(--line);
      }
      #cy {
        height: 560px;
      }
    }
  </style>
</head>
<body>
  <header>
    <div class="header-inner">
      <div>
        <h1>${title}</h1>
        <p class="subtitle">${escapeHtml(path.basename(targetDir))} - ${documents.length} planning artifact(s) rendered as an interactive graph and review tree.</p>
      </div>
      <div class="stats">${stats}</div>
    </div>
  </header>
  ${renderGraphPanel(graph)}
  <main>
    ${renderSidebar(documents)}
    <section class="content" aria-label="Preview documents">
      ${documents.map(renderDocument).join("\n")}
    </section>
  </main>
  <footer>Generated ${escapeHtml(now)} from ${escapeHtml(targetDir)}.</footer>
  <button type="button" id="back-to-graph" class="back-to-graph">Graph</button>
  <script src="https://cdn.jsdelivr.net/npm/cytoscape@3.33.3/dist/cytoscape.min.js"></script>
  <script src="https://cdn.jsdelivr.net/npm/dagre@0.8.5/dist/dagre.min.js"></script>
  <script src="https://cdn.jsdelivr.net/npm/cytoscape-dagre@2.5.0/cytoscape-dagre.js"></script>
  <script>
    const PREVIEW_GRAPH = ${scriptJson(graph)};

    (function () {
      const container = document.getElementById("cy");
      const details = document.getElementById("node-details");
      const status = document.getElementById("graph-status");
      const fitButton = document.getElementById("fit-graph");
      const topDownButton = document.getElementById("layout-tb");
      const leftRightButton = document.getElementById("layout-lr");
      const resetOverviewButton = document.getElementById("reset-overview");
      const collapseAllButton = document.getElementById("collapse-all");
      const expandAllButton = document.getElementById("expand-all");
      const fullViewButton = document.getElementById("full-view");
      const backToGraphButton = document.getElementById("back-to-graph");
      const graphPanel = document.querySelector(".graph-panel");
      const nodesById = new Map(PREVIEW_GRAPH.nodes.map((entry) => [entry.data.id, entry]));
      const childrenByParent = new Map();
      const parentByChild = new Map();
      PREVIEW_GRAPH.edges.forEach((edge) => {
        const source = edge.data.source;
        const target = edge.data.target;
        if (!childrenByParent.has(source)) childrenByParent.set(source, []);
        childrenByParent.get(source).push(target);
        parentByChild.set(target, source);
      });
      const nodesWithChildren = new Set(childrenByParent.keys());
      let cy = null;
      let hasDagreLayout = false;
      let collapsedNodeIds = new Set();
      let focusedRootId = "root";
      let selectedNodeId = null;
      let currentRankDir = "LR";

      function setStatus(message) {
        if (status) status.textContent = message || "";
      }

      function appendText(parent, tagName, text, className) {
        const el = document.createElement(tagName);
        if (className) el.className = className;
        el.textContent = text || "";
        parent.appendChild(el);
        return el;
      }

      function makeInspectorButton(id, label) {
        const button = document.createElement("button");
        button.type = "button";
        button.id = id;
        button.textContent = label;
        return button;
      }

      function renderInspectorActions(parent) {
        const actions = document.createElement("div");
        actions.className = "inspector-actions";
        actions.appendChild(makeInspectorButton("expand-node", "Expand"));
        actions.appendChild(makeInspectorButton("collapse-node", "Collapse"));
        actions.appendChild(makeInspectorButton("focus-node", "Focus"));
        actions.appendChild(makeInspectorButton("go-document", "Move"));
        actions.appendChild(makeInspectorButton("clear-focus", "Clear"));
        parent.appendChild(actions);
      }

      function setRootDepthState(maxDepth = 1) {
        focusedRootId = "root";
        collapsedNodeIds = new Set(
          Array.from(nodesWithChildren).filter((id) => {
            const depth = nodesById.get(id)?.data?.depth || 0;
            return depth >= maxDepth;
          }),
        );
      }

      function setOverviewState() {
        setRootDepthState(1);
      }

      function collectVisibleNodeIds() {
        const visible = new Set();
        const start = nodesById.has(focusedRootId) ? focusedRootId : "root";

        function walk(id) {
          visible.add(id);
          if (collapsedNodeIds.has(id)) return;
          const children = childrenByParent.get(id) || [];
          children.forEach(walk);
        }

        walk(start);
        return visible;
      }

      function visibleGraphElements() {
        const visibleNodeIds = collectVisibleNodeIds();
        const nodes = Array.from(visibleNodeIds)
          .map((id) => {
            const source = nodesById.get(id);
            if (!source) return null;
            const data = { ...source.data };
            if (nodesWithChildren.has(id)) {
              data.label = (collapsedNodeIds.has(id) ? "▸ " : "▾ ") + data.label;
            }
            return { data };
          })
          .filter(Boolean);
        const edges = PREVIEW_GRAPH.edges.filter((edge) => {
          return visibleNodeIds.has(edge.data.source) && visibleNodeIds.has(edge.data.target);
        });
        return { elements: nodes.concat(edges), visibleCount: visibleNodeIds.size };
      }

      function layoutConfig(rankDir) {
        if (hasDagreLayout) {
          return {
            name: "dagre",
            rankDir: rankDir,
            nodeSep: 42,
            rankSep: 92,
            edgeSep: 18,
            padding: 40,
          };
        }
        return {
          name: "breadthfirst",
          directed: true,
          padding: 40,
          spacingFactor: 1.25,
        };
      }

      function runLayout(rankDir, fitAfter = true) {
        if (!cy) return;
        currentRankDir = rankDir;
        cy.layout(layoutConfig(rankDir)).run();
        if (fitAfter) {
          window.setTimeout(() => {
            cy.resize();
            cy.fit(undefined, 44);
          }, 30);
        }
      }

      function applyVisibleGraph(fitAfter = true) {
        if (!cy) return;
        const visible = visibleGraphElements();
        cy.elements().remove();
        cy.add(visible.elements);
        runLayout(currentRankDir, fitAfter);
        if (selectedNodeId && cy.getElementById(selectedNodeId).length) {
          selectGraphNode(cy.getElementById(selectedNodeId), false);
        }
        setStatus("Showing " + visible.visibleCount + " of " + PREVIEW_GRAPH.nodes.length + " nodes. Double-click a node to expand or collapse it.");
      }

      function clearDocumentHighlight() {
        document.querySelectorAll(".document-highlight").forEach((el) => {
          el.classList.remove("document-highlight");
        });
      }

      function updateDetails(data) {
        if (!details) return;
        details.textContent = "";
        appendText(details, "span", data.kind || "node", "inspector-kind");
        appendText(details, "strong", data.fullLabel || data.label || data.id);
        if (data.detail) appendText(details, "p", data.detail);
        if (data.path) appendText(details, "p", data.path);
        renderInspectorActions(details);
      }

      function selectGraphNode(node, highlightDocument = true) {
        selectedNodeId = node.id();
        const subtree = node.union(node.successors());
        cy.elements().removeClass("active dimmed");
        cy.elements().not(subtree).addClass("dimmed");
        subtree.addClass("active");
        updateDetails(node.data());

        clearDocumentHighlight();
        const docId = node.data("docId");
        if (docId && highlightDocument) {
          const doc = document.getElementById(docId);
          if (doc) doc.classList.add("document-highlight");
        }
      }

      function scrollToSelectedDocument() {
        if (!selectedNodeId) return;
        const data = nodesById.get(selectedNodeId)?.data;
        const docId = data?.docId;
        if (!docId) return;
        const doc = document.getElementById(docId);
        if (!doc) return;
        clearDocumentHighlight();
        doc.classList.add("document-highlight");
        doc.scrollIntoView({ block: "start", behavior: "smooth" });
      }

      function toggleNodeCollapse(id) {
        if (!nodesWithChildren.has(id)) return;
        if (collapsedNodeIds.has(id)) {
          collapsedNodeIds.delete(id);
        } else {
          collapsedNodeIds.add(id);
        }
        selectedNodeId = id;
        applyVisibleGraph(true);
      }

      function expandSelectedNodeOneLevel() {
        if (!selectedNodeId || !nodesWithChildren.has(selectedNodeId)) return;

        if (collapsedNodeIds.has(selectedNodeId)) {
          collapsedNodeIds.delete(selectedNodeId);
        } else {
          const directChildren = childrenByParent.get(selectedNodeId) || [];
          directChildren
            .filter((id) => nodesWithChildren.has(id))
            .forEach((id) => collapsedNodeIds.delete(id));
        }

        applyVisibleGraph(true);
      }

      function collapseSelectedNodeOneLevel() {
        if (!selectedNodeId || !nodesWithChildren.has(selectedNodeId)) return;

        const directChildren = childrenByParent.get(selectedNodeId) || [];
        const expandedChildren = directChildren.filter((id) => {
          return nodesWithChildren.has(id) && !collapsedNodeIds.has(id);
        });

        if (expandedChildren.length) {
          expandedChildren.forEach((id) => collapsedNodeIds.add(id));
        } else {
          collapsedNodeIds.add(selectedNodeId);
        }

        applyVisibleGraph(true);
      }

      function focusSelectedNode() {
        if (!selectedNodeId || !nodesById.has(selectedNodeId)) return;
        focusedRootId = selectedNodeId;
        collapsedNodeIds.delete(selectedNodeId);
        applyVisibleGraph(true);
      }

      function clearFocus() {
        focusedRootId = "root";
        applyVisibleGraph(true);
      }

      function toggleFullView() {
        if (!graphPanel) return;
        graphPanel.classList.toggle("fullscreen");
        document.body.classList.toggle("graph-fullscreen", graphPanel.classList.contains("fullscreen"));
        if (fullViewButton) {
          fullViewButton.textContent = graphPanel.classList.contains("fullscreen") ? "Exit Full View" : "Full View";
        }
        window.setTimeout(() => {
          if (!cy) return;
          cy.resize();
          cy.fit(undefined, 44);
        }, 80);
      }

      function renderGraph() {
        if (!container) return;
        if (!window.cytoscape) {
          setStatus("Cytoscape CDN did not load. The text tree below is still available.");
          return;
        }
        if (window.cytoscapeDagre) {
          window.cytoscape.use(window.cytoscapeDagre);
          hasDagreLayout = true;
        }

        cy = window.cytoscape({
          container,
          elements: [],
          style: [
            {
              selector: "node",
              style: {
                label: "data(label)",
                width: 170,
                height: 52,
                padding: "10px",
                shape: "round-rectangle",
                "text-valign": "center",
                "text-halign": "center",
                "text-wrap": "wrap",
                "text-max-width": "170px",
                "font-size": "12px",
                "font-weight": 600,
                "background-color": "#e0f2fe",
                "background-opacity": 0.95,
                "border-color": "#2563eb",
                "border-width": 1,
                color: "#1d2328",
              },
            },
            {
              selector: 'node[kind = "root"]',
              style: {
                "background-color": "#0f766e",
                "border-color": "#0f766e",
                color: "#ffffff",
                "font-size": "14px",
              },
            },
            {
              selector: 'node[kind = "document"]',
              style: {
                "background-color": "#fef3c7",
                "border-color": "#d97706",
              },
            },
            {
              selector: 'node[kind = "task"], node[kind = "requirement"]',
              style: {
                "background-color": "#dcfce7",
                "border-color": "#16a34a",
              },
            },
            {
              selector: 'node[kind = "metadata"]',
              style: {
                "background-color": "#f1f5f9",
                "border-color": "#64748b",
              },
            },
            {
              selector: "edge",
              style: {
                width: 1.4,
                "line-color": "#94a3b8",
                "target-arrow-color": "#94a3b8",
                "target-arrow-shape": "triangle",
                "curve-style": "bezier",
              },
            },
            {
              selector: ".dimmed",
              style: {
                opacity: 0.16,
              },
            },
            {
              selector: "node.active",
              style: {
                "border-width": 3,
                "border-color": "#2563eb",
                "z-index": 20,
              },
            },
            {
              selector: "edge.active",
              style: {
                width: 2.5,
                "line-color": "#2563eb",
                "target-arrow-color": "#2563eb",
                opacity: 1,
              },
            },
          ],
          layout: layoutConfig(currentRankDir),
        });

        cy.on("tap", "node", (event) => {
          selectGraphNode(event.target, false);
        });
        cy.on("dbltap", "node", (event) => {
          toggleNodeCollapse(event.target.id());
        });
        cy.on("tap", (event) => {
          if (event.target === cy) {
            selectedNodeId = null;
            cy.elements().removeClass("active dimmed");
            clearDocumentHighlight();
            updateDetails({ kind: "graph", fullLabel: "Planning graph", detail: PREVIEW_GRAPH.nodes.length + " nodes / " + PREVIEW_GRAPH.edges.length + " edges" });
          }
        });

        setOverviewState();
        updateDetails({ kind: "graph", fullLabel: "Planning graph", detail: PREVIEW_GRAPH.nodes.length + " nodes / " + PREVIEW_GRAPH.edges.length + " edges" });
        applyVisibleGraph(true);
      }

      if (fitButton) fitButton.addEventListener("click", () => cy && cy.fit(undefined, 40));
      if (topDownButton) topDownButton.addEventListener("click", () => runLayout("TB"));
      if (leftRightButton) leftRightButton.addEventListener("click", () => runLayout("LR"));
      if (resetOverviewButton) resetOverviewButton.addEventListener("click", () => {
        selectedNodeId = null;
        setOverviewState();
        applyVisibleGraph(true);
      });
      if (collapseAllButton) collapseAllButton.addEventListener("click", () => {
        focusedRootId = "root";
        collapsedNodeIds = new Set(Array.from(nodesWithChildren).filter((id) => id !== "root"));
        applyVisibleGraph(true);
      });
      if (expandAllButton) expandAllButton.addEventListener("click", () => {
        focusedRootId = "root";
        collapsedNodeIds = new Set();
        applyVisibleGraph(true);
      });
      if (fullViewButton) fullViewButton.addEventListener("click", toggleFullView);
      if (backToGraphButton) {
        backToGraphButton.addEventListener("click", () => {
          if (!graphPanel) return;
          graphPanel.scrollIntoView({ block: "start", behavior: "smooth" });
          window.setTimeout(() => {
            if (!cy) return;
            cy.resize();
            cy.fit(undefined, 44);
          }, 120);
        });
      }
      if (details) {
        details.addEventListener("click", (event) => {
          const target = event.target;
          if (!(target instanceof HTMLElement)) return;
          if (target.id === "expand-node") expandSelectedNodeOneLevel();
          if (target.id === "collapse-node") collapseSelectedNodeOneLevel();
          if (target.id === "focus-node") focusSelectedNode();
          if (target.id === "go-document") scrollToSelectedDocument();
          if (target.id === "clear-focus") clearFocus();
        });
      }

      renderGraph();
    })();
  </script>
</body>
</html>
`;
}

function main() {
  const options = parseArgs(process.argv.slice(2));
  const targetDir = path.resolve(options.target);
  if (!existsDir(targetDir)) die(`target directory does not exist: ${targetDir}`);

  const files = discoverArtifacts(targetDir);
  if (!files.length) {
    die("no GSD spec/plan or Superpowers planning artifacts found under .planning/phases or docs/superpowers");
  }

  const documents = files
    .map((file) => parseDocument(file, targetDir))
    .sort((a, b) => documentScore(a).localeCompare(documentScore(b)));
  const outputPath = path.resolve(targetDir, options.output || DEFAULT_OUTPUT);
  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  fs.writeFileSync(outputPath, renderHtml(targetDir, documents));

  console.log(`Wrote SDD planning preview: ${outputPath}`);
  if (options.open) {
    const result = spawnSync("open", [outputPath], { stdio: "inherit" });
    if (result.error) die(`could not open preview: ${result.error.message}`);
  }
}

main();
