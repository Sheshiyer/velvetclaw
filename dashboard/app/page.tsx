"use client";

import { useState } from "react";
import { ActivityFeed } from "@/components/activity-feed";
import { Calendar } from "@/components/calendar";
import { GlobalSearch } from "@/components/global-search";
import { OrgChart } from "@/components/org-chart";
import { UsageTracker } from "@/components/usage-tracker";

type Tab = "activity" | "calendar" | "search" | "org" | "usage";

const tabs: { id: Tab; label: string; icon: string }[] = [
  { id: "activity", label: "Activity Feed", icon: "zap" },
  { id: "calendar", label: "Calendar", icon: "calendar" },
  { id: "search", label: "Global Search", icon: "search" },
  { id: "org", label: "Org Chart", icon: "network" },
  { id: "usage", label: "Usage", icon: "bar-chart" },
];

export default function MissionControl() {
  const [activeTab, setActiveTab] = useState<Tab>("activity");

  return (
    <div className="flex flex-col h-screen">
      {/* Header */}
      <header className="border-b border-gray-800 px-6 py-4">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-xl font-semibold">VelvetClaw Mission Control</h1>
            <p className="text-sm text-gray-400">Multi-agent organization dashboard</p>
          </div>
          <div className="flex items-center gap-3">
            <div className="h-2 w-2 rounded-full bg-green-500" />
            <span className="text-sm text-gray-400">All systems operational</span>
          </div>
        </div>
      </header>

      {/* Tab Navigation */}
      <nav className="border-b border-gray-800 px-6">
        <div className="flex gap-1">
          {tabs.map((tab) => (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id)}
              className={`px-4 py-3 text-sm font-medium border-b-2 transition-colors ${
                activeTab === tab.id
                  ? "border-blue-500 text-blue-400"
                  : "border-transparent text-gray-400 hover:text-gray-200"
              }`}
            >
              {tab.label}
            </button>
          ))}
        </div>
      </nav>

      {/* Tab Content */}
      <main className="flex-1 overflow-auto p-6">
        {activeTab === "activity" && <ActivityFeed />}
        {activeTab === "calendar" && <Calendar />}
        {activeTab === "search" && <GlobalSearch />}
        {activeTab === "org" && <OrgChart />}
        {activeTab === "usage" && <UsageTracker />}
      </main>
    </div>
  );
}
