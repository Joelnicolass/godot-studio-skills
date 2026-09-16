export default function GodotBinder({
  project,
  setProjectPath,
  status,
  unique,
  actions,
  source,
  busy,
  onBind,
  onScan,
  onInspect,
  onPickUnique,
  onPickAction,
}) {
  return (
    <section className="binder">
      <h1>Godot</h1>
      <p className="hint">
        Scan reads <code>.tscn</code> and <code>[input]</code>. Live inspect runs
        AgentKit against the current scene.
      </p>
      <label>
        project.godot dir
        <input
          value={project}
          onChange={(e) => setProjectPath(e.target.value)}
          onBlur={() => onBind(project)}
        />
      </label>
      <div className="row">
        <button disabled={Boolean(busy)} onClick={() => onBind(project)}>
          Bind
        </button>
        <button disabled={Boolean(busy)} onClick={onScan}>
          Scan scenes
        </button>
        <button disabled={Boolean(busy)} onClick={() => onInspect("")}>
          Live inspect
        </button>
      </div>
      <p className="meta">
        {status.exists ? "project ok" : "no project.godot"} ·{" "}
        {status.agentKit ? "AgentKit" : "no AgentKit"} · {source || "—"} ·{" "}
        {unique.length} % · {actions.length} actions
        {busy ? ` · ${busy}…` : ""}
      </p>
      <h2>Unique names</h2>
      <ul className="catalog">
        {unique.length === 0 && <li className="hint">Scan or inspect to list %nodes</li>}
        {unique.map((item) => (
          <li key={`${item.scene || ""}:${item.unique}`}>
            <button
              type="button"
              className="catalog-item"
              onClick={() => onPickUnique(item)}
              title={item.path || item.scene || item.class}
            >
              <span>{item.unique}</span>
              <em>
                {item.class}
                {item.click ? " · click" : ""}
                {item.type ? " · type" : ""}
              </em>
            </button>
          </li>
        ))}
      </ul>
      <h2>InputMap</h2>
      <ul className="catalog">
        {actions.length === 0 && <li className="hint">Scan or live info for actions</li>}
        {actions.map((name) => (
          <li key={name}>
            <button type="button" className="catalog-item" onClick={() => onPickAction(name)}>
              <span>{name}</span>
            </button>
          </li>
        ))}
      </ul>
    </section>
  );
}
