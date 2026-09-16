import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import {
  EXAMPLE,
  KINDS,
  emptyData,
  fromFlowJson,
  kindMeta,
  toFlowJson,
  uid,
} from "./graph.js";

const W = 168;

function portPos(node, which) {
  if (which === "in") return { x: node.x, y: node.y + 28 };
  if (which === "loop") return { x: node.x + W, y: node.y + 54 };
  return { x: node.x + W, y: node.y + 28 };
}

function bezier(a, b) {
  const dx = Math.max(40, Math.abs(b.x - a.x) * 0.45);
  return `M ${a.x} ${a.y} C ${a.x + dx} ${a.y}, ${b.x - dx} ${b.y}, ${b.x} ${b.y}`;
}

function caption(node) {
  const d = node.data || {};
  switch (node.kind) {
    case "flow":
      return d.scene || "(main scene)";
    case "shot":
      return d.name;
    case "click":
    case "try_click":
      return d.node;
    case "wait":
      return `${d.seconds}s`;
    case "type":
      return `${d.node} ← ${d.text}`;
    case "print":
      return `${d.node}.${d.prop}`;
    case "repeat":
      return `×${d.times}`;
    default:
      return d.node || "";
  }
}

export default function App() {
  const boot = fromFlowJson(EXAMPLE);
  const [nodes, setNodes] = useState(boot.nodes);
  const [edges, setEdges] = useState(boot.edges);
  const [selected, setSelected] = useState(null);
  const [draft, setDraft] = useState("");
  const [err, setErr] = useState("");
  const [link, setLink] = useState(null);
  const drag = useRef(null);
  const canvas = useRef(null);

  const json = useMemo(() => JSON.stringify(toFlowJson(nodes, edges), null, 2), [nodes, edges]);

  useEffect(() => {
    function onKey(e) {
      if (e.key !== "Backspace" && e.key !== "Delete") return;
      const tag = e.target?.tagName;
      if (tag === "INPUT" || tag === "TEXTAREA" || tag === "SELECT") return;
      removeSelected();
    }
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  });

  const onMove = useCallback((e) => {
    const rect = canvas.current.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const y = e.clientY - rect.top;
    if (drag.current) {
      const { id, ox, oy } = drag.current;
      setNodes((ns) => ns.map((n) => (n.id === id ? { ...n, x: x - ox, y: y - oy } : n)));
    }
    if (link) setLink((l) => ({ ...l, x, y }));
  }, [link]);

  function addKind(kind) {
    const node = {
      id: uid(kind),
      kind,
      x: 120 + nodes.length * 12,
      y: 200 + (nodes.length % 5) * 16,
      data: emptyData(kind),
    };
    setNodes((ns) => [...ns, node]);
    setSelected(node.id);
  }

  function startLink(e, node, handle) {
    e.stopPropagation();
    const p = portPos(node, handle);
    setLink({ from: node.id, handle, x: p.x, y: p.y });
  }

  function endLink(e, node) {
    e.stopPropagation();
    if (!link || link.from === node.id) {
      setLink(null);
      return;
    }
    setEdges((es) => {
      const next = es.filter(
        (ed) => !(ed.from === link.from && (ed.handle || "out") === link.handle)
      );
      next.push({ id: uid("e"), from: link.from, to: node.id, handle: link.handle });
      return next;
    });
    setLink(null);
  }

  function removeSelected() {
    if (!selected) return;
    const node = nodes.find((n) => n.id === selected);
    if (node?.kind === "flow") return;
    setNodes((ns) => ns.filter((n) => n.id !== selected));
    setEdges((es) => es.filter((ed) => ed.from !== selected && ed.to !== selected));
    setSelected(null);
  }

  function updateData(patch) {
    setNodes((ns) =>
      ns.map((n) => (n.id === selected ? { ...n, data: { ...n.data, ...patch } } : n))
    );
  }

  function loadSpec(spec) {
    const g = fromFlowJson(spec);
    setNodes(g.nodes);
    setEdges(g.edges);
    setSelected(g.nodes[0]?.id ?? null);
    setErr("");
  }

  function importText(text) {
    try {
      loadSpec(JSON.parse(text));
    } catch (e) {
      setErr(String(e.message || e));
    }
  }

  const current = nodes.find((n) => n.id === selected);

  return (
    <div className="app">
      <aside className="palette">
        <h1>AgentKit flow</h1>
        <p className="hint">Experimental. Cables = playtester order. Export JSON and run <code>cli.sh … flow</code>.</p>
        {KINDS.filter((k) => k.id !== "flow").map((k) => (
          <button key={k.id} className="kind-btn" style={{ borderLeft: `4px solid ${k.color}` }} onClick={() => addKind(k.id)}>
            {k.label}
          </button>
        ))}
        <button onClick={() => loadSpec(EXAMPLE)}>Load boot example</button>
        <button onClick={removeSelected}>Delete node</button>
      </aside>
      <div className="stage-wrap">
        <div className="toolbar">
          <button
            onClick={() => {
              navigator.clipboard.writeText(json);
            }}
          >
            Copy JSON
          </button>
          <button onClick={() => setDraft(json)}>Show JSON</button>
          <label className="file">
            Import
            <input
              type="file"
              accept="application/json,.json"
              hidden
              onChange={(e) => {
                const f = e.target.files?.[0];
                if (!f) return;
                f.text().then(importText);
              }}
            />
          </label>
        </div>
        <div
          className="canvas"
          ref={canvas}
          onPointerMove={onMove}
          onPointerUp={() => {
            drag.current = null;
            if (link) setLink(null);
          }}
          onPointerDown={() => setSelected(null)}
        >
          <svg className="cables">
            {edges.map((ed) => {
              const a = nodes.find((n) => n.id === ed.from);
              const b = nodes.find((n) => n.id === ed.to);
              if (!a || !b) return null;
              const handle = ed.handle || "out";
              return (
                <path
                  key={ed.id}
                  d={bezier(portPos(a, handle), portPos(b, "in"))}
                  fill="none"
                  stroke={handle === "loop" ? "#c084fc" : "#a1a1aa"}
                  strokeWidth="2"
                />
              );
            })}
            {link && (() => {
              const a = nodes.find((n) => n.id === link.from);
              if (!a) return null;
              return (
                <path
                  d={bezier(portPos(a, link.handle), { x: link.x, y: link.y })}
                  fill="none"
                  stroke="#fafafa"
                  strokeWidth="2"
                  strokeDasharray="4 4"
                />
              );
            })()}
          </svg>
          {nodes.map((node) => {
            const meta = kindMeta(node.kind);
            return (
              <div
                key={node.id}
                className={`node${selected === node.id ? " selected" : ""}`}
                style={{ left: node.x, top: node.y }}
                onPointerDown={(e) => {
                  e.stopPropagation();
                  setSelected(node.id);
                  const rect = canvas.current.getBoundingClientRect();
                  drag.current = {
                    id: node.id,
                    ox: e.clientX - rect.left - node.x,
                    oy: e.clientY - rect.top - node.y,
                  };
                }}
              >
                <div className="node-h" style={{ background: meta.color }}>{meta.label}</div>
                <div className="node-b">{caption(node)}</div>
                {node.kind !== "flow" && (
                  <div className="port in" onPointerUp={(e) => endLink(e, node)} title="in" />
                )}
                <div
                  className="port out"
                  onPointerDown={(e) => startLink(e, node, "out")}
                  title="out"
                />
                {node.kind === "repeat" && (
                  <>
                    <span className="loop-label">loop</span>
                    <div
                      className="port loop"
                      onPointerDown={(e) => startLink(e, node, "loop")}
                      title="loop"
                    />
                  </>
                )}
              </div>
            );
          })}
          <div className="banner">Drag · out cable = next · loop = repeat body · Backspace deletes</div>
        </div>
      </div>
      <aside className="inspector">
        <h1>Inspector</h1>
        {!current && <p className="hint">Select a node.</p>}
        {current && <Fields node={current} onChange={updateData} />}
        {err && <p className="error">{err}</p>}
        {draft && (
          <>
            <label>JSON</label>
            <textarea value={json} readOnly />
          </>
        )}
        <label>Paste JSON</label>
        <textarea
          placeholder='{ "steps": [] }'
          onBlur={(e) => {
            const t = e.target.value.trim();
            if (t) importText(t);
          }}
        />
      </aside>
    </div>
  );
}

function Fields({ node, onChange }) {
  const d = node.data;
  const field = (key, label, type = "text") => (
    <label key={key}>
      {label}
      <input
        type={type}
        value={d[key] ?? ""}
        onChange={(e) =>
          onChange({ [key]: type === "number" ? Number(e.target.value) : e.target.value })
        }
      />
    </label>
  );
  switch (node.kind) {
    case "flow":
      return (
        <>
          {field("scene", "scene (res:// or empty)")}
          {field("wait_first", "wait_first", "number")}
        </>
      );
    case "shot":
      return field("name", "png filename");
    case "click":
    case "try_click":
      return field("node", "%UniqueName");
    case "wait":
      return field("seconds", "seconds", "number");
    case "type":
      return (
        <>
          {field("node", "node")}
          {field("text", "text")}
        </>
      );
    case "print":
      return (
        <>
          {field("node", "node")}
          {field("prop", "prop")}
        </>
      );
    case "wait_until":
    case "assert":
      return (
        <>
          {field("node", "node")}
          <label>
            key
            <select value={d.key} onChange={(e) => onChange({ key: e.target.value })}>
              <option value="disabled">disabled</option>
              <option value="visible">visible</option>
              <option value="visible_in_tree">visible_in_tree</option>
              <option value="text_contains">text_contains</option>
              <option value="text_equals">text_equals</option>
            </select>
          </label>
          {field("value", "value")}
          {node.kind === "wait_until" && field("timeout", "timeout", "number")}
        </>
      );
    case "repeat":
      return (
        <>
          {field("times", "times", "number")}
          <label>
            until (JSON)
            <textarea value={d.until} onChange={(e) => onChange({ until: e.target.value })} />
          </label>
        </>
      );
    default:
      return null;
  }
}
