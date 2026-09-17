import { useCallback, useEffect, useState } from "react";
import { getProject, liveInfo, liveInspect, loadFlow, runFlow, scanProject, setProject } from "../api.js";

export function useGodotProject() {
  const [project, setProjectPath] = useState("");
  const [status, setStatus] = useState({ exists: false, agentKit: false });
  const [unique, setUnique] = useState([]);
  const [actions, setActions] = useState([]);
  const [flows, setFlows] = useState([]);
  const [source, setSource] = useState("");
  const [busy, setBusy] = useState("");
  const [log, setLog] = useState("");
  const [shots, setShots] = useState([]);
  const [runOk, setRunOk] = useState(null);

  const applyCatalog = useCallback((data) => {
    if (data.unique) setUnique(data.unique);
    if (data.actions) setActions(data.actions);
    if (data.flows) setFlows(data.flows);
    if (data.source) setSource(data.source);
    if (data.project) setProjectPath(data.project);
    setStatus({ exists: Boolean(data.exists), agentKit: Boolean(data.agentKit) });
    if (data.log) setLog(data.log);
  }, []);

  useEffect(() => {
    getProject()
      .then((data) => {
        applyCatalog(data);
        return scanProject();
      })
      .then(applyCatalog)
      .catch((err) => setLog(String(err.message || err)));
  }, [applyCatalog]);

  const bind = useCallback(
    async (nextPath) => {
      setBusy("bind");
      try {
        const data = await setProject(nextPath || project);
        applyCatalog(data);
        const scanned = await scanProject();
        applyCatalog(scanned);
      } catch (err) {
        setLog(String(err.message || err));
      } finally {
        setBusy("");
      }
    },
    [applyCatalog, project]
  );

  const scan = useCallback(async () => {
    setBusy("scan");
    try {
      applyCatalog(await scanProject());
    } catch (err) {
      setLog(String(err.message || err));
    } finally {
      setBusy("");
    }
  }, [applyCatalog]);

  const inspect = useCallback(
    async (scene = "") => {
      setBusy("inspect");
      try {
        const data = await liveInspect(scene);
        applyCatalog(data);
        const info = await liveInfo();
        applyCatalog({
          ...data,
          actions: info.actions?.length ? info.actions : data.actions,
          log: [data.log, info.log].filter(Boolean).join("\n"),
        });
      } catch (err) {
        setLog(String(err.message || err));
      } finally {
        setBusy("");
      }
    },
    [applyCatalog]
  );

  const loadWorkspaceFlow = useCallback(async (name) => {
    const data = await loadFlow(name);
    return data.spec;
  }, []);

  const run = useCallback(async (spec) => {
    setBusy("run");
    setRunOk(null);
    setShots([]);
    try {
      const data = await runFlow(spec);
      setLog(data.log || "");
      setShots(data.shots || []);
      setRunOk(Boolean(data.ok));
      if (data.project) setProjectPath(data.project);
      return data;
    } catch (err) {
      const message = String(err.message || err);
      setLog(message);
      setRunOk(false);
      return { ok: false, log: message, shots: [] };
    } finally {
      setBusy("");
    }
  }, []);

  return {
    project,
    setProjectPath,
    status,
    unique,
    actions,
    flows,
    source,
    busy,
    log,
    shots,
    runOk,
    bind,
    scan,
    inspect,
    loadWorkspaceFlow,
    run,
  };
}
