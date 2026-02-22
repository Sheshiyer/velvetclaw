"use client";

import { useState } from "react";

interface SearchResult {
  id: string;
  type: "memory" | "task" | "decision" | "lesson" | "document";
  title: string;
  snippet: string;
  agent: string;
  path: string;
  relevance: number;
}

// Placeholder data — replaced by Convex semantic search in production
const SAMPLE_RESULTS: SearchResult[] = [
  {
    id: "1",
    type: "memory",
    title: "Authentication Architecture Decision",
    snippet: "Decided to use JWT with refresh tokens for the API gateway...",
    agent: "CLAWD",
    path: "workspace-clawd/memory/2026-02-15.md",
    relevance: 0.95,
  },
  {
    id: "2",
    type: "decision",
    title: "Shipping Provider Selection",
    snippet: "Chose FedEx for domestic, DHL for international. Rationale: cost per...",
    agent: "JARVIS",
    path: "shared/decisions/shipping-provider.md",
    relevance: 0.88,
  },
  {
    id: "3",
    type: "lesson",
    title: "API Rate Limiting Lesson",
    snippet: "LLM APIs silently drop requests above 60 RPM. Always implement...",
    agent: "SENTINEL",
    path: "workspace-sentinel/lessons/api-rate-limits.md",
    relevance: 0.82,
  },
];

const TYPE_BADGES: Record<string, string> = {
  memory: "bg-blue-500/20 text-blue-400",
  task: "bg-green-500/20 text-green-400",
  decision: "bg-purple-500/20 text-purple-400",
  lesson: "bg-amber-500/20 text-amber-400",
  document: "bg-gray-500/20 text-gray-400",
};

export function GlobalSearch() {
  const [query, setQuery] = useState("");
  const [results] = useState<SearchResult[]>(SAMPLE_RESULTS);

  return (
    <div className="max-w-3xl">
      <h2 className="text-lg font-semibold mb-4">Global Search</h2>
      <p className="text-sm text-gray-400 mb-6">
        Search across all agent memories, tasks, decisions, and documents.
      </p>

      {/* Search input */}
      <div className="relative mb-6">
        <input
          type="text"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="Search memories, tasks, decisions, lessons..."
          className="w-full px-4 py-3 bg-gray-900 border border-gray-700 rounded-lg text-sm text-gray-100 placeholder-gray-500 focus:outline-none focus:border-blue-500"
        />
      </div>

      {/* Results */}
      <div className="space-y-3">
        {results.map((result) => (
          <div
            key={result.id}
            className="p-4 rounded-lg bg-gray-900 border border-gray-800 hover:border-gray-700 transition-colors"
          >
            <div className="flex items-center gap-2 mb-1">
              <span
                className={`px-2 py-0.5 rounded text-xs font-medium ${
                  TYPE_BADGES[result.type]
                }`}
              >
                {result.type}
              </span>
              <span className="text-sm font-medium">{result.title}</span>
              <span className="ml-auto text-xs text-gray-500">
                {Math.round(result.relevance * 100)}% match
              </span>
            </div>
            <p className="text-sm text-gray-400">{result.snippet}</p>
            <div className="flex items-center gap-2 mt-2 text-xs text-gray-500">
              <span>{result.agent}</span>
              <span>|</span>
              <span className="font-mono">{result.path}</span>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
