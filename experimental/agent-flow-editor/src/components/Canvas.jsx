import { useCallback, useRef, useState } from "react";
import { portPos, uid } from "../graph.js";
import Cables from "./Cables.jsx";
import FlowNode from "./FlowNode.jsx";

export default function Canvas({
  nodes,
  setNodes,
  edges,
  setEdges,
  selected,
  setSelected,
  link,
  setLink,
  drag,
}) {
  const canvas = useRef(null);
  const [pan, setPan] = useState({ x: 0, y: 0 });
  const panRef = useRef(pan);
  panRef.current = pan;
  const panDrag = useRef(null);
  const [panning, setPanning] = useState(false);

  function toWorld(e) {
    const rect = canvas.current.getBoundingClientRect();
    const p = panRef.current;
    return {
      x: e.clientX - rect.left - p.x,
      y: e.clientY - rect.top - p.y,
    };
  }

  const onMove = useCallback(
    (e) => {
      if (panDrag.current) {
        const { sx, sy, ox, oy } = panDrag.current;
        setPan({ x: ox + (e.clientX - sx), y: oy + (e.clientY - sy) });
        return;
      }
      const { x, y } = toWorld(e);
      if (drag.current) {
        const { id, ox, oy } = drag.current;
        setNodes((ns) => ns.map((n) => (n.id === id ? { ...n, x: x - ox, y: y - oy } : n)));
      }
      if (link) setLink((l) => ({ ...l, x, y }));
    },
    [drag, link, setLink, setNodes]
  );

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

  function endPointer(e) {
    drag.current = null;
    if (panDrag.current) {
      panDrag.current = null;
      setPanning(false);
    }
    if (link) setLink(null);
    if (canvas.current?.hasPointerCapture?.(e.pointerId)) {
      canvas.current.releasePointerCapture(e.pointerId);
    }
  }

  return (
    <div
      className={`canvas${panning ? " panning" : ""}`}
      ref={canvas}
      role="application"
      aria-label="Blueprints"
      style={{ backgroundPosition: `${pan.x}px ${pan.y}px` }}
      onPointerMove={onMove}
      onPointerUp={endPointer}
      onPointerCancel={endPointer}
      onPointerDown={(e) => {
        if (e.button !== 0 && e.button !== 1) return;
        e.preventDefault();
        setSelected(null);
        panDrag.current = {
          sx: e.clientX,
          sy: e.clientY,
          ox: panRef.current.x,
          oy: panRef.current.y,
        };
        setPanning(true);
        canvas.current.setPointerCapture(e.pointerId);
      }}
    >
      <div
        className="world"
        style={{ transform: `translate(${pan.x}px, ${pan.y}px)` }}
      >
        <Cables nodes={nodes} edges={edges} link={link} />
        {nodes.map((node) => (
          <FlowNode
            key={node.id}
            node={node}
            selected={selected === node.id}
            onSelect={(e) => {
              e.stopPropagation();
              setSelected(node.id);
              const { x, y } = toWorld(e);
              drag.current = {
                id: node.id,
                ox: x - node.x,
                oy: y - node.y,
              };
              canvas.current.setPointerCapture(e.pointerId);
            }}
            onStartLink={startLink}
            onEndLink={endLink}
          />
        ))}
      </div>
      <div className="banner">
        Arrastrá el vacío para desplazar · out = next · loop = repeat · Backspace borra
      </div>
    </div>
  );
}
