import { spawn } from "node:child_process";
import {
  createReadStream,
  existsSync,
  mkdirSync,
  readdirSync,
  readFileSync,
  writeFileSync,
} from "node:fs";
import path from "node:path";

const CLICK_TYPES = new Set([
  "Button",
  "CheckBox",
  "CheckButton",
  "MenuButton",
  "OptionButton",
  "LinkButton",
  "TextureButton",
]);
const TYPE_TYPES = new Set(["LineEdit", "TextEdit", "SpinBox"]);
const SELECT_TYPES = new Set(["ItemList", "OptionButton"]);
const RANGE_TYPES = new Set(["Range", "HSlider", "VSlider", "ProgressBar", "SpinBox", "ScrollBar", "HScrollBar", "VScrollBar"]);
const SCROLL_TYPES = new Set(["ScrollContainer"]);

function defaultProject(editorRoot) {
  return path.resolve(editorRoot, "../../example");
}

function parseUniqueFromTscn(filePath, resPath) {
  const text = readFileSync(filePath, "utf8");
  const records = [];
  const nodeRe =
    /\[node name="([^"]+)" type="([^"]+)"(?: parent="([^"]*)")?\]([\s\S]*?)(?=\n\[|\n*$)/g;
  let match;
  while ((match = nodeRe.exec(text))) {
    const body = match[4];
    if (!/unique_name_in_owner\s*=\s*true/.test(body)) continue;
    const klass = match[2];
    records.push({
      unique: "%" + match[1],
      class: klass,
      path: resPath,
      scene: resPath,
      click: CLICK_TYPES.has(klass),
      type: TYPE_TYPES.has(klass),
      select: SELECT_TYPES.has(klass),
      range: RANGE_TYPES.has(klass),
      scroll: SCROLL_TYPES.has(klass),
    });
  }
  return records;
}

function walkTscn(dir, root, out) {
  let entries = [];
  try {
    entries = readdirSync(dir, { withFileTypes: true });
  } catch {
    return;
  }
  for (const ent of entries) {
    if (ent.name.startsWith(".")) continue;
    if (ent.name === "addons" || ent.name === "node_modules" || ent.name === ".godot") continue;
    const full = path.join(dir, ent.name);
    if (ent.isDirectory()) {
      walkTscn(full, root, out);
    } else if (ent.name.endsWith(".tscn")) {
      const res = "res://" + path.relative(root, full).split(path.sep).join("/");
      out.push(...parseUniqueFromTscn(full, res));
    }
  }
}

function parseInputActions(projectGodot) {
  const text = readFileSync(projectGodot, "utf8");
  const idx = text.indexOf("[input]");
  if (idx < 0) return [];
  const rest = text.slice(idx + "[input]".length);
  const next = rest.search(/\n\[/);
  const block = next >= 0 ? rest.slice(0, next) : rest;
  const names = [];
  for (const line of block.split("\n")) {
    const match = line.match(/^([A-Za-z0-9_]+)=\{/);
    if (match) names.push(match[1]);
  }
  return names;
}

function jsonBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on("data", (c) => chunks.push(c));
    req.on("end", () => {
      const raw = Buffer.concat(chunks).toString("utf8");
      if (!raw) return resolve({});
      try {
        resolve(JSON.parse(raw));
      } catch (err) {
        reject(err);
      }
    });
    req.on("error", reject);
  });
}

function send(res, status, obj) {
  res.statusCode = status;
  res.setHeader("Content-Type", "application/json; charset=utf-8");
  res.end(JSON.stringify(obj));
}

function parseAgentJson(stdout) {
  const lines = stdout.split(/\r?\n/);
  for (let i = lines.length - 1; i >= 0; i--) {
    const line = lines[i];
    const idx = line.indexOf("AGENT_JSON ");
    if (idx < 0) continue;
    try {
      return JSON.parse(line.slice(idx + "AGENT_JSON ".length));
    } catch {
      return null;
    }
  }
  return null;
}

function runCli(cli, project, args, timeoutMs) {
  return new Promise((resolve) => {
    const child = spawn("bash", [cli, project, ...args], { cwd: project });
    let stdout = "";
    let stderr = "";
    const timer = setTimeout(() => child.kill("SIGTERM"), timeoutMs);
    child.stdout.on("data", (d) => {
      stdout += d.toString();
    });
    child.stderr.on("data", (d) => {
      stderr += d.toString();
    });
    child.on("close", (code) => {
      clearTimeout(timer);
      resolve({ code: code ?? 1, stdout, stderr });
    });
    child.on("error", (err) => {
      clearTimeout(timer);
      resolve({ code: 1, stdout, stderr: String(err) });
    });
  });
}

function agentWorkspace(project) {
  const root = path.join(project, "agent");
  const flows = path.join(root, "flows");
  const outDir = path.join(root, "out");
  mkdirSync(flows, { recursive: true });
  mkdirSync(path.join(root, "harness"), { recursive: true });
  mkdirSync(outDir, { recursive: true });
  const gdignore = path.join(outDir, ".gdignore");
  if (!existsSync(gdignore)) writeFileSync(gdignore, "");
  return { root, flows, outDir };
}

function listFlows(project) {
  const dir = path.join(project, "agent", "flows");
  if (!existsSync(dir)) return [];
  return readdirSync(dir)
    .filter((name) => name.endsWith(".json") && name !== "_editor_last.json")
    .sort()
    .map((name) => ({ name, file: `res://agent/flows/${name}` }));
}

function readFlowFile(project, name) {
  const base = path.basename(String(name || ""));
  if (!base.endsWith(".json")) return { error: "not json" };
  const file = path.join(project, "agent", "flows", base);
  if (!existsSync(file)) return { error: "missing flow" };
  try {
    return { name: base, spec: JSON.parse(readFileSync(file, "utf8")) };
  } catch (err) {
    return { error: String(err.message || err) };
  }
}

export function godotBridge(editorRoot) {
  let project = defaultProject(editorRoot);
  let lastOutDir = "";

  function snapshot() {
    const godotFile = path.join(project, "project.godot");
    const kit = path.join(project, "addons/agent_kit/plugin.cfg");
    const cli = path.join(project, "addons/agent_kit/cli.sh");
    return {
      project,
      exists: existsSync(godotFile),
      agentKit: existsSync(kit),
      cli: existsSync(cli) ? cli : "",
    };
  }

  return {
    name: "godot-bridge",
    configureServer(server) {
      server.middlewares.use(async (req, res, next) => {
        const url = new URL(req.url || "/", "http://localhost");
        if (!url.pathname.startsWith("/api/")) return next();
        try {
          if (req.method === "GET" && url.pathname === "/api/project") {
            return send(res, 200, snapshot());
          }
          if (req.method === "POST" && url.pathname === "/api/project") {
            const body = await jsonBody(req);
            const nextPath = String(body.project || "").trim();
            if (!nextPath) return send(res, 400, { error: "missing project" });
            const resolved = path.resolve(nextPath);
            if (!existsSync(path.join(resolved, "project.godot"))) {
              return send(res, 400, { error: "no project.godot", project: resolved });
            }
            project = resolved;
            return send(res, 200, snapshot());
          }
          if (req.method === "GET" && url.pathname === "/api/scan") {
            const snap = snapshot();
            if (!snap.exists) return send(res, 400, { error: "no project.godot", ...snap });
            const unique = [];
            walkTscn(project, project, unique);
            unique.sort((a, b) => a.unique.localeCompare(b.unique));
            const actions = parseInputActions(path.join(project, "project.godot"));
            return send(res, 200, {
              source: "scan",
              unique,
              actions,
              flows: listFlows(project),
              ...snap,
            });
          }
          if (
            (req.method === "GET" || req.method === "POST") &&
            (url.pathname === "/api/inspect" || url.pathname === "/api/info")
          ) {
            const snap = snapshot();
            if (!snap.cli) return send(res, 400, { error: "AgentKit missing", ...snap });
            const verb = url.pathname === "/api/info" ? "info" : "inspect";
            const args = verb === "inspect" ? ["inspect", "--unique"] : ["info"];
            const body = req.method === "POST" ? await jsonBody(req).catch(() => ({})) : {};
            const scene = body.scene || url.searchParams.get("scene") || "";
            if (scene) args.push(`--scene=${scene}`);
            const result = await runCli(snap.cli, project, args, 45000);
            const parsed = parseAgentJson(result.stdout);
            return send(res, result.code === 0 ? 200 : 500, {
              source: "live",
              unique: parsed?.unique || [],
              actions: parsed?.actions || [],
              flows: listFlows(project),
              payload: parsed,
              log: `${result.stdout}\n${result.stderr}`.trim(),
              code: result.code,
              ...snap,
            });
          }
          if (req.method === "GET" && url.pathname === "/api/flow") {
            const loaded = readFlowFile(project, url.searchParams.get("name"));
            if (loaded.error) return send(res, 404, loaded);
            return send(res, 200, loaded);
          }
          if (req.method === "POST" && url.pathname === "/api/run") {
            const snap = snapshot();
            if (!snap.cli) return send(res, 400, { error: "AgentKit missing", ...snap });
            const body = await jsonBody(req);
            const spec = body.spec;
            if (!spec || typeof spec !== "object") {
              return send(res, 400, { error: "missing spec" });
            }
            const ws = agentWorkspace(project);
            const flowFile = path.join(ws.flows, "_editor_last.json");
            const outDir = ws.outDir;
            writeFileSync(flowFile, JSON.stringify(spec, null, 2));
            lastOutDir = outDir;
            const result = await runCli(
              snap.cli,
              project,
              ["flow", `--flow=${flowFile}`, `--out=${outDir}`, "--fail-on-error"],
              120000
            );
            const shots = existsSync(outDir)
              ? readdirSync(outDir).filter((name) => name.endsWith(".png"))
              : [];
            return send(res, 200, {
              ok: result.code === 0 && /AGENT_OK flow/.test(result.stdout),
              code: result.code,
              log: `${result.stdout}\n${result.stderr}`.trim(),
              shots,
              flow: flowFile,
              out: outDir,
              flows: listFlows(project),
              ...snap,
            });
          }
          if (req.method === "GET" && url.pathname.startsWith("/api/shots/")) {
            const name = path.basename(decodeURIComponent(url.pathname.slice("/api/shots/".length)));
            const file = path.join(lastOutDir, name);
            if (!lastOutDir || !existsSync(file)) {
              res.statusCode = 404;
              return res.end("missing shot");
            }
            res.setHeader("Content-Type", "image/png");
            return createReadStream(file).pipe(res);
          }
          return send(res, 404, { error: "unknown api" });
        } catch (err) {
          return send(res, 500, { error: String(err.message || err) });
        }
      });
    },
  };
}
