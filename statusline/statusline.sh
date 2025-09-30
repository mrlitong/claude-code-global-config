#!/bin/bash

# Claude Code statusline script with color output
# Format: 🖥️:hostname | 🎨:output_style | 📂:current_directory | ⏳:session_duration | 🤖:model_version | 🌿:branch_name

# Read JSON input from stdin
input=$(cat)

# Color codes
GREEN='\033[32m'
MAGENTA='\033[35m'
BLUE='\033[34m'
YELLOW='\033[33m'
CYAN='\033[36m'
PURPLE='\033[95m'
GRAY='\033[90m'
RED='\033[31m'
RESET='\033[0m'

# Simple JSON parsing function
parse_json() {
    local key="$1"
    local default="$2"
    local result=$(echo "$input" | sed -n "s/.*\"$key\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -1)
    if [[ -n "$result" ]]; then
        echo "$result"
    else
        echo "$default"
    fi
}

# Parse JSON input
hostname=$(hostname -s)
output_style=$(echo "$input" | sed -n 's/.*"output_style":[[:space:]]*{[[:space:]]*"name":[[:space:]]*"\([^"]*\)".*/\1/p')
[ -z "$output_style" ] && output_style="default"

current_dir=$(parse_json "cwd" "$HOME")
model_name=$(echo "$input" | sed -n 's/.*"display_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
[ -z "$model_name" ] && model_name=$(parse_json "model" "Claude")

# Get session_id for unique session tracking
session_id=$(parse_json "session_id" "unknown")

# Get session start time - use a unique file per session to track when session started
SESSION_FILE="$HOME/.claude/statusline/session_${session_id}"
if [[ ! -f "$SESSION_FILE" ]]; then
    # Create session file with current time if it doesn't exist
    date +%s > "$SESSION_FILE"
fi
session_start=$(cat "$SESSION_FILE" 2>/dev/null || echo $(date +%s))
current_time=$(date +%s)
duration_seconds=$((current_time - session_start))

# Format session duration
if [[ $duration_seconds -lt 60 ]]; then
    duration="<1min"
elif [[ $duration_seconds -lt 3600 ]]; then
    duration_minutes=$((duration_seconds / 60))
    duration="${duration_minutes}min"
else
    duration_hours=$((duration_seconds / 3600))
    duration_remaining_minutes=$(((duration_seconds % 3600) / 60))
    if [[ $duration_remaining_minutes -eq 0 ]]; then
        duration="${duration_hours}h"
    else
        duration="${duration_hours}h${duration_remaining_minutes}min"
    fi
fi

# Format current directory (show only last 2 levels)
smart_path="${current_dir/#$HOME/~}"
IFS='/' read -ra PATH_PARTS <<< "$smart_path"
if [[ ${#PATH_PARTS[@]} -gt 2 ]]; then
    smart_path="${PATH_PARTS[-2]}/${PATH_PARTS[-1]}"
fi

# Format model version
case "$model_name" in
    *"Claude 3"*"Opus"*) model_version="Opus 3" ;;
    *"Claude 3"*"Sonnet"*) model_version="Sonnet 3.5" ;;
    *"Claude 3"*"Haiku"*) model_version="Haiku 3" ;;
    *"Opus 4"*) model_version="Opus 4.1" ;;
    *"Sonnet 4"*) model_version="Sonnet 4.5" ;;
    *"Haiku 4"*) model_version="Haiku 4" ;;
    *"Opus"*) model_version="Opus 4.1" ;;
    *"Sonnet"*) model_version="Sonnet 3.5" ;;
    *"Haiku"*) model_version="Haiku 3" ;;
    *) model_version="Claude" ;;
esac

# Get Git branch information and statistics
git_branch=""
git_section=""
if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    # Get current branch name, handling detached HEAD state
    branch_name=$(git branch --show-current 2>/dev/null)
    if [[ -z "$branch_name" ]]; then
        # If in detached HEAD state, show short commit hash
        branch_name=$(git rev-parse --short HEAD 2>/dev/null)
        [[ -n "$branch_name" ]] && branch_name="detached:$branch_name"
    fi

    # Get git diff statistics (both staged and unstaged)
    git_stats=""
    if [[ -n "$branch_name" ]]; then
        # Get combined statistics for staged and unstaged changes
        STAGED_STATS=$(git diff --staged --shortstat 2>/dev/null)
        UNSTAGED_STATS=$(git diff --shortstat 2>/dev/null)

        # Parse statistics
        files_changed=0
        insertions=0
        deletions=0

        # Parse staged changes
        if [[ -n "$STAGED_STATS" ]]; then
            staged_files=$(echo "$STAGED_STATS" | grep -oE '[0-9]+ file' | grep -oE '[0-9]+' || echo 0)
            staged_ins=$(echo "$STAGED_STATS" | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || echo 0)
            staged_del=$(echo "$STAGED_STATS" | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+' || echo 0)
            files_changed=$((files_changed + staged_files))
            insertions=$((insertions + staged_ins))
            deletions=$((deletions + staged_del))
        fi

        # Parse unstaged changes
        if [[ -n "$UNSTAGED_STATS" ]]; then
            unstaged_files=$(echo "$UNSTAGED_STATS" | grep -oE '[0-9]+ file' | grep -oE '[0-9]+' || echo 0)
            unstaged_ins=$(echo "$UNSTAGED_STATS" | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || echo 0)
            unstaged_del=$(echo "$UNSTAGED_STATS" | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+' || echo 0)
            # Only count unique files (approximation - may count same file twice if both staged and unstaged)
            files_changed=$((files_changed + unstaged_files))
            insertions=$((insertions + unstaged_ins))
            deletions=$((deletions + unstaged_del))
        fi

        # Format git statistics if there are changes
        if [[ $files_changed -gt 0 ]]; then
            git_stats=" ${GRAY}|${RESET} 📝:${YELLOW}${files_changed}${RESET}"
            # Add line changes in parentheses if any
            if [[ $insertions -gt 0 || $deletions -gt 0 ]]; then
                git_stats="${git_stats}("
                if [[ $insertions -gt 0 ]]; then
                    git_stats="${git_stats}${GREEN}+${insertions}${RESET}"
                fi
                if [[ $insertions -gt 0 && $deletions -gt 0 ]]; then
                    git_stats="${git_stats},${RED}-${deletions}${RESET}"
                elif [[ $deletions -gt 0 ]]; then
                    git_stats="${git_stats}${RED}-${deletions}${RESET}"
                fi
                git_stats="${git_stats})"
            fi
        fi

        git_section=" [🌿:${PURPLE}${branch_name}${RESET}${git_stats}]"
    fi
fi

# Get context usage from Claude Code's /context command
context_section=""
# Parse context_usage from input JSON if available
context_tokens=$(echo "$input" | sed -n 's/.*"context_tokens"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p')
context_percentage=$(echo "$input" | sed -n 's/.*"context_percentage"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p')

if [[ -n "$context_tokens" && -n "$context_percentage" ]]; then
    # Convert to k format
    if [[ $context_tokens -ge 1000 ]]; then
        tokens_k=$((context_tokens / 1000))
        context_display="${tokens_k}k/200k"
    else
        context_display="${context_tokens}/200k"
    fi

    # Color based on percentage
    if [[ $context_percentage -le 50 ]]; then
        context_section=" ${GRAY}|${RESET} 📊:${GREEN}${context_display}${RESET}"
    elif [[ $context_percentage -le 80 ]]; then
        context_section=" ${GRAY}|${RESET} 📊:${YELLOW}${context_display}${RESET}"
    else
        context_section=" ${GRAY}|${RESET} 📊:${RED}${context_display}${RESET}"
    fi
else
    # Show N/A in gray if no token info available yet
    context_section=" ${GRAY}|${RESET} 📊:${GRAY}N/A${RESET}"
fi

# Build the status line with colors
# Group 1: Host & Directory | Group 2: Model & Style | Group 3: Performance | Group 4: Git
echo -e "[🖥️:${GREEN}${hostname}${RESET} ${GRAY}|${RESET} 📂:${BLUE}${smart_path}${RESET}] [🤖:${CYAN}${model_version}${RESET} ${GRAY}|${RESET} 🎨:${MAGENTA}${output_style}${RESET}] [⏳:${YELLOW}${duration}${RESET}${context_section}]${git_section}"
