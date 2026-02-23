#!/usr/bin/env bash
# VelvetClaw — Memory Archive (Heartbeat Rotation)
#
# Monthly rotation of HEARTBEAT.md entries to keep live files manageable.
# Moves entries older than the 50 most recent to an archive file.
#
# Usage:
#   ./scripts/memory-archive.sh              # Archive all agents
#   ./scripts/memory-archive.sh jarvis       # Archive specific agent

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AGENTS_DIR="$REPO_ROOT/agents"
ARCHIVE_BASE="$REPO_ROOT/logs/archive"
MAX_ENTRIES=50

# ── Helpers ──

log() {
  local timestamp
  timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo "[$timestamp] $*" >&2
}

# ── Archive a single agent's heartbeat ──

archive_agent() {
  local agent_id="$1"
  local heartbeat="$AGENTS_DIR/$agent_id/HEARTBEAT.md"

  if [[ ! -f "$heartbeat" ]]; then
    log "SKIP $agent_id: no HEARTBEAT.md found"
    return 0
  fi

  # Count entries (lines starting with "### [")
  local entry_count
  entry_count=$(grep -c '^### \[' "$heartbeat" 2>/dev/null || echo "0")

  if (( entry_count <= MAX_ENTRIES )); then
    log "OK   $agent_id: $entry_count entries (<= $MAX_ENTRIES), no archival needed"
    return 0
  fi

  local entries_to_archive=$(( entry_count - MAX_ENTRIES ))
  log "ARCHIVE $agent_id: $entry_count entries, archiving oldest $entries_to_archive"

  # Create archive directory
  local archive_dir="$ARCHIVE_BASE/$agent_id"
  mkdir -p "$archive_dir"

  # Determine archive filename from current date
  local archive_month
  archive_month="$(date -u +"%Y-%m")"
  local archive_file="$archive_dir/${archive_month}-heartbeat.md"

  # Extract the header: everything before the first "### [" entry
  local header_end_line
  header_end_line=$(grep -n '^### \[' "$heartbeat" | head -1 | cut -d: -f1)

  if [[ -z "$header_end_line" ]]; then
    log "WARN $agent_id: no entries found matching '### [' pattern"
    return 0
  fi

  local header_lines=$(( header_end_line - 1 ))

  # Extract header (lines before first entry)
  local header
  header=$(head -n "$header_lines" "$heartbeat")

  # Get all entry start line numbers
  local entry_lines
  entry_lines=$(grep -n '^### \[' "$heartbeat" | cut -d: -f1)

  # Find the line number where we split: keep the last MAX_ENTRIES entries
  # The split point is the start of entry (entries_to_archive + 1) counting from top
  local split_entry_num=$(( entries_to_archive + 1 ))
  local split_line
  split_line=$(echo "$entry_lines" | sed -n "${split_entry_num}p")

  if [[ -z "$split_line" ]]; then
    log "WARN $agent_id: could not determine split point"
    return 0
  fi

  # Everything from first entry to just before split_line goes to archive
  local archive_start_line="$header_end_line"
  local archive_end_line=$(( split_line - 1 ))

  # Extract old entries (to archive)
  local old_entries
  old_entries=$(sed -n "${archive_start_line},${archive_end_line}p" "$heartbeat")

  # Extract new entries (to keep)
  local total_lines
  total_lines=$(wc -l < "$heartbeat" | tr -d ' ')
  local new_entries
  new_entries=$(sed -n "${split_line},${total_lines}p" "$heartbeat")

  # Append old entries to archive file
  if [[ -f "$archive_file" ]]; then
    printf "\n%s\n" "$old_entries" >> "$archive_file"
  else
    printf "# %s -- Heartbeat Archive (%s)\n\n%s\n" "$agent_id" "$archive_month" "$old_entries" > "$archive_file"
  fi

  # Rebuild the live heartbeat file: header + recent entries
  printf "%s\n%s\n" "$header" "$new_entries" > "$heartbeat"

  local new_count
  new_count=$(grep -c '^### \[' "$heartbeat" 2>/dev/null || echo "0")
  log "DONE $agent_id: archived $entries_to_archive entries to $archive_file ($new_count entries remain)"
}

# ── Main ──

main() {
  local target_agent="${1:-}"

  if [[ -n "$target_agent" ]]; then
    # Archive specific agent
    if [[ ! -d "$AGENTS_DIR/$target_agent" ]]; then
      log "ERROR: agent '$target_agent' not found in $AGENTS_DIR"
      exit 1
    fi
    archive_agent "$target_agent"
  else
    # Archive all agents
    for agent_dir in "$AGENTS_DIR"/*/; do
      if [[ -d "$agent_dir" ]]; then
        local agent_id
        agent_id="$(basename "$agent_dir")"
        archive_agent "$agent_id"
      fi
    done
  fi
}

main "$@"
