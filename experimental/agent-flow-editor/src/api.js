async function readJson(res) {
  const text = await res.text();
  try {
    return JSON.parse(text);
  } catch {
    throw new Error(text || `HTTP ${res.status}`);
  }
}

async function request(url, options) {
  const res = await fetch(url, options);
  const data = await readJson(res);
  if (!res.ok) throw new Error(data.error || `HTTP ${res.status}`);
  return data;
}

export function getProject() {
  return request("/api/project");
}

export function setProject(project) {
  return request("/api/project", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ project }),
  });
}

export function scanProject() {
  return request("/api/scan");
}

export function liveInspect(scene = "") {
  return request("/api/inspect", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ scene }),
  });
}

export function liveInfo() {
  return request("/api/info", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({}),
  });
}

export function runFlow(spec) {
  return request("/api/run", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ spec }),
  });
}

export function loadFlow(name) {
  return request(`/api/flow?name=${encodeURIComponent(name)}`);
}

export function shotUrl(name) {
  return `/api/shots/${encodeURIComponent(name)}?t=${Date.now()}`;
}
