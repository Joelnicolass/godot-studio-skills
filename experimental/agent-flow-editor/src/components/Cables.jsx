import { bezier, portPos } from "../graph.js";

export default function Cables({ nodes, edges, link }) {
  return (
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
      {link &&
        (() => {
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
  );
}
