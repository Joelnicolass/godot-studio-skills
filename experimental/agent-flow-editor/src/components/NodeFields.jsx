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
  const selectNames = unique.filter((u) => u.select).map((u) => u.unique);
  const rangeNames = unique.filter((u) => u.range).map((u) => u.unique);
  const scrollNames = unique.filter((u) => u.scroll).map((u) => u.unique);

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
      return (
        <>
          <Field data={d} fieldKey="name" label="png filename" onChange={onChange} />
          <Field data={d} fieldKey="node" label="crop to %node (optional)" list="godot-nodes" onChange={onChange} />
          <NodeList id="godot-nodes" names={names} />
        </>
      );
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
          <Field data={d} fieldKey="hold" label="hold seconds (0 = pulse)" type="number" onChange={onChange} />
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
    case "select":
      return (
        <>
          <Field data={d} fieldKey="node" label="node" list="godot-select-nodes" onChange={onChange} />
          <Field data={d} fieldKey="index" label="index" type="number" onChange={onChange} />
          <Field data={d} fieldKey="text" label="text (wins over index)" onChange={onChange} />
          <NodeList id="godot-select-nodes" names={selectNames.length ? selectNames : names} />
        </>
      );
    case "range":
      return (
        <>
          <Field data={d} fieldKey="node" label="node" list="godot-range-nodes" onChange={onChange} />
          <Field data={d} fieldKey="value" label="value" type="number" onChange={onChange} />
          <NodeList id="godot-range-nodes" names={rangeNames.length ? rangeNames : names} />
        </>
      );
    case "scroll":
      return (
        <>
          <Field data={d} fieldKey="node" label="node" list="godot-scroll-nodes" onChange={onChange} />
          <Field data={d} fieldKey="vertical" label="vertical" type="number" onChange={onChange} />
          <Field data={d} fieldKey="horizontal" label="horizontal" type="number" onChange={onChange} />
          <NodeList id="godot-scroll-nodes" names={scrollNames.length ? scrollNames : names} />
        </>
      );
    case "drag":
      return (
        <>
          <Field data={d} fieldKey="node" label="node" list="godot-nodes" onChange={onChange} />
          <Field data={d} fieldKey="from_x" label="from_x" type="number" onChange={onChange} />
          <Field data={d} fieldKey="from_y" label="from_y" type="number" onChange={onChange} />
          <Field data={d} fieldKey="to_x" label="to_x" type="number" onChange={onChange} />
          <Field data={d} fieldKey="to_y" label="to_y" type="number" onChange={onChange} />
          <NodeList id="godot-nodes" names={names} />
        </>
      );
    case "call":
      return (
        <>
          <Field
            data={d}
            fieldKey="harness"
            label="harness (res://agent/harness/*.gd, wins over node)"
            onChange={onChange}
          />
          <Field data={d} fieldKey="node" label="node (game, optional)" list="godot-nodes" onChange={onChange} />
          <Field data={d} fieldKey="method" label="method" onChange={onChange} />
          <label>
            args (JSON array)
            <textarea value={d.args} onChange={(e) => onChange({ args: e.target.value })} />
          </label>
          <NodeList id="godot-nodes" names={names} />
        </>
      );
    case "scene":
      return <Field data={d} fieldKey="path" label="res:// scene" onChange={onChange} />;
    case "seed":
      return <Field data={d} fieldKey="value" label="seed" type="number" onChange={onChange} />;
    case "time_scale":
      return <Field data={d} fieldKey="value" label="Engine.time_scale" type="number" onChange={onChange} />;
    case "diff":
      return (
        <>
          <Field data={d} fieldKey="a" label="a.png" onChange={onChange} />
          <Field data={d} fieldKey="b" label="b.png" onChange={onChange} />
          <Field data={d} fieldKey="out" label="overlay png" onChange={onChange} />
          <Field data={d} fieldKey="threshold" label="threshold" type="number" onChange={onChange} />
          <Field data={d} fieldKey="max_percent" label="max_percent (fail above)" type="number" onChange={onChange} />
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
          {node.kind === "wait_until" && (
            <Field data={d} fieldKey="signal" label="signal (optional, e.g. pressed)" onChange={onChange} />
          )}
          <label>
            key
            <select value={d.key} onChange={(e) => onChange({ key: e.target.value })}>
              <option value="disabled">disabled</option>
              <option value="visible">visible</option>
              <option value="visible_in_tree">visible_in_tree</option>
              <option value="text_contains">text_contains</option>
              <option value="text_equals">text_equals</option>
              <option value="texture_path_contains">texture_path_contains</option>
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
