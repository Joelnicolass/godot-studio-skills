function Field({ data, fieldKey, label, type = "text", list, onChange }) {
  return (
    <label>
      {label}
      <input
        type={type}
        list={list}
        value={data[fieldKey] ?? ""}
        onChange={(e) =>
          onChange({
            [fieldKey]: type === "number" ? Number(e.target.value) : e.target.value,
          })
        }
      />
    </label>
  );
}

export default function NodeFields({ node, unique = [], actions = [], onChange }) {
  const d = node.data;
  const names = unique.map((u) => u.unique);
  const clickNames = unique.filter((u) => u.click).map((u) => u.unique);
  const typeNames = unique.filter((u) => u.type).map((u) => u.unique);

  switch (node.kind) {
    case "flow":
      return (
        <>
          <Field data={d} fieldKey="scene" label="scene (res:// or empty)" onChange={onChange} />
          <Field
            data={d}
            fieldKey="wait_first"
            label="wait_first"
            type="number"
            onChange={onChange}
          />
        </>
      );
    case "shot":
      return <Field data={d} fieldKey="name" label="png filename" onChange={onChange} />;
    case "click":
    case "try_click":
      return (
        <>
          <Field
            data={d}
            fieldKey="node"
            label="%UniqueName"
            list="godot-click-nodes"
            onChange={onChange}
          />
          <NodeList id="godot-click-nodes" names={clickNames.length ? clickNames : names} />
        </>
      );
    case "press":
      return (
        <>
          <Field
            data={d}
            fieldKey="name"
            label="InputMap action"
            list="godot-actions"
            onChange={onChange}
          />
          <NodeList id="godot-actions" names={actions} />
        </>
      );
    case "wait":
      return (
        <Field data={d} fieldKey="seconds" label="seconds" type="number" onChange={onChange} />
      );
    case "type":
      return (
        <>
          <Field
            data={d}
            fieldKey="node"
            label="node"
            list="godot-type-nodes"
            onChange={onChange}
          />
          <Field data={d} fieldKey="text" label="text" onChange={onChange} />
          <NodeList id="godot-type-nodes" names={typeNames.length ? typeNames : names} />
        </>
      );
    case "print":
      return (
        <>
          <Field data={d} fieldKey="node" label="node" list="godot-nodes" onChange={onChange} />
          <Field data={d} fieldKey="prop" label="prop" onChange={onChange} />
          <NodeList id="godot-nodes" names={names} />
        </>
      );
    case "wait_until":
    case "assert":
      return (
        <>
          <Field data={d} fieldKey="node" label="node" list="godot-nodes" onChange={onChange} />
          <label>
            key
            <select value={d.key} onChange={(e) => onChange({ key: e.target.value })}>
              <option value="disabled">disabled</option>
              <option value="visible">visible</option>
              <option value="visible_in_tree">visible_in_tree</option>
              <option value="text_contains">text_contains</option>
              <option value="text_equals">text_equals</option>
            </select>
          </label>
          <Field data={d} fieldKey="value" label="value" onChange={onChange} />
          {node.kind === "wait_until" && (
            <Field
              data={d}
              fieldKey="timeout"
              label="timeout"
              type="number"
              onChange={onChange}
            />
          )}
          <NodeList id="godot-nodes" names={names} />
        </>
      );
    case "repeat":
      return (
        <>
          <Field data={d} fieldKey="times" label="times" type="number" onChange={onChange} />
          <label>
            until (JSON)
            <textarea value={d.until} onChange={(e) => onChange({ until: e.target.value })} />
          </label>
        </>
      );
    default:
      return null;
  }
}

function NodeList({ id, names }) {
  if (!names.length) return null;
  return (
    <datalist id={id}>
      {names.map((name) => (
        <option key={name} value={name} />
      ))}
    </datalist>
  );
}
