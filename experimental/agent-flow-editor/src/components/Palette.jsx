import { KINDS } from "../graph.js";

export default function Palette({ onAdd, onLoadExample, onDelete }) {
  return (
    <aside className="palette">
      <h1>AgentKit flow</h1>
      <p className="hint">
        Experimental. Cables = playtester order. Bind the Godot project
        and hit <strong>Run flow</strong> to execute <code>cli.sh flow</code>.
      </p>
      {KINDS.filter((k) => k.id !== "flow").map((k) => (
        <button
          key={k.id}
          className="kind-btn"
          style={{ borderLeft: `4px solid ${k.color}` }}
          onClick={() => onAdd(k.id)}
        >
          {k.label}
        </button>
      ))}
      <button onClick={onLoadExample}>Load boot example</button>
      <button onClick={onDelete}>Delete node</button>
    </aside>
  );
}
