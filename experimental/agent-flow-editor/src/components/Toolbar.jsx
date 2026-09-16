export default function Toolbar({
  busy,
  onCopy,
  onShowJson,
  onImport,
  onRun,
}) {
  return (
    <div className="toolbar">
      <button className="run" disabled={busy === "run"} onClick={onRun}>
        {busy === "run" ? "Running…" : "Run flow"}
      </button>
      <button onClick={onCopy}>Copy JSON</button>
      <button onClick={onShowJson}>Show JSON</button>
      <label className="file">
        Import
        <input
          type="file"
          accept="application/json,.json"
          hidden
          onChange={(e) => {
            const f = e.target.files?.[0];
            if (!f) return;
            f.text().then(onImport);
          }}
        />
      </label>
    </div>
  );
}
