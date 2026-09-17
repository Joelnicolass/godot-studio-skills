export default function GodotBinder({
  project,
  setProjectPath,
  status,
  unique,
  actions,
  flows = [],
  source,
  busy,
  onBind,
  onScan,
  onInspect,
  onPickUnique,
  onPickAction,
  onPickFlow,
}) {
  return (
    <section className="binder">
      <h1>Godot</h1>
      <p className="hint">
        Scan lee <code>.tscn</code> y <code>[input]</code>. Live inspect corre
        AgentKit contra la escena actual.
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
        {status.agentKit ? "AgentKit" : "sin AgentKit"} · {source || "—"} ·{" "}
        {unique.length} % · {actions.length} actions
        {busy ? ` · ${busy}…` : ""}
      </p>
      <h2>agent/flows</h2>
      <ul className="catalog">
        {flows.length === 0 && (
          <li className="hint">JSON de playtest en res://agent/flows (no en el addon)</li>
        )}
        {flows.map((item) => (
          <li key={item.file || item.name}>
            <button
              type="button"
              className="catalog-item"
              onClick={() => onPickFlow(item)}
              title={item.file}
            >
              <span>{item.name}</span>
            </button>
          </li>
        ))}
      </ul>
      <h2>Unique names</h2>
      <ul className="catalog">
        {unique.length === 0 && <li className="hint">Scan o inspect para listar %nodos</li>}
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
                {item.select ? " · select" : ""}
                {item.range ? " · range" : ""}
                {item.scroll ? " · scroll" : ""}
              </em>
            </button>
          </li>
        ))}
      </ul>
      <h2>InputMap</h2>
      <ul className="catalog">
        {actions.length === 0 && <li className="hint">Scan o live info para acciones</li>}
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
