import { shotUrl } from "../api.js";

export default function RunPanel({ busy, log, shots, runOk }) {
  return (
    <section className="run-panel">
      <h1>Run log</h1>
      {runOk === true && <p className="ok">AGENT_OK flow</p>}
      {runOk === false && <p className="error">flow failed or Godot did not start</p>}
      {busy === "run" && <p className="hint">Godot is running the flow…</p>}
      {log && <pre className="run-log">{log}</pre>}
      {shots.length > 0 && (
        <div className="shots">
          {shots.map((name) => (
            <figure key={name}>
              <img src={shotUrl(name)} alt={name} />
              <figcaption>{name}</figcaption>
            </figure>
          ))}
        </div>
      )}
    </section>
  );
}
