import { shotUrl } from "../api.js";

function lineClass(line) {
  if (/AGENT_FAIL|AGENT_STEP_ERROR|SCRIPT ERROR|^ERROR:/.test(line)) return "log-err";
  if (/WARNING:|AGENT_ERRORS \[\{/.test(line)) return "log-warn";
  if (/AGENT_STEP |AGENT_OK |AGENT_ASSERT ok/.test(line)) return "log-step";
  return "";
}

export default function RunPanel({ busy, log, shots, runOk }) {
  const lines = log ? log.split(/\r?\n/) : [];
  const engineHits = lines.filter((line) =>
    /AGENT_STEP_ERROR|SCRIPT ERROR|^ERROR:|AGENT_FAIL/.test(line)
  );
  return (
    <section className="run-panel">
      <h1>Run log</h1>
      {runOk === true && <p className="ok">AGENT_OK flow</p>}
      {runOk === false && <p className="error">flow falló o no arrancó Godot</p>}
      {busy === "run" && <p className="hint">Godot está corriendo el flow…</p>}
      {engineHits.length > 0 && (
        <p className="error">Consola: {engineHits.length} error(es) / FAIL en el log</p>
      )}
      {log && (
        <pre className="run-log">
          {lines.map((line, i) => (
            <span key={i} className={lineClass(line)}>
              {line}
              {i < lines.length - 1 ? "\n" : ""}
            </span>
          ))}
        </pre>
      )}
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
