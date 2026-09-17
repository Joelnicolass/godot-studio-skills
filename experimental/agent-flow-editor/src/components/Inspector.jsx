import GodotBinder from "./GodotBinder.jsx";
import NodeFields from "./NodeFields.jsx";
import RunPanel from "./RunPanel.jsx";

export default function Inspector({
  current,
  json,
  draft,
  err,
  unique,
  actions,
  onChange,
  onImport,
  godot,
  onPickUnique,
  onPickAction,
  onPickFlow,
}) {
  return (
    <aside className="inspector">
      <h1>Inspector</h1>
      {!current && <p className="hint">Select a node.</p>}
      {current && (
        <NodeFields node={current} unique={unique} actions={actions} onChange={onChange} />
      )}
      {err && <p className="error">{err}</p>}
      {draft && (
        <>
          <label>JSON</label>
          <textarea value={json} readOnly />
        </>
      )}
      <label>Paste JSON</label>
      <textarea
        placeholder='{ "steps": [] }'
        onBlur={(e) => {
          const t = e.target.value.trim();
          if (t) onImport(t);
        }}
      />
      <GodotBinder
        project={godot.project}
        setProjectPath={godot.setProjectPath}
        status={godot.status}
        unique={unique}
        actions={actions}
        flows={godot.flows}
        source={godot.source}
        busy={godot.busy}
        onBind={godot.bind}
        onScan={godot.scan}
        onInspect={godot.inspect}
        onPickUnique={onPickUnique}
        onPickAction={onPickAction}
        onPickFlow={onPickFlow}
      />
      <RunPanel busy={godot.busy} log={godot.log} shots={godot.shots} runOk={godot.runOk} />
    </aside>
  );
}
