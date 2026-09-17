import Canvas from "./components/Canvas.jsx";
import Inspector from "./components/Inspector.jsx";
import Palette from "./components/Palette.jsx";
import Toolbar from "./components/Toolbar.jsx";
import { EXAMPLE, kindUsesAction, kindUsesNode } from "./graph.js";
import { useFlowGraph } from "./hooks/useFlowGraph.js";
import { useGodotProject } from "./hooks/useGodotProject.js";

export default function App() {
  const graph = useFlowGraph();
  const godot = useGodotProject();

  function pickUnique(item) {
    if (!graph.current || !kindUsesNode(graph.current.kind)) {
      graph.setErr("Seleccioná un nodo que acepte %UniqueName para pegar " + item.unique);
      return;
    }
    graph.setErr("");
    graph.updateData({ node: item.unique });
  }

  function pickAction(name) {
    if (!graph.current || !kindUsesAction(graph.current.kind)) {
      graph.setErr("Seleccioná un nodo Press action para pegar " + name);
      return;
    }
    graph.setErr("");
    graph.updateData({ name });
  }

  async function pickFlow(item) {
    try {
      const spec = await godot.loadWorkspaceFlow(item.name);
      graph.loadSpec(spec);
      graph.setErr("");
    } catch (err) {
      graph.setErr(String(err.message || err));
    }
  }

  return (
    <div className="app">
      <Palette
        onAdd={graph.addKind}
        onLoadExample={() => graph.loadSpec(EXAMPLE)}
        onDelete={graph.removeSelected}
      />
      <div className="stage-wrap">
        <Toolbar
          busy={godot.busy}
          onCopy={() => navigator.clipboard.writeText(graph.json)}
          onShowJson={() => graph.setDraft(true)}
          onImport={graph.importText}
          onRun={() => godot.run(graph.spec)}
        />
        <Canvas
          nodes={graph.nodes}
          setNodes={graph.setNodes}
          edges={graph.edges}
          setEdges={graph.setEdges}
          selected={graph.selected}
          setSelected={graph.setSelected}
          link={graph.link}
          setLink={graph.setLink}
          drag={graph.drag}
        />
      </div>
      <Inspector
        current={graph.current}
        json={graph.json}
        draft={graph.draft}
        err={graph.err}
        unique={godot.unique}
        actions={godot.actions}
        onChange={graph.updateData}
        onImport={graph.importText}
        godot={godot}
        onPickUnique={pickUnique}
        onPickAction={pickAction}
        onPickFlow={pickFlow}
      />
    </div>
  );
}
