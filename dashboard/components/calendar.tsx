"use client";

interface ScheduledTask {
  id: string;
  title: string;
  agent: string;
  day: string;
  time: string;
  recurring: boolean;
  department: string;
}

const DAYS = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

const AGENT_COLORS: Record<string, string> = {
  JARVIS: "border-blue-500 bg-blue-500/10",
  ATLAS: "border-green-500 bg-green-500/10",
  TRENDY: "border-emerald-500 bg-emerald-500/10",
  SCRIBE: "border-purple-500 bg-purple-500/10",
  CLAWD: "border-orange-500 bg-orange-500/10",
  SENTINEL: "border-red-500 bg-red-500/10",
  PIXEL: "border-teal-500 bg-teal-500/10",
  NOVA: "border-pink-500 bg-pink-500/10",
  VIBE: "border-rose-500 bg-rose-500/10",
  SAGE: "border-amber-500 bg-amber-500/10",
  CLIP: "border-cyan-500 bg-cyan-500/10",
};

// Placeholder data — replaced by Convex queries in production
const SAMPLE_TASKS: ScheduledTask[] = [
  { id: "1", title: "Org-wide status check", agent: "JARVIS", day: "Mon", time: "09:00", recurring: true, department: "org" },
  { id: "2", title: "Trend scan cycle", agent: "TRENDY", day: "Mon", time: "06:00", recurring: true, department: "research" },
  { id: "3", title: "Weekly research digest", agent: "ATLAS", day: "Tue", time: "10:00", recurring: true, department: "research" },
  { id: "4", title: "Content calendar review", agent: "SCRIBE", day: "Tue", time: "14:00", recurring: true, department: "content" },
  { id: "5", title: "Infrastructure health audit", agent: "SENTINEL", day: "Wed", time: "08:00", recurring: true, department: "development" },
  { id: "6", title: "Design review session", agent: "PIXEL", day: "Thu", time: "11:00", recurring: true, department: "design" },
  { id: "7", title: "User engagement report", agent: "SAGE", day: "Fri", time: "15:00", recurring: true, department: "user-success" },
  { id: "8", title: "Clip performance analysis", agent: "CLIP", day: "Fri", time: "16:00", recurring: true, department: "product" },
];

export function Calendar() {
  return (
    <div>
      <h2 className="text-lg font-semibold mb-4">Calendar</h2>
      <p className="text-sm text-gray-400 mb-6">
        Weekly view of all scheduled tasks across all agents.
      </p>

      <div className="grid grid-cols-7 gap-2">
        {/* Day headers */}
        {DAYS.map((day) => (
          <div key={day} className="text-center text-sm font-medium text-gray-400 pb-2 border-b border-gray-800">
            {day}
          </div>
        ))}

        {/* Day columns */}
        {DAYS.map((day) => {
          const dayTasks = SAMPLE_TASKS.filter((t) => t.day === day);
          return (
            <div key={`col-${day}`} className="min-h-[200px] space-y-2 pt-2">
              {dayTasks.map((task) => (
                <div
                  key={task.id}
                  className={`p-2 rounded border-l-2 text-xs ${
                    AGENT_COLORS[task.agent] || "border-gray-500 bg-gray-800"
                  }`}
                >
                  <div className="font-medium text-gray-200">{task.time}</div>
                  <div className="text-gray-400 mt-0.5">{task.title}</div>
                  <div className="text-gray-500 mt-0.5">{task.agent}</div>
                </div>
              ))}
            </div>
          );
        })}
      </div>
    </div>
  );
}
