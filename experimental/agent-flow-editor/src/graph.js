export const KINDS = [
  { id: "flow", label: "Flow", color: "#6ee7b7" },
  { id: "shot", label: "Shot", color: "#93c5fd" },
  { id: "click", label: "Click", color: "#fbbf24" },
  { id: "try_click", label: "Try click", color: "#fdba74" },
  { id: "wait", label: "Wait", color: "#c4b5fd" },
  { id: "type", label: "Type", color: "#67e8f9" },
  { id: "wait_until", label: "Wait until", color: "#f9a8d4" },
  { id: "assert", label: "Assert", color: "#fca5a5" },
  { id: "print", label: "Print", color: "#d4d4d8" },
  { id: "repeat", label: "Repeat", color: "#d8b4fe" },
];

export function kindMeta(id) {
  return KINDS.find((k) => k.id === id) || KINDS[1];
}

export function uid(prefix) {
  return `${prefix}_${Math.random().toString(36).slice(2, 9)}`;
}

export function emptyData(kind) {
  switch (kind) {
    case "flow":
      return { scene: "", wait_first: 0.8 };
    case "shot":
      return { name: "01.png" };
    case "click":
    case "try_click":
      return { node: "%PlaySolo" };
    case "wait":
      return { seconds: 0.4 };
    case "type":
      return { node: "%Ip", text: "127.0.0.1" };
    case "wait_until":
      return { node: "%Status", key: "text_contains", value: "ok", timeout: 6 };
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
      return { shot: d.name || "shot.png" };
    case "click":
      return { click: d.node || "" };
    case "try_click":
      return { try_click: d.node || "" };
    case "wait":
      return { wait: Number(d.seconds) || 0 };
    case "type":
      return { type: { node: d.node || "", text: d.text || "" } };
    case "wait_until":
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
    return { node: nodeAt("shot", x, y, { name: raw.shot || raw.screenshot }) };
  }
  if (raw.click) return { node: nodeAt("click", x, y, { node: raw.click }) };
  if (raw.try_click) return { node: nodeAt("try_click", x, y, { node: raw.try_click }) };
  if (raw.wait != null) return { node: nodeAt("wait", x, y, { seconds: raw.wait }) };
  if (raw.type) {
    return { node: nodeAt("type", x, y, { node: raw.type.node, text: raw.type.text }) };
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
  const data = { node: spec.node || "", timeout: spec.timeout };
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
