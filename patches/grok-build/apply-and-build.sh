#!/usr/bin/env bash
set -euo pipefail

# Physical dir: where this script and the patch file live (follows the
# grok-build/local-patches symlink into grimoire).
SCRIPT_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PATCH="$SCRIPT_DIR/spawn-subagent-reasoning-effort.patch"

# Logical dir: grok-build/local-patches when invoked through the symlink.
# dirname of that string is grok-build. Do not use "$dir/.." — git and
# realpath walk through the symlink into grimoire.
INVOKED_DIR="$(cd -L -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -L)"

resolve_repo_root() {
  local candidate
  if [[ -n "${GROK_BUILD_ROOT:-}" ]]; then
    candidate="$GROK_BUILD_ROOT"
  else
    candidate="$(dirname -- "$INVOKED_DIR")"
  fi
  git -C "$candidate" rev-parse --show-toplevel
}

REPO_ROOT="$(resolve_repo_root)"

if [[ ! -f "$REPO_ROOT/Cargo.toml" || ! -f "$REPO_ROOT/SOURCE_REV" ]]; then
  printf 'Cannot locate grok-build at %s.\n' "$REPO_ROOT" >&2
  printf 'Run this script via grok-build/local-patches, or set GROK_BUILD_ROOT.\n' >&2
  exit 1
fi

TOUCHED_FILES=(
  "crates/common/xai-tool-types/src/lib.rs"
  "crates/common/xai-tool-types/src/task.rs"
  "crates/codegen/xai-grok-tools/src/implementations/grok_build/task/mod.rs"
  "crates/codegen/xai-grok-workspace/src/permission/policy.rs"
  "crates/codegen/xai-grok-workspace/src/permission/types.rs"
  "crates/codegen/xai-grok-shell/src/agent/subagent/handle_request.rs"
  "crates/codegen/xai-grok-shell/src/agent/subagent/spawn.rs"
  "crates/codegen/xai-grok-shell/src/agent/subagent/tests/mod.rs"
  "crates/codegen/xai-grok-shell/src/agent/subagent/tests/rest.rs"
  "crates/codegen/xai-grok-shell/src/extensions/notification.rs"
  "crates/codegen/xai-grok-shell/src/session/acp_session_tests/tool_layer_images_bridge_tests.rs"
  "crates/codegen/xai-grok-shell/src/session/acp_session_impl/tool_calls.rs"
  "crates/codegen/xai-grok-shell/src/session/acp_session_impl/updates_tests.rs"
  "crates/codegen/xai-grok-shell/src/session/acp_session_impl/workflow.rs"
  "crates/codegen/xai-grok-shell/src/session/storage/jsonl/tests.rs"
  "crates/codegen/xai-grok-shell/src/session/workflow/host_service.rs"
  "crates/codegen/xai-grok-shell/src/session/workflow/manager.rs"
  "crates/codegen/xai-grok-shell/src/session/workflow/notify.rs"
  "crates/codegen/xai-grok-shell/src/session/workflow/tracker.rs"
  "crates/codegen/xai-grok-pager/src/app/acp_handler/session_notification.rs"
  "crates/codegen/xai-grok-pager/src/app/acp_handler/tests/mod.rs"
  "crates/codegen/xai-grok-pager/src/app/acp_handler/tests/subagents.rs"
  "crates/codegen/xai-grok-pager/src/app/acp_handler/workflow_ingest.rs"
  "crates/codegen/xai-grok-pager/src/app/agent_view/dock_input_tests.rs"
  "crates/codegen/xai-grok-pager/src/app/agent_view/mod.rs"
  "crates/codegen/xai-grok-pager/src/app/agent_view/session.rs"
  "crates/codegen/xai-grok-pager/src/app/agent_view/subagent_takeover.rs"
  "crates/codegen/xai-grok-pager/src/app/agent_view/subagent_takeover_tests.rs"
  "crates/codegen/xai-grok-pager/src/app/agent_view/workflows_overlay.rs"
  "crates/codegen/xai-grok-pager/src/app/app_view_tests.rs"
  "crates/codegen/xai-grok-pager/src/app/dispatch/tests/mod.rs"
  "crates/codegen/xai-grok-pager/src/app/subagent.rs"
  "crates/codegen/xai-grok-pager/src/app/subagent_format_tests.rs"
  "crates/codegen/xai-grok-pager/src/views/dashboard/row.rs"
  "crates/codegen/xai-grok-pager/src/views/tasks_pane.rs"
  "crates/codegen/xai-grok-pager/src/views/workflows.rs"
  "crates/codegen/xai-grok-pager/docs/user-guide/04-slash-commands.md"
  "crates/codegen/xai-grok-pager/docs/user-guide/16-subagents.md"
)

cd "$REPO_ROOT"

touched_files_are_clean() {
  git diff --quiet -- "${TOUCHED_FILES[@]}" \
    && git diff --cached --quiet -- "${TOUCHED_FILES[@]}"
}

restore_source() {
  git reset --quiet HEAD -- "${TOUCHED_FILES[@]}" || true
  git checkout -- "${TOUCHED_FILES[@]}" || true
  if ! touched_files_are_clean; then
    printf 'Source could not be restored to a clean tree.\n' >&2
    return 1
  fi
  printf 'Source restored to a clean tree.\n'
}

restore_source_on_exit() {
  local status=$?
  trap - EXIT
  if ! restore_source && ((status == 0)); then
    status=1
  fi
  exit "$status"
}

if [[ ! -f "$PATCH" ]]; then
  printf 'Patch file not found: %s\n' "$PATCH" >&2
  exit 1
fi

if git apply --reverse --check "$PATCH" >/dev/null 2>&1; then
  if touched_files_are_clean; then
    printf 'Patch is already applied.\n'
  else
    CURRENT_DIFF="$(mktemp "${TMPDIR:-/tmp}/spawn-subagent-reasoning-effort.XXXXXX")"
    trap 'rm -f "$CURRENT_DIFF"' EXIT
    git -c core.quotepath=false diff --binary HEAD -- "${TOUCHED_FILES[@]}" > "$CURRENT_DIFF"
    if cmp -s "$PATCH" "$CURRENT_DIFF"; then
      printf 'Patch is already applied.\n'
    else
      printf 'Cannot build: files changed by the applied patch have additional modifications.\n' >&2
      printf 'Commit, stash, or revert those changes, then run this script again.\n' >&2
      exit 1
    fi
    rm -f "$CURRENT_DIFF" || true
    trap - EXIT
  fi
elif ! touched_files_are_clean; then
  printf 'Cannot apply patch: files changed by the patch have uncommitted modifications.\n' >&2
  printf 'Commit, stash, or revert those changes, then run this script again.\n' >&2
  exit 1
elif git apply --check "$PATCH"; then
  git apply "$PATCH"
  printf 'Patch applied.\n'
elif git apply --3way --check "$PATCH"; then
  if git apply --3way "$PATCH"; then
    git reset --quiet HEAD -- "${TOUCHED_FILES[@]}"
    printf 'Patch applied with a three-way merge.\n'
  else
    git reset --quiet HEAD -- "${TOUCHED_FILES[@]}"
    git checkout -- "${TOUCHED_FILES[@]}"
    printf 'Cannot apply patch: the three-way merge produced conflicts.\n' >&2
    printf 'The touched files were restored. Refresh the patch against current upstream.\n' >&2
    exit 1
  fi
else
  printf 'Cannot apply patch: upstream changes are incompatible with %s.\n' "$PATCH" >&2
  printf 'Refresh the patch against the current upstream revision before building.\n' >&2
  exit 1
fi

trap restore_source_on_exit EXIT

cargo test -p xai-tool-types task_tool_input_runtime_overrides_parse_explicit
cargo test -p xai-tool-types canonical_reasoning_effort_normalizes_supported_values
cargo test -p xai-grok-tools task_tool_input_schema_includes_runtime_overrides
cargo test -p xai-grok-tools model_and_reasoning_effort_thread_to_runtime_overrides
cargo test -p xai-grok-tools reasoning_effort_none_threads_to_runtime_overrides
cargo test -p xai-grok-tools invalid_reasoning_effort_is_rejected
cargo test -p xai-grok-tools reasoning_effort_placeholders_are_rejected
cargo test -p xai-grok-tools blank_reasoning_effort_is_omitted
cargo test -p xai-grok-shell --lib task_not_gated_in_plan_mode
cargo test -p xai-grok-shell --lib reasoning_effort_override_
cargo test -p xai-grok-shell --lib reasoning_effort_validation_precedes_worktree_lifecycle
cargo test -p xai-grok-shell --lib notification_subagent_spawned_includes_resumed_from
cargo test -p xai-grok-pager subagent_runtime_meta_joins_model_and_effort --lib
cargo test -p xai-grok-pager spawned_subagent_stores_effective_runtime_metadata --lib
cargo test -p xai-grok-pager --lib -- subagent_title_tests
cargo test -p xai-grok-pager --lib -- render_subagent_overlay_shows_model_and_effort
cargo test -p xai-grok-pager --lib -- render_subagent_overlay_keeps_model_when_effort_is_absent
cargo test -p xai-grok-pager --lib -- entry_label_includes_model_and_effort
cargo test -p xai-grok-pager --lib -- workflow_ingest_stores_agent_reasoning_effort
cargo test -p xai-grok-pager --lib -- roster_shows_model_and_effort
cargo test -p xai-grok-pager --lib -- roster_keeps_model_when_effort_is_absent
cargo test -p xai-grok-shell --lib -- agent_info_includes_reasoning_effort
cargo test -p xai-grok-shell --lib -- launch_effort_applies_to_children_and_child_override_wins
cargo test -p xai-grok-workspace permission::types::tests::write_scoped_and_dynamic_inputs_map_to_edit_not_read
cargo test -p xai-grok-workspace permission::policy::tests::write_scoped_access_respects_edit_deny_and_not_read_allow
cargo build -p xai-grok-pager-bin --release

trap - EXIT
restore_source
printf 'Release binary built at %s/target/release/xai-grok-pager\n' "$REPO_ROOT"
