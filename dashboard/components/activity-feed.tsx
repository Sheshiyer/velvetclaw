"use client";

interface Activity {
  id: string;
  agent: string;
  action: string;
  detail: string;
  timestamp: string;
  department: string;
  status: "success" | "in_progress" | "failed";
}

const AGENT_COLORS: Record<string, string> = {
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

const STATUS_ICONS: Record<string, string> = {
  success: "bg-green-500",
  in_progress: "bg-yellow-500",
  failed: "bg-red-500",
};

// Placeholder data — replaced by Convex queries in production
const SAMPLE_ACTIVITIES: Activity[] = [
  {
    id: "1",
    agent: "JARVIS",
    action: "Delegated task",
    detail: "Assigned 'Q1 content strategy' to SCRIBE via content department",
    timestamp: "2 min ago",
    department: "org",
    status: "success",
  },
  {
    id: "2",
    agent: "ATLAS",
    action: "Completed research",
    detail: "Finished competitive analysis brief for Product team",
    timestamp: "8 min ago",
    department: "research",
    status: "success",
  },
  {
    id: "3",
    agent: "SENTINEL",
    action: "Health check",
    detail: "All 12 monitored services responding within SLA",
    timestamp: "10 min ago",
    department: "development",
    status: "success",
  },
  {
    id: "4",
    agent: "SCRIBE",
    action: "Writing content",
    detail: "Drafting blog post: 'Why Autonomous Agents Need Memory'",
    timestamp: "15 min ago",
    department: "content",
    status: "in_progress",
  },
  {
    id: "5",
    agent: "PIXEL",
    action: "Generated visuals",
    detail: "Created 3 hero image variants for blog post",
    timestamp: "22 min ago",
    department: "design",
    status: "success",
  },
];

export function ActivityFeed() {
  return (
    <div className="max-w-3xl">
      <h2 className="text-lg font-semibold mb-4">Activity Feed</h2>
      <p className="text-sm text-gray-400 mb-6">
        Real-time log of every action taken by every agent in the organization.
      </p>

      <div className="space-y-3">
        {SAMPLE_ACTIVITIES.map((activity) => (
          <div
            key={activity.id}
            className="flex items-start gap-3 p-4 rounded-lg bg-gray-900 border border-gray-800"
          >
            {/* Agent avatar */}
            <div
              className={`w-8 h-8 rounded-full flex items-center justify-center text-xs font-bold text-white shrink-0 ${
                AGENT_COLORS[activity.agent] || "bg-gray-600"
              }`}
            >
              {activity.agent.slice(0, 2)}
            </div>

            {/* Content */}
            <div className="flex-1 min-w-0">
              <div className="flex items-center gap-2">
                <span className="font-medium text-sm">{activity.agent}</span>
                <span className="text-gray-500 text-xs">{activity.action}</span>
                <div
                  className={`w-1.5 h-1.5 rounded-full ${
                    STATUS_ICONS[activity.status]
                  }`}
                />
              </div>
              <p className="text-sm text-gray-400 mt-0.5">{activity.detail}</p>
            </div>

            {/* Timestamp */}
            <span className="text-xs text-gray-500 shrink-0">
              {activity.timestamp}
            </span>
          </div>
        ))}
      </div>
    </div>
  );
}
