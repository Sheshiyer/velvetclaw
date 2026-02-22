"use client";

interface AgentUsage {
  agent: string;
  department: string;
  tokensToday: number;
  tokensWeek: number;
  tokensMonth: number;
  costToday: number;
  costWeek: number;
  costMonth: number;
  tasksCompleted: number;
}

// Placeholder data — replaced by Convex aggregations in production
const USAGE_DATA: AgentUsage[] = [
  { agent: "JARVIS", department: "Org", tokensToday: 45200, tokensWeek: 312000, tokensMonth: 1240000, costToday: 0.68, costWeek: 4.68, costMonth: 18.60, tasksCompleted: 12 },
  { agent: "ATLAS", department: "Research", tokensToday: 128000, tokensWeek: 890000, tokensMonth: 3560000, costToday: 1.92, costWeek: 13.35, costMonth: 53.40, tasksCompleted: 8 },
  { agent: "TRENDY", department: "Research", tokensToday: 34000, tokensWeek: 238000, tokensMonth: 952000, costToday: 0.51, costWeek: 3.57, costMonth: 14.28, tasksCompleted: 24 },
  { agent: "SCRIBE", department: "Content", tokensToday: 89000, tokensWeek: 623000, tokensMonth: 2492000, costToday: 1.34, costWeek: 9.35, costMonth: 37.38, tasksCompleted: 6 },
  { agent: "CLAWD", department: "Development", tokensToday: 156000, tokensWeek: 1092000, tokensMonth: 4368000, costToday: 2.34, costWeek: 16.38, costMonth: 65.52, tasksCompleted: 15 },
  { agent: "SENTINEL", department: "Development", tokensToday: 22000, tokensWeek: 154000, tokensMonth: 616000, costToday: 0.33, costWeek: 2.31, costMonth: 9.24, tasksCompleted: 48 },
  { agent: "PIXEL", department: "Design", tokensToday: 67000, tokensWeek: 469000, tokensMonth: 1876000, costToday: 1.01, costWeek: 7.04, costMonth: 28.14, tasksCompleted: 10 },
  { agent: "NOVA", department: "Design", tokensToday: 0, tokensWeek: 210000, tokensMonth: 840000, costToday: 0, costWeek: 3.15, costMonth: 12.60, tasksCompleted: 3 },
  { agent: "VIBE", department: "Design", tokensToday: 0, tokensWeek: 140000, tokensMonth: 560000, costToday: 0, costWeek: 2.10, costMonth: 8.40, tasksCompleted: 5 },
  { agent: "SAGE", department: "User Success", tokensToday: 41000, tokensWeek: 287000, tokensMonth: 1148000, costToday: 0.62, costWeek: 4.31, costMonth: 17.22, tasksCompleted: 18 },
  { agent: "CLIP", department: "Product", tokensToday: 53000, tokensWeek: 371000, tokensMonth: 1484000, costToday: 0.80, costWeek: 5.57, costMonth: 22.26, tasksCompleted: 14 },
];

function formatTokens(n: number): string {
  if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1)}M`;
  if (n >= 1_000) return `${(n / 1_000).toFixed(0)}K`;
  return n.toString();
}

export function UsageTracker() {
  const totalToday = USAGE_DATA.reduce((sum, a) => sum + a.costToday, 0);
  const totalWeek = USAGE_DATA.reduce((sum, a) => sum + a.costWeek, 0);
  const totalMonth = USAGE_DATA.reduce((sum, a) => sum + a.costMonth, 0);
  const totalTasks = USAGE_DATA.reduce((sum, a) => sum + a.tasksCompleted, 0);

  return (
    <div>
      <h2 className="text-lg font-semibold mb-4">Usage Tracker</h2>
      <p className="text-sm text-gray-400 mb-6">
        Token consumption and cost per agent, department, and time period.
      </p>

      {/* Summary cards */}
      <div className="grid grid-cols-4 gap-4 mb-8">
        <div className="p-4 rounded-lg bg-gray-900 border border-gray-800">
          <div className="text-xs text-gray-400 uppercase tracking-wider">Today</div>
          <div className="text-2xl font-semibold mt-1">${totalToday.toFixed(2)}</div>
        </div>
        <div className="p-4 rounded-lg bg-gray-900 border border-gray-800">
          <div className="text-xs text-gray-400 uppercase tracking-wider">This Week</div>
          <div className="text-2xl font-semibold mt-1">${totalWeek.toFixed(2)}</div>
        </div>
        <div className="p-4 rounded-lg bg-gray-900 border border-gray-800">
          <div className="text-xs text-gray-400 uppercase tracking-wider">This Month</div>
          <div className="text-2xl font-semibold mt-1">${totalMonth.toFixed(2)}</div>
        </div>
        <div className="p-4 rounded-lg bg-gray-900 border border-gray-800">
          <div className="text-xs text-gray-400 uppercase tracking-wider">Tasks Completed</div>
          <div className="text-2xl font-semibold mt-1">{totalTasks}</div>
        </div>
      </div>

      {/* Agent breakdown table */}
      <div className="rounded-lg border border-gray-800 overflow-hidden">
        <table className="w-full text-sm">
          <thead>
            <tr className="bg-gray-900 text-gray-400 text-xs uppercase tracking-wider">
              <th className="text-left p-3">Agent</th>
              <th className="text-left p-3">Department</th>
              <th className="text-right p-3">Today</th>
              <th className="text-right p-3">Week</th>
              <th className="text-right p-3">Month</th>
              <th className="text-right p-3">Cost/Mo</th>
              <th className="text-right p-3">Tasks</th>
            </tr>
          </thead>
          <tbody>
            {USAGE_DATA.map((row) => (
              <tr key={row.agent} className="border-t border-gray-800 hover:bg-gray-900/50">
                <td className="p-3 font-medium">{row.agent}</td>
                <td className="p-3 text-gray-400">{row.department}</td>
                <td className="p-3 text-right text-gray-300">{formatTokens(row.tokensToday)}</td>
                <td className="p-3 text-right text-gray-300">{formatTokens(row.tokensWeek)}</td>
                <td className="p-3 text-right text-gray-300">{formatTokens(row.tokensMonth)}</td>
                <td className="p-3 text-right text-gray-300">${row.costMonth.toFixed(2)}</td>
                <td className="p-3 text-right text-gray-300">{row.tasksCompleted}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
