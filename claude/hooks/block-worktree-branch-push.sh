#!/bin/bash
# PreToolUse(Bash) hook: block pushing throwaway claude/* worktree branches.
# Allowed: refspec pushes (git push origin HEAD:feature/x), branch deletes.
# Blocked: any push that would create/update a claude/* branch on the remote.

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')

case "$cmd" in
  *"git push"*) ;;
  *) exit 0 ;;
esac

# Deleting a remote claude/* branch is cleanup — always allow.
if printf '%s' "$cmd" | grep -qE -- '--delete|git push[^|;&]* -d '; then
  exit 0
fi

deny() {
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}' "$1"
  exit 0
}

# Any push mentioning a claude/* ref (as source or destination).
if printf '%s' "$cmd" | grep -q 'claude/'; then
  deny "Blocked: this push would publish a claude/* worktree branch to the remote. Push to the real feature branch instead: git push origin HEAD:<feature-branch>"
fi

# Bare push (no explicit src:dst refspec) while checked out on a claude/* branch.
branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)
if [ "${branch#claude/}" != "$branch" ]; then
  if ! printf '%s' "$cmd" | grep -qE 'git push[^|;&]*[^ ]+:[^ ]+'; then
    deny "Blocked: you are on worktree branch ${branch} and a bare git push would publish it. Use: git push origin HEAD:<feature-branch>"
  fi
fi

exit 0
