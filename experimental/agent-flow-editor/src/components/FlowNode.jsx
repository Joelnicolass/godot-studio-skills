import { caption, kindMeta } from "../graph.js";

export default function FlowNode({
  node,
  selected,
  onSelect,
  onStartLink,
  onEndLink,
}) {
  const meta = kindMeta(node.kind);
  return (
    <div
      className={`node${selected ? " selected" : ""}`}
      style={{ left: node.x, top: node.y }}
      onPointerDown={onSelect}
    >
      <div className="node-h" style={{ background: meta.color }}>
        {meta.label}
      </div>
      <div className="node-b">{caption(node)}</div>
      {node.kind !== "flow" && (
        <div className="port in" onPointerUp={(e) => onEndLink(e, node)} title="in" />
      )}
      <div
        className="port out"
        onPointerDown={(e) => onStartLink(e, node, "out")}
        title="out"
      />
      {node.kind === "repeat" && (
        <>
          <span className="loop-label">loop</span>
          <div
            className="port loop"
            onPointerDown={(e) => onStartLink(e, node, "loop")}
            title="loop"
          />
        </>
      )}
    </div>
  );
}
