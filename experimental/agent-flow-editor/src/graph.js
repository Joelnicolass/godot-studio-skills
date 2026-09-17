export function portPos(node, which) {
  const w = 168;
  if (which === "in") return { x: node.x, y: node.y + 28 };
  if (which === "loop") return { x: node.x + w, y: node.y + 54 };
  return { x: node.x + w, y: node.y + 28 };
}

export function bezier(a, b) {
  const dx = Math.max(40, Math.abs(b.x - a.x) * 0.45);
  return `M ${a.x} ${a.y} C ${a.x + dx} ${a.y}, ${b.x - dx} ${b.y}, ${b.x} ${b.y}`;
}

export function caption(node) {
  const d = node.data || {};
  switch (node.kind) {
    case "flow":
      return d.scene || "(main scene)";
    case "shot":
      return d.node ? `${d.name} ${d.node}` : d.name;
    case "click":
    case "try_click":
      return d.node;
    case "press":
      return d.hold ? `${d.name} ${d.hold}s` : d.name;
    case "wait":
      return `${d.seconds}s`;
    case "type":
      return `${d.node} ← ${d.text}`;
    case "print":
      return `${d.node}.${d.prop}`;
    case "select":
      return d.text ? `${d.node} “${d.text}”` : `${d.node} #${d.index}`;
    case "range":
      return `${d.node} = ${d.value}`;
    case "scroll":
      return d.node;
    case "drag":
      return d.node;
    case "call":
      return d.harness ? `${d.harness}.${d.method}` : `${d.node}.${d.method}`;
    case "scene":
      return d.path;
    case "seed":
      return String(d.value);
    case "time_scale":
      return String(d.value);
    case "diff":
      return `${d.a} vs ${d.b}`;
    case "repeat":
      return `×${d.times}`;
    default:
      return d.node || "";
  }
}

export const KINDS = [
  { id: "flow", label: "Flow", color: "#6ee7b7" },
  { id: "shot", label: "Shot", color: "#93c5fd" },
  { id: "click", label: "Click", color: "#fbbf24" },
  { id: "try_click", label: "Try click", color: "#fdba74" },
  { id: "press", label: "Press action", color: "#86efac" },
  { id: "wait", label: "Wait", color: "#c4b5fd" },
  { id: "type", label: "Type", color: "#67e8f9" },
  { id: "select", label: "Select", color: "#fdba74" },
  { id: "range", label: "Range", color: "#a5b4fc" },
  { id: "scroll", label: "Scroll", color: "#7dd3fc" },
  { id: "drag", label: "Drag", color: "#5eead4" },
  { id: "call", label: "Call", color: "#fde68a" },
  { id: "scene", label: "Scene", color: "#6ee7b7" },
  { id: "seed", label: "Seed", color: "#d4d4d8" },
  { id: "time_scale", label: "Time scale", color: "#e7e5e4" },
  { id: "diff", label: "Diff PNGs", color: "#f9a8d4" },
  { id: "wait_until", label: "Wait until", color: "#f9a8d4" },
  { id: "assert", label: "Assert", color: "#fca5a5" },
  { id: "print", label: "Print", color: "#d4d4d8" },
  { id: "repeat", label: "Repeat", color: "#d8b4fe" },
];

export function kindMeta(id) {
  return KINDS.find((k) => k.id === id) || KINDS[1];
}

export function kindUsesNode(kind) {
  return [
    "click",
    "try_click",
    "type",
    "print",
    "wait_until",
    "assert",
    "select",
    "range",
    "scroll",
    "drag",
    "call",
    "shot",
  ].includes(kind);
}

export function kindUsesAction(kind) {
  return kind === "press";
}

export function uid(prefix) {
  return `${prefix}_${Math.random().toString(36).slice(2, 9)}`;
}

export function emptyData(kind) {
  switch (kind) {
    case "flow":
      return { scene: "", wait_first: 0.8 };
    case "shot":
      return { name: "01.png", node: "" };
    case "click":
    case "try_click":
      return { node: "%PlaySolo" };
    case "press":
      return { name: "ui_accept", hold: 0 };
    case "wait":
      return { seconds: 0.4 };
    case "type":
      return { node: "%Ip", text: "127.0.0.1" };
    case "select":
      return { node: "%Rooms", index: 0, text: "" };
    case "range":
      return { node: "%Volume", value: 0.5 };
    case "scroll":
      return { node: "%List", vertical: 80, horizontal: 0 };
    case "drag":
      return { node: "%Pad", from_x: 8, from_y: 8, to_x: 80, to_y: 8 };
    case "call":
      return { node: "%Title", method: "set", harness: "", args: '["text","ok"]' };
    case "scene":
      return { path: "res://scenes/ui/boot.tscn" };
    case "seed":
      return { value: 1 };
    case "time_scale":
      return { value: 1 };
    case "diff":
      return { a: "01_boot.png", b: "02_after_solo.png", out: "diff.png", threshold: 0.02, max_percent: 0 };
    case "wait_until":
      return { node: "%Status", key: "text_contains", value: "ok", timeout: 6, signal: "" };
    case "assert":
      return { node: "%PlaySolo", key: "disabled", value: "false" };
    case "print":
      return { node: "%Title", prop: "text" };
    case "repeat":
      return { times: 80, until: '{"node":"%ResultsView","visible":true}' };
    default:
      return {};
  }
}

function condFrom(data) {
  const spec = { node: data.node || "" };
  const key = data.key || "visible";
  if (key === "text_contains" || key === "text_equals" || key === "texture_path_contains") {
    spec[key] = data.value ?? "";
  } else if (key === "timeout") {
    /* skip */
  } else {
    spec[key] = data.value === "true" || data.value === true;
  }
  if (data.timeout != null && data.timeout !== "") spec.timeout = Number(data.timeout);
  return spec;
}

function stepFromNode(node, innerSteps) {
  const d = node.data || {};
  switch (node.kind) {
    case "shot":
      if (d.node) return { shot: { name: d.name || "shot.png", node: d.node } };
      return { shot: d.name || "shot.png" };
    case "click":
      return { click: d.node || "" };
    case "try_click":
      return { try_click: d.node || "" };
    case "press": {
      const hold = Number(d.hold) || 0;
      if (hold > 0) return { press: { name: d.name || "", hold } };
      return { press: d.name || "" };
    }
    case "wait":
      return { wait: Number(d.seconds) || 0 };
    case "type":
      return { type: { node: d.node || "", text: d.text || "" } };
    case "select": {
      const spec = { node: d.node || "" };
      if (d.text) spec.text = d.text;
      else spec.index = Number(d.index) || 0;
      return { select: spec };
    }
    case "range":
      return { range: { node: d.node || "", value: Number(d.value) || 0 } };
    case "scroll":
      return {
        scroll: {
          node: d.node || "",
          vertical: Number(d.vertical) || 0,
          horizontal: Number(d.horizontal) || 0,
        },
      };
    case "drag":
      return {
        drag: {
          node: d.node || "",
          from_x: Number(d.from_x) || 0,
          from_y: Number(d.from_y) || 0,
          to_x: Number(d.to_x) || 0,
          to_y: Number(d.to_y) || 0,
        },
      };
    case "call": {
      let args = [];
      try {
        args = JSON.parse(d.args || "[]");
      } catch {
        args = [];
      }
      const spec = { method: d.method || "", args };
      if (d.harness) spec.harness = d.harness;
      else spec.node = d.node || "";
      return { call: spec };
    }
    case "scene":
      return { scene: d.path || "" };
    case "seed":
      return { seed: Number(d.value) || 0 };
    case "time_scale":
      return { time_scale: Number(d.value) || 1 };
    case "diff":
      return {
        diff: {
          a: d.a || "",
          b: d.b || "",
          out: d.out || "diff.png",
          threshold: Number(d.threshold) || 0.02,
          max_percent: Number(d.max_percent) || 0,
        },
      };
    case "wait_until":
      if (d.signal) {
        return { wait_until: { node: d.node || "", signal: d.signal, timeout: Number(d.timeout) || 5 } };
      }
      return { wait_until: condFrom(d) };
    case "assert":
      return { assert: condFrom(d) };
    case "print":
      return { print: { node: d.node || "", prop: d.prop || "text" } };
    case "repeat": {
      let until = {};
      try {
        until = JSON.parse(d.until || "{}");
      } catch {
        until = {};
      }
      return { repeat: { times: Number(d.times) || 1, until, steps: innerSteps } };
    }
    default:
      return null;
  }
}

function outgoing(edges, from, handle) {
  return edges.filter((e) => e.from === from && (e.handle || "out") === handle);
}

function walk(nodes, edges, startId, handle) {
  const steps = [];
  const seen = new Set();
  let current = outgoing(edges, startId, handle)[0]?.to;
  while (current && !seen.has(current)) {
    seen.add(current);
    const node = nodes.find((n) => n.id === current);
    if (!node || node.kind === "flow") break;
    if (node.kind === "repeat") {
      const inner = walk(nodes, edges, node.id, "loop");
      steps.push(stepFromNode(node, inner));
    } else {
      const step = stepFromNode(node, []);
      if (step) steps.push(step);
    }
    current = outgoing(edges, node.id, "out")[0]?.to;
  }
  return steps;
}

export function toFlowJson(nodes, edges) {
  const flow = nodes.find((n) => n.kind === "flow");
  const startId = flow?.id;
  const steps = startId ? walk(nodes, edges, startId, "out") : [];
  const spec = { wait_first: Number(flow?.data?.wait_first) || 0.8, steps };
  const scene = (flow?.data?.scene || "").trim();
  if (scene) spec.scene = scene;
  return spec;
}

function nodeAt(kind, x, y, data) {
  return { id: uid(kind), kind, x, y, data: { ...emptyData(kind), ...data } };
}

function chain(nodes, edges, parentId, handle, items, x, y) {
  let prev = parentId;
  let prevHandle = handle;
  let cx = x;
  for (const item of items) {
    const placed = placeStep(item, cx, y);
    nodes.push(placed.node);
    edges.push({ id: uid("e"), from: prev, to: placed.node.id, handle: prevHandle });
    if (placed.loopEdges) edges.push(...placed.loopEdges);
    if (placed.loopNodes) nodes.push(...placed.loopNodes);
    prev = placed.node.id;
    prevHandle = "out";
    cx += 220;
  }
}

function placeStep(raw, x, y) {
  if (raw.shot || raw.screenshot) {
    const shot = raw.shot || raw.screenshot;
    if (typeof shot === "object") {
      return { node: nodeAt("shot", x, y, { name: shot.name || "shot.png", node: shot.node || "" }) };
    }
    return { node: nodeAt("shot", x, y, { name: shot }) };
  }
  if (raw.click) return { node: nodeAt("click", x, y, { node: raw.click }) };
  if (raw.try_click) return { node: nodeAt("try_click", x, y, { node: raw.try_click }) };
  if (raw.press) {
    const spec = typeof raw.press === "string" ? { name: raw.press } : raw.press;
    return { node: nodeAt("press", x, y, { name: spec.name, hold: spec.hold || 0 }) };
  }
  if (raw.wait != null) return { node: nodeAt("wait", x, y, { seconds: raw.wait }) };
  if (raw.type) {
    return { node: nodeAt("type", x, y, { node: raw.type.node, text: raw.type.text }) };
  }
  if (raw.select) {
    return {
      node: nodeAt("select", x, y, {
        node: raw.select.node,
        index: raw.select.index ?? 0,
        text: raw.select.text || "",
      }),
    };
  }
  if (raw.range) {
    return { node: nodeAt("range", x, y, { node: raw.range.node, value: raw.range.value }) };
  }
  if (raw.scroll) {
    return {
      node: nodeAt("scroll", x, y, {
        node: raw.scroll.node,
        vertical: raw.scroll.vertical ?? 0,
        horizontal: raw.scroll.horizontal ?? 0,
      }),
    };
  }
  if (raw.drag) {
    return { node: nodeAt("drag", x, y, { ...raw.drag }) };
  }
  if (raw.call) {
    return {
      node: nodeAt("call", x, y, {
        node: raw.call.node || "",
        harness: raw.call.harness || "",
        method: raw.call.method,
        args: JSON.stringify(raw.call.args || []),
      }),
    };
  }
  if (raw.scene) return { node: nodeAt("scene", x, y, { path: raw.scene }) };
  if (raw.seed != null) return { node: nodeAt("seed", x, y, { value: raw.seed }) };
  if (raw.time_scale != null) return { node: nodeAt("time_scale", x, y, { value: raw.time_scale }) };
  if (raw.diff) {
    return { node: nodeAt("diff", x, y, { ...raw.diff }) };
  }
  if (raw.print) {
    return { node: nodeAt("print", x, y, { node: raw.print.node, prop: raw.print.prop }) };
  }
  if (raw.assert) {
    return { node: nodeAt("assert", x, y, condToData(raw.assert)) };
  }
  if (raw.wait_until) {
    return { node: nodeAt("wait_until", x, y, condToData(raw.wait_until)) };
  }
  if (raw.repeat) {
    const node = nodeAt("repeat", x, y, {
      times: raw.repeat.times ?? 80,
      until: JSON.stringify(raw.repeat.until || {}),
    });
    const loopNodes = [];
    const loopEdges = [];
    chain(loopNodes, loopEdges, node.id, "loop", raw.repeat.steps || [], x, y + 130);
    return { node, loopNodes, loopEdges };
  }
  return { node: nodeAt("wait", x, y, { seconds: 0 }) };
}

function condToData(spec) {
  const data = { node: spec.node || "", timeout: spec.timeout, signal: spec.signal || "" };
  if (spec.signal) {
    data.key = "signal";
    data.value = spec.signal;
    return data;
  }
  for (const key of [
    "disabled",
    "visible",
    "visible_in_tree",
    "text_contains",
    "text_equals",
    "texture_path_contains",
  ]) {
    if (spec[key] != null) {
      data.key = key;
      data.value = String(spec[key]);
      break;
    }
  }
  return data;
}

export function fromFlowJson(spec) {
  const nodes = [];
  const edges = [];
  const flow = nodeAt("flow", 40, 80, {
    scene: spec.scene || "",
    wait_first: spec.wait_first ?? 0.8,
  });
  nodes.push(flow);
  chain(nodes, edges, flow.id, "out", spec.steps || [], 280, 80);
  return { nodes, edges };
}

export const EXAMPLE = {
  wait_first: 0.9,
  steps: [
    { shot: "01_boot.png" },
    { print: { node: "%Title", prop: "text" } },
    { assert: { node: "%PlaySolo", disabled: false } },
    { click: "%PlaySolo" },
    { wait: 1.4 },
    { shot: "02_after_solo.png" },
  ],
};
