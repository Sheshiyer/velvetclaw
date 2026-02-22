"use client";

interface Agent {
  id: string;
  name: string;
  role: string;
  department: string | null;
  status: "online" | "offline" | "busy";
  lastHeartbeat: string;
  capabilities: string[];
}

const STATUS_COLORS: Record<string, string> = {
  online: "bg-green-500",
  offline: "bg-red-500",
  busy: "bg-yellow-500",
};

const AGENT_BG: Record<string, string> = {
  JARVIS: "bg-blue-600",
  ATLAS: "bg-green-500",
  TRENDY: "bg-emerald-500",
  SCRIBE: "bg-purple-500",
  CLAWD: "bg-orange-500",
  SENTINEL: "bg-red-500",
  PIXEL: "bg-teal-500",
  NOVA: "bg-pink-500",
  VIBE: "bg-rose-500",
  SAGE: "bg-amber-500",
  CLIP: "bg-cyan-500",
};

// Placeholder data — replaced by live heartbeat data in production
const AGENTS: Agent[] = [
  { id: "jarvis", name: "JARVIS", role: "Chief Strategy Officer", department: null, status: "online", lastHeartbeat: "30s ago", capabilities: ["Strategic Planning", "Task Orchestration"] },
  { id: "atlas", name: "ATLAS", role: "Senior Research Analyst", department: "Research", status: "online", lastHeartbeat: "2m ago", capabilities: ["Deep Research", "Web Search"] },
  { id: "trendy", name: "TRENDY", role: "Viral Scout", department: "Research", status: "online", lastHeartbeat: "5m ago", capabilities: ["Trend Detection", "Viral Content Scouting"] },
  { id: "scribe", name: "SCRIBE", role: "Content Director", department: "Content", status: "busy", lastHeartbeat: "1m ago", capabilities: ["Content Creation", "Voice Analysis"] },
  { id: "clawd", name: "CLAWD", role: "Senior Software Engineer", department: "Development", status: "online", lastHeartbeat: "1m ago", capabilities: ["Full-Stack Development", "Multi-Agent Review"] },
  { id: "sentinel", name: "SENTINEL", role: "QA & Business Monitor", department: "Development", status: "online", lastHeartbeat: "30s ago", capabilities: ["Uptime Monitoring", "Code Review"] },
  { id: "pixel", name: "PIXEL", role: "Lead Designer", department: "Design", status: "online", lastHeartbeat: "3m ago", capabilities: ["Design Concepts", "Image Generation"] },
  { id: "nova", name: "NOVA", role: "Video Production Lead", department: "Design", status: "offline", lastHeartbeat: "15m ago", capabilities: ["Video Planning", "Video Generation"] },
  { id: "vibe", name: "VIBE", role: "Senior Motion Designer", department: "Design", status: "offline", lastHeartbeat: "20m ago", capabilities: ["Motion Graphics", "Launch Videos"] },
  { id: "sage", name: "SAGE", role: "User Success Agent", department: "User Success", status: "online", lastHeartbeat: "2m ago", capabilities: ["User Segmentation", "Personalized Emails"] },
  { id: "clip", name: "CLIP", role: "Clipping Agent", department: "Product", status: "online", lastHeartbeat: "4m ago", capabilities: ["Video Clipping", "Caption Generation"] },
];

const departments = ["Research", "Content", "Development", "Design", "User Success", "Product"];

function AgentCard({ agent }: { agent: Agent }) {
  return (
    <div className="p-3 rounded-lg bg-gray-900 border border-gray-800">
      <div className="flex items-center gap-2">
        <div
          className={`w-8 h-8 rounded-full flex items-center justify-center text-xs font-bold text-white ${
            AGENT_BG[agent.name] || "bg-gray-600"
          }`}
        >
          {agent.name.slice(0, 2)}
        </div>
        <div className="flex-1">
          <div className="flex items-center gap-2">
            <span className="font-medium text-sm">{agent.name}</span>
            <div className={`w-2 h-2 rounded-full ${STATUS_COLORS[agent.status]}`} />
          </div>
          <span className="text-xs text-gray-400">{agent.role}</span>
        </div>
      </div>
      <div className="flex flex-wrap gap-1 mt-2">
        {agent.capabilities.map((cap) => (
          <span key={cap} className="px-2 py-0.5 rounded text-[10px] bg-gray-800 text-gray-400 uppercase tracking-wider">
            {cap}
          </span>
        ))}
      </div>
      <div className="text-[10px] text-gray-500 mt-2">
        Last heartbeat: {agent.lastHeartbeat}
      </div>
    </div>
  );
}

export function OrgChart() {
  const jarvis = AGENTS.find((a) => a.id === "jarvis")!;

  return (
    <div>
      <h2 className="text-lg font-semibold mb-4">Organization Chart</h2>
      <p className="text-sm text-gray-400 mb-6">
        Live agent hierarchy with heartbeat status.
      </p>

      {/* JARVIS at top */}
      <div className="flex justify-center mb-8">
        <div className="w-80">
          <AgentCard agent={jarvis} />
        </div>
      </div>

      {/* Departments grid */}
      <div className="grid grid-cols-3 gap-4">
        {departments.map((dept) => {
          const deptAgents = AGENTS.filter((a) => a.department === dept);
          return (
            <div key={dept} className="p-4 rounded-lg border border-gray-800">
              <h3 className="text-sm font-medium text-gray-300 mb-3 uppercase tracking-wider">
                {dept}
              </h3>
              <div className="space-y-2">
                {deptAgents.map((agent) => (
                  <AgentCard key={agent.id} agent={agent} />
                ))}
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
