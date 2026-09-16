import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { EXAMPLE, emptyData, fromFlowJson, toFlowJson, uid } from "../graph.js";

export function useFlowGraph() {
  const boot = fromFlowJson(EXAMPLE);
  const [nodes, setNodes] = useState(boot.nodes);
  const [edges, setEdges] = useState(boot.edges);
  const [selected, setSelected] = useState(null);
  const [draft, setDraft] = useState(false);
  const [err, setErr] = useState("");
  const [link, setLink] = useState(null);
  const drag = useRef(null);

  const json = useMemo(() => JSON.stringify(toFlowJson(nodes, edges), null, 2), [nodes, edges]);
  const spec = useMemo(() => toFlowJson(nodes, edges), [nodes, edges]);
  const current = nodes.find((n) => n.id === selected) || null;

  const addKind = useCallback((kind) => {
    setNodes((ns) => {
      const node = {
        id: uid(kind),
        kind,
        x: 120 + ns.length * 12,
        y: 200 + (ns.length % 5) * 16,
        data: emptyData(kind),
      };
      setSelected(node.id);
      return [...ns, node];
    });
  }, []);

  const removeSelected = useCallback(() => {
    setSelected((id) => {
      if (!id) return id;
      setNodes((ns) => {
        const node = ns.find((n) => n.id === id);
        if (node?.kind === "flow") return ns;
        setEdges((es) => es.filter((ed) => ed.from !== id && ed.to !== id));
        return ns.filter((n) => n.id !== id);
      });
      return null;
    });
  }, []);

  const updateData = useCallback((patch) => {
    setNodes((ns) =>
      ns.map((n) => (n.id === selected ? { ...n, data: { ...n.data, ...patch } } : n))
    );
  }, [selected]);

  const loadSpec = useCallback((next) => {
    const g = fromFlowJson(next);
    setNodes(g.nodes);
    setEdges(g.edges);
    setSelected(g.nodes[0]?.id ?? null);
    setErr("");
  }, []);

  const importText = useCallback(
    (text) => {
      try {
        loadSpec(JSON.parse(text));
      } catch (e) {
        setErr(String(e.message || e));
      }
    },
    [loadSpec]
  );

  useEffect(() => {
    function onKey(e) {
      if (e.key !== "Backspace" && e.key !== "Delete") return;
      const tag = e.target?.tagName;
      if (tag === "INPUT" || tag === "TEXTAREA" || tag === "SELECT") return;
      removeSelected();
    }
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [removeSelected]);

  return {
    nodes,
    setNodes,
    edges,
    setEdges,
    selected,
    setSelected,
    current,
    draft,
    setDraft,
    err,
    setErr,
    link,
    setLink,
    drag,
    json,
    spec,
    addKind,
    removeSelected,
    updateData,
    loadSpec,
    importText,
  };
}
