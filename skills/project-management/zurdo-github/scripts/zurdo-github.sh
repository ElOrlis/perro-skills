#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: zurdo-github.sh <mode> [--dry-run] [--repo owner/name] [--slug <zurdo-slug>] [--about "<text>"] [--scope <issue-number>] [--project "<title>"] <path>
Modes: bootstrap | publish | sync-status | board | scope | ticket
Exit codes: 0 ok, 2 usage/parse error, 3 auth or capability error, 1 other.
EOF
}

if [ $# -lt 1 ]; then usage; exit 2; fi

MODE=""
DRY_RUN=false
REPO_ARG=""
SLUG_ARG=""
ABOUT_ARG=""
SCOPE_ARG=""
PROJECT_ARG=""
PRD=""

case "${1:-}" in
  bootstrap|publish|sync-status|board|scope|ticket) MODE="$1"; shift ;;
  -h|--help) usage; exit 0 ;;
  *) usage; exit 2 ;;
esac

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --repo)    REPO_ARG="${2:-}"; shift 2 ;;
    --slug)    SLUG_ARG="${2:-}"; shift 2 ;;
    --about)   ABOUT_ARG="${2:-}"; shift 2 ;;
    --scope)   SCOPE_ARG="${2:-}"; shift 2 ;;
    --project) PROJECT_ARG="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    --) shift; break ;;
    -*) echo "error: unknown flag: $1" >&2; usage; exit 2 ;;
    *)  PRD="$1"; shift ;;
  esac
done

if [ -z "$PRD" ]; then usage; exit 2; fi
if [ ! -f "$PRD" ]; then echo "error: path not found: $PRD" >&2; exit 2; fi

TMPDIR_ROOT=$(mktemp -d)
DRY_LOG="$TMPDIR_ROOT/dry.log"
: > "$DRY_LOG"
cleanup() {
  if $DRY_RUN && [ -s "$DRY_LOG" ]; then
    cat "$DRY_LOG"
  fi
  rm -rf "$TMPDIR_ROOT"
}
trap cleanup EXIT

# ---------- repo resolution ----------
resolve_repo() {
  if [ -n "$REPO_ARG" ]; then printf '%s\n' "$REPO_ARG"; return; fi
  local url
  url=$(git remote get-url origin 2>/dev/null || true)
  if [ -z "$url" ]; then
    echo "error: no origin remote; pass --repo owner/name" >&2
    exit 3
  fi
  local slug
  slug=$(printf '%s' "$url" | sed -E 's#^https?://github\.com/##; s#^git@github\.com:##; s#\.git$##')
  if ! printf '%s' "$slug" | grep -qE '^[^/]+/[^/]+$'; then
    echo "error: could not parse owner/name from remote: $url" >&2
    exit 3
  fi
  printf '%s\n' "$slug"
}

REPO=$(resolve_repo)
OWNER="${REPO%%/*}"
NAME="${REPO#*/}"

# ---------- dry-run mock plumbing ----------
next_dry_num() {
  local f="$TMPDIR_ROOT/counter" n
  n=$(cat "$f" 2>/dev/null || echo 0)
  n=$((n+1))
  echo "$n" > "$f"
  echo "$n"
}

_dry_stub() {
  local all="$*"
  case "$all" in
    label\ list*)                                echo "[]" ;;
    issue\ pin*)                                 echo "" ;;
    api\ repos/*/milestones\?state=all*)         echo "[]" ;;
    api\ repos/*/issues/*/dependencies/blocked_by*)
      case "$all" in
        *--method\ POST*) echo '{}' ;;
        *)                echo "[]" ;;
      esac ;;
    issue\ list*)                                echo "[]" ;;
    repo\ view*)                                 echo '{"description":"","repositoryTopics":[]}' ;;
    project\ list*)                              echo '{"projects":[]}' ;;
    project\ view*)                              echo '{"id":"PVT_dryrun"}' ;;
    project\ field-list*)                        echo '{"fields":[]}' ;;
    project\ item-list*)                         echo '{"items":[]}' ;;
    api\ --method\ POST*/milestones*)
      n=$(next_dry_num); printf '{"number":%d,"id":%d}\n' "$n" "$((1000+n))" ;;
    api\ --method\ POST*/sub_issues*)            echo '{}' ;;
    issue\ create*)
      n=$(next_dry_num); printf 'https://github.com/%s/issues/%d\n' "$REPO" "$n" ;;
    project\ create*)                            echo '{"number":1,"id":"PVT_dryrun"}' ;;
    project\ link*)                              echo '' ;;
    project\ edit*)                              echo '' ;;
    project\ field-create*)                      echo '{"id":"PVTSSF_dryrun"}' ;;
    project\ item-add*)                          echo '{"id":"PVTI_dryrun"}' ;;
    api\ repos/*/issues/*)
      case "$all" in
        *--jq\ .id*) echo $((RANDOM + 5000)) ;;
        *)           echo '{}' ;;
      esac ;;
    *) echo "" ;;
  esac
}

run_gh() {
  if $DRY_RUN; then
    printf 'DRY: gh %s\n' "$*" >> "$DRY_LOG"
    _dry_stub "$@"
    return 0
  fi
  timeout 90 gh "$@"
}

# POST a relationship edge and classify the outcome **by exit status**, never
# by reading the response body. A successful POST echoes the issue JSON back,
# and PRD prose inside it once matched the `*"unavailable"*` / `*"disabled"*`
# body-sniffing this replaces — so every edge was wired natively while the run
# reported `fallback`. Prints `ok`, `already` (HTTP 422: the edge exists, which
# is what an idempotent re-run looks like), or `unavailable`.
post_edge() {
  local resp rc=0
  resp=$(run_gh api --method POST "$@" 2>&1) || rc=$?
  if [ "$rc" -eq 0 ]; then printf 'ok\n'; return 0; fi
  case "$resp" in
    *422*) printf 'already\n' ;;
    *)     printf 'unavailable\n' ;;
  esac
}

# ---------- PRD parser (awk) ----------
PRD_JSON="$TMPDIR_ROOT/prd.json"

if [ "$MODE" = "scope" ] || [ "$MODE" = "ticket" ]; then
  # PRD parser does not run for scope/ticket modes.
  :
else
awk '
function jesc(s) {
  gsub(/\\/, "\\\\", s)
  gsub(/"/, "\\\"", s)
  gsub(/\r/, "", s)
  gsub(/\t/, "\\t", s)
  gsub(/\n/, "\\n", s)
  return "\"" s "\""
}
function append(buf, line) {
  return (buf=="") ? line : buf "\n" line
}
function fail(msg, line) {
  print "PARSE ERROR: " msg ": " line > "/dev/stderr"
  exit 2
}
BEGIN {
  state = "pre"
  ntasks = 0
  intro = ""
  title = ""
}
state == "pre" {
  if (match($0, /^# PRD: /)) {
    title = substr($0, 8)
    state = "intro"
  }
  next
}
/^## Task: / {
  if (state == "intro") { sub(/\n+$/, "", intro) }
  else if (state == "description") { sub(/\n+$/, "", descriptions[ntasks]) }
  line = substr($0, 10)
  sep = " \xe2\x80\x94 "
  n = index(line, sep)
  if (n == 0) { fail("task header missing em-dash separator", $0) }
  ntasks++
  ids[ntasks] = substr(line, 1, n-1)
  # length(sep), never a hard-coded 5: `index` and `substr` count characters
  # under a UTF-8 locale and bytes under a byte-oriented awk, and the em-dash
  # is 1 character but 3 bytes. Hard-coding the byte width ate the first two
  # characters of every title under gawk.
  titles[ntasks] = substr(line, n + length(sep))
  efforts[ntasks] = ""; deps[ntasks] = "[]"; skills[ntasks] = ""
  max_att[ntasks] = ""; agent_to[ntasks] = ""; category[ntasks] = ""
  descriptions[ntasks] = ""; ccount[ntasks] = 0
  if (ids[ntasks] !~ /^task-[a-z0-9-]+$/) {
    fail("invalid task id (must match ^task-[a-z0-9-]+$)", ids[ntasks])
  }
  state = "metadata"
  next
}
state == "intro" {
  intro = append(intro, $0)
  next
}
state == "metadata" {
  if ($0 ~ /^### Description/) { state = "description"; next }
  if ($0 ~ /^\*\*[A-Za-z-]+\*\*: /) {
    p = index($0, "**:")
    key = substr($0, 3, p-3)
    val = substr($0, p+4)
    if      (key == "Effort")        efforts[ntasks] = val
    else if (key == "Depends-on")    deps[ntasks] = val
    else if (key == "Skills")        skills[ntasks] = val
    else if (key == "Max-Attempts")  max_att[ntasks] = val
    else if (key == "Agent-timeout") agent_to[ntasks] = val
    else if (key == "Category")      category[ntasks] = val
    next
  }
  next
}
state == "description" {
  if ($0 ~ /^### Acceptance Criteria/) { state = "criteria"; next }
  descriptions[ntasks] = append(descriptions[ntasks], $0)
  next
}
state == "criteria" {
  if ($0 ~ /^- \[ \] /) {
    line = substr($0, 7)
    hints = ""
    text = line
    while (match(text, / \[[^]]+\]$/)) {
      hint = substr(text, RSTART+2, RLENGTH-3)
      hints = (hints == "" ? jesc(hint) : jesc(hint) "," hints)
      text = substr(text, 1, RSTART-1)
    }
    ccount[ntasks]++
    ctext[ntasks, ccount[ntasks]] = text
    chints[ntasks, ccount[ntasks]] = hints
  }
  next
}
END {
  if (state == "pre") { fail("missing H1 (# PRD: <title>)", "") }
  sub(/\n+$/, "", intro)
  printf "{\"title\":%s,\"intro\":%s,\"tasks\":[", jesc(title), jesc(intro)
  for (i = 1; i <= ntasks; i++) {
    if (i > 1) printf ","
    d = deps[i]
    sub(/^\[/, "", d); sub(/\]$/, "", d); gsub(/[ \t]/, "", d)
    dj = "["
    if (d != "") {
      m = split(d, darr, ",")
      for (k = 1; k <= m; k++) {
        if (k > 1) dj = dj ","
        dj = dj "\"" darr[k] "\""
      }
    }
    dj = dj "]"
    mattr = (max_att[i] == "" ? "null" : max_att[i])
    printf "{\"id\":%s,\"title\":%s,\"effort\":%s,\"depends_on\":%s,\"skills\":%s,\"max_attempts\":%s,\"agent_timeout\":%s,\"category\":%s,\"description\":%s,\"criteria\":[",
      jesc(ids[i]), jesc(titles[i]), jesc(efforts[i]), dj,
      jesc(skills[i]), mattr, jesc(agent_to[i]), jesc(category[i]),
      jesc(descriptions[i])
    for (j = 1; j <= ccount[i]; j++) {
      if (j > 1) printf ","
      printf "{\"text\":%s,\"hints\":[%s]}", jesc(ctext[i, j]), chints[i, j]
    }
    printf "]}"
  }
  printf "]}\n"
}
' "$PRD" > "$PRD_JSON"

# Validate: unique ids + every Depends-on resolves.
if ! jq -e '.' "$PRD_JSON" >/dev/null 2>&1; then
  echo "PARSE ERROR: awk produced invalid JSON" >&2
  exit 2
fi

DUPES=$(jq -r '[.tasks[].id] | (. as $a | $a | unique | . as $u | ($a|length) - ($u|length))' "$PRD_JSON")
if [ "$DUPES" != "0" ]; then
  echo "PARSE ERROR: duplicate task ids in PRD" >&2
  exit 2
fi

BAD_DEP=$(jq -r '
  [.tasks[].id] as $ids
  | .tasks[]
  | . as $t
  | .depends_on[]
  | . as $d
  | select( ($ids | index($d)) == null )
  | "\($t.id) depends on unknown \($d)"
' "$PRD_JSON")
if [ -n "$BAD_DEP" ]; then
  echo "PARSE ERROR: unresolved Depends-on: $BAD_DEP" >&2
  exit 2
fi
fi

# ---------- label vocabulary ----------
COLOR_EPIC="5319E7"
COLOR_TASK="1D76DB"
COLOR_PENDING="FBCA04"
COLOR_FAILED="B60205"
COLOR_EFFORT="BFD4F2"
COLOR_TRIAGE_NEEDS="C5DEF5"
COLOR_TRIAGE_INFO="CCCCCC"
COLOR_READY_AGENT="0E8A16"
COLOR_READY_HUMAN="D4C5F9"
COLOR_WONTFIX="FFFFFF"
COLOR_SCOPE="0052CC"
COLOR_RESEARCH="006B75"
COLOR_GRILLING="EE0701"

LABEL_LIST_JSON=""
load_labels() {
  if [ -z "$LABEL_LIST_JSON" ]; then
    LABEL_LIST_JSON=$(run_gh label list --json name --limit 200 -R "$REPO" 2>/dev/null || echo "[]")
    [ -z "$LABEL_LIST_JSON" ] && LABEL_LIST_JSON="[]"
  fi
}
label_exists() {
  load_labels
  printf '%s' "$LABEL_LIST_JSON" | jq -e --arg n "$1" 'any(.[]?; .name == $n)' >/dev/null 2>&1
}
ensure_label() {
  local name="$1" color="$2" desc="$3"
  if label_exists "$name"; then return 0; fi
  run_gh label create "$name" --color "$color" --description "$desc" -R "$REPO" >/dev/null || true
}

ensure_all_labels() {
  ensure_label "zurdo:epic"           "$COLOR_EPIC"          "Zurdo PRD epic issue"
  ensure_label "zurdo:task"           "$COLOR_TASK"          "Zurdo PRD task issue"
  ensure_label "zurdo:pending-review" "$COLOR_PENDING"       "Awaiting human review"
  ensure_label "zurdo:failed"         "$COLOR_FAILED"        "Zurdo run failed this task"
  ensure_label "zurdo:scope"          "$COLOR_SCOPE"         "Zurdo initiative scope issue"
  ensure_label "zurdo:research"       "$COLOR_RESEARCH"      "Zurdo research ticket"
  ensure_label "zurdo:grilling"       "$COLOR_GRILLING"      "Zurdo grilling ticket"
  if [ -f "$PRD_JSON" ]; then
    local efforts
    efforts=$(jq -r '[.tasks[].effort] | unique | .[]' "$PRD_JSON")
    local e
    for e in $efforts; do
      [ -z "$e" ] && continue
      ensure_label "effort:$e" "$COLOR_EFFORT" "Effort tier: $e"
    done
  fi
  ensure_label "needs-triage"     "$COLOR_TRIAGE_NEEDS" "Needs human triage"
  ensure_label "needs-info"       "$COLOR_TRIAGE_INFO"  "Needs more info to proceed"
  ensure_label "ready-for-agent"  "$COLOR_READY_AGENT"  "Ready for an agent to pick up"
  ensure_label "ready-for-human"  "$COLOR_READY_HUMAN"  "Ready for a human to review"
  ensure_label "wontfix"          "$COLOR_WONTFIX"      "Will not fix"
}

# ---------- helpers ----------
marker_epic() { printf '<!-- zurdo-github prd=%s epic -->' "$PRD"; }
marker_task() { printf '<!-- zurdo-github prd=%s task=%s -->' "$PRD" "$1"; }

url_to_num() { basename "${1%/}"; }

find_issue_by_marker() {
  # echoes issue number if found; empty otherwise
  local marker="$1"
  local json
  json=$(run_gh issue list --state all --search "$marker" --json number,body --limit 50 -R "$REPO" 2>/dev/null || echo "[]")
  [ -z "$json" ] && json="[]"
  printf '%s' "$json" | jq -r --arg m "$marker" 'map(select(.body|contains($m))) | (.[0].number // empty)'
}

find_milestone_number() {
  local title="$1"
  local json
  json=$(run_gh api "repos/$OWNER/$NAME/milestones?state=all" --jq '.' 2>/dev/null || echo "[]")
  [ -z "$json" ] && json="[]"
  printf '%s' "$json" | jq -r --arg t "$title" 'map(select(.title == $t)) | (.[0].number // empty)'
}

issue_db_id() {
  local n="$1"
  run_gh api "repos/$OWNER/$NAME/issues/$n" --jq .id 2>/dev/null || echo ""
}

write_tmp_body() {
  local f
  f=$(mktemp "$TMPDIR_ROOT/body.XXXXXXXX")
  cat > "$f"
  printf '%s\n' "$f"
}

# ---------- bootstrap ----------
do_bootstrap() {
  ensure_all_labels
  if [ -n "$ABOUT_ARG" ]; then
    local rj desc topics
    rj=$(run_gh repo view "$REPO" --json description,repositoryTopics 2>/dev/null || echo '{"description":"","repositoryTopics":[]}')
    desc=$(printf '%s' "$rj" | jq -r '.description // ""')
    topics=$(printf '%s' "$rj" | jq -r '.repositoryTopics | length')
    if [ -z "$desc" ] && [ "$topics" = "0" ]; then
      run_gh repo edit "$REPO" --description "$ABOUT_ARG" >/dev/null || true
    fi
  fi
  local tracker="docs/agents/issue-tracker.md"
  if [ -f "$tracker" ]; then
    if ! grep -q '^## Zurdo operations' "$tracker"; then
      cat >> "$tracker" <<'EOF'

## Zurdo operations

Zurdo turns a PRD into GitHub issues. Label groups: type (`zurdo:epic`, `zurdo:task`), state (`zurdo:pending-review`, `zurdo:failed`), effort (`effort:<value>`), triage (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`).

Marker format: `<!-- zurdo-github prd=<path> task=<id> -->` (and `epic` variant) — an invisible identity that makes re-runs idempotent.

Epic layout: the PRD becomes a milestone plus an epic issue holding the intro, a task table, and (fallback) a task checklist. Task issues are sub-issues of the epic.

Modes: `bootstrap` (labels + docs), `publish` (milestone + epic + tasks + wiring), `sync-status` (label/close from a Zurdo run), `board` (Projects v2 mirror).
EOF
    fi
  else
    echo "skip: docs/agents/issue-tracker.md not present"
  fi
}

# ---------- publish ----------
do_publish() {
  ensure_all_labels

  local prd_title prd_intro milestone_title
  prd_title=$(jq -r '.title' "$PRD_JSON")
  prd_intro=$(jq -r '.intro' "$PRD_JSON")
  milestone_title="$prd_title"

  # (1) milestone
  local mnum
  mnum=$(find_milestone_number "$milestone_title")
  if [ -z "$mnum" ]; then
    local out
    out=$(run_gh api --method POST "repos/$OWNER/$NAME/milestones" \
      -f title="$milestone_title" \
      -f description="$prd_intro" 2>/dev/null || echo '{}')
    mnum=$(printf '%s' "$out" | jq -r '.number // empty')
    [ -z "$mnum" ] && mnum="1"
  else
    run_gh api --method PATCH "repos/$OWNER/$NAME/milestones/$mnum" \
      -f description="$prd_intro" >/dev/null || true
  fi

  # (2) epic issue
  local emarker enum
  emarker=$(marker_epic)
  enum=$(find_issue_by_marker "$emarker")
  local epic_body_file
  epic_body_file=$(printf '%s\n\n%s\n\n%s\n' "$emarker" "$prd_intro" "_epic body will be finalized after task numbers are known._" | write_tmp_body)
  if [ -z "$enum" ]; then
    local eurl
    eurl=$(run_gh issue create \
      --title "$prd_title" \
      --label zurdo:epic \
      --milestone "$milestone_title" \
      --assignee @me \
      --body-file "$epic_body_file" \
      -R "$REPO" 2>/dev/null || echo "")
    enum=$(url_to_num "$eurl")
    [ -z "$enum" ] && enum="1"
  fi

  # (3) task issues — first pass (no Blocked-by line, since blocker numbers unknown)
  local task_count
  task_count=$(jq -r '.tasks | length' "$PRD_JSON")

  declare -a T_ID T_TITLE T_EFFORT T_NUM T_DBID
  declare -A ID2IDX
  local i tid ttitle teffort tskills tmaxatt tagentto tdesc tmarker deps_len body_file existing url num crit_lines
  for i in $(seq 0 $((task_count-1))); do
    tid=$(jq -r ".tasks[$i].id" "$PRD_JSON")
    ttitle=$(jq -r ".tasks[$i].title" "$PRD_JSON")
    teffort=$(jq -r ".tasks[$i].effort" "$PRD_JSON")
    tskills=$(jq -r ".tasks[$i].skills // \"\"" "$PRD_JSON")
    tmaxatt=$(jq -r ".tasks[$i].max_attempts | if . == null then \"\" else tostring end" "$PRD_JSON")
    tagentto=$(jq -r ".tasks[$i].agent_timeout // \"\"" "$PRD_JSON")
    tdesc=$(jq -r ".tasks[$i].description" "$PRD_JSON")
    deps_len=$(jq -r ".tasks[$i].depends_on | length" "$PRD_JSON")
    tmarker=$(marker_task "$tid")

    T_ID[$i]="$tid"; T_TITLE[$i]="$ttitle"; T_EFFORT[$i]="$teffort"
    ID2IDX[$tid]=$i

    # metadata table row
    local meta_cols meta_vals
    meta_cols="| Effort |"; meta_vals="| $teffort |"
    if [ -n "$tskills" ]; then meta_cols="$meta_cols Skills |"; meta_vals="$meta_vals $tskills |"; fi
    if [ -n "$tmaxatt" ]; then meta_cols="$meta_cols Max-Attempts |"; meta_vals="$meta_vals $tmaxatt |"; fi
    if [ -n "$tagentto" ]; then meta_cols="$meta_cols Agent-timeout |"; meta_vals="$meta_vals $tagentto |"; fi
    local sep
    sep=$(printf '%s' "$meta_cols" | sed 's/[^|]/-/g; s/-|/---|/g')

    crit_lines=$(jq -r ".tasks[$i].criteria[] | \"- [ ] \" + .text + (if (.hints|length)>0 then \" \" + ((.hints|map(\"\`\" + . + \"\`\"))|join(\" \")) else \"\" end)" "$PRD_JSON")

    body_file=$(cat <<EOF | write_tmp_body
Part of #${enum}

${tmarker}

${meta_cols}
${sep}
${meta_vals}

## Description

${tdesc}

## Acceptance Criteria

${crit_lines}
EOF
)

    local -a labels_args=(--label zurdo:task --label "effort:$teffort")
    if [ "$deps_len" = "0" ]; then
      labels_args+=(--label ready-for-agent)
    fi

    existing=$(find_issue_by_marker "$tmarker")
    if [ -z "$existing" ]; then
      url=$(run_gh issue create \
        --title "$ttitle" \
        "${labels_args[@]}" \
        --milestone "$milestone_title" \
        --body-file "$body_file" \
        -R "$REPO" 2>/dev/null || echo "")
      num=$(url_to_num "$url")
      [ -z "$num" ] && num=$((100 + i))
    else
      num="$existing"
      run_gh issue edit "$num" \
        --title "$ttitle" \
        --body-file "$body_file" \
        --milestone "$milestone_title" \
        -R "$REPO" >/dev/null || true
      run_gh issue edit "$num" --add-label "zurdo:task" --add-label "effort:$teffort" -R "$REPO" >/dev/null || true
      if [ "$deps_len" = "0" ]; then
        run_gh issue edit "$num" --add-label "ready-for-agent" -R "$REPO" >/dev/null || true
      fi
    fi
    T_NUM[$i]="$num"
    T_DBID[$i]=$(issue_db_id "$num")
    [ -z "${T_DBID[$i]}" ] && T_DBID[$i]="$((5000 + i))"
  done

  # (4) wiring pass
  local subissue_mode="native"
  local dep_mode="native"
  local epic_dbid
  epic_dbid=$(issue_db_id "$enum")
  [ -z "$epic_dbid" ] && epic_dbid="4999"

  local fallback_checklist=""
  for i in $(seq 0 $((task_count-1))); do
    case "$(post_edge "repos/$OWNER/$NAME/issues/$enum/sub_issues" \
      -F "sub_issue_id=${T_DBID[$i]}")" in
      unavailable) subissue_mode="fallback" ;;
    esac
  done
  if [ "$subissue_mode" = "fallback" ]; then
    for i in $(seq 0 $((task_count-1))); do
      fallback_checklist="${fallback_checklist}- [ ] #${T_NUM[$i]}"$'\n'
    done
  fi

  for i in $(seq 0 $((task_count-1))); do
    local dcount
    dcount=$(jq -r ".tasks[$i].depends_on | length" "$PRD_JSON")
    if [ "$dcount" = "0" ]; then continue; fi
    local j dep_id dep_idx dep_dbid resp
    for j in $(seq 0 $((dcount-1))); do
      dep_id=$(jq -r ".tasks[$i].depends_on[$j]" "$PRD_JSON")
      dep_idx="${ID2IDX[$dep_id]:-}"
      [ -z "$dep_idx" ] && continue
      dep_dbid="${T_DBID[$dep_idx]}"
      case "$(post_edge "repos/$OWNER/$NAME/issues/${T_NUM[$i]}/dependencies/blocked_by" \
        -F "issue_id=$dep_dbid")" in
        unavailable) dep_mode="fallback" ;;
      esac
    done
  done

  # Second-pass task body edits: add Blocked by: line where applicable
  for i in $(seq 0 $((task_count-1))); do
    local dcount
    dcount=$(jq -r ".tasks[$i].depends_on | length" "$PRD_JSON")
    if [ "$dcount" = "0" ]; then continue; fi
    local blocked_line="Blocked by:" j dep_id dep_idx
    for j in $(seq 0 $((dcount-1))); do
      dep_id=$(jq -r ".tasks[$i].depends_on[$j]" "$PRD_JSON")
      dep_idx="${ID2IDX[$dep_id]:-}"
      [ -z "$dep_idx" ] && continue
      blocked_line="$blocked_line [${T_TITLE[$dep_idx]}](#${T_NUM[$dep_idx]})"
    done

    local tid ttitle teffort tskills tmaxatt tagentto tdesc tmarker crit_lines body_file
    tid="${T_ID[$i]}"; ttitle="${T_TITLE[$i]}"; teffort="${T_EFFORT[$i]}"
    tskills=$(jq -r ".tasks[$i].skills // \"\"" "$PRD_JSON")
    tmaxatt=$(jq -r ".tasks[$i].max_attempts | if . == null then \"\" else tostring end" "$PRD_JSON")
    tagentto=$(jq -r ".tasks[$i].agent_timeout // \"\"" "$PRD_JSON")
    tdesc=$(jq -r ".tasks[$i].description" "$PRD_JSON")
    tmarker=$(marker_task "$tid")

    local meta_cols meta_vals sep
    meta_cols="| Effort |"; meta_vals="| $teffort |"
    if [ -n "$tskills" ]; then meta_cols="$meta_cols Skills |"; meta_vals="$meta_vals $tskills |"; fi
    if [ -n "$tmaxatt" ]; then meta_cols="$meta_cols Max-Attempts |"; meta_vals="$meta_vals $tmaxatt |"; fi
    if [ -n "$tagentto" ]; then meta_cols="$meta_cols Agent-timeout |"; meta_vals="$meta_vals $tagentto |"; fi
    sep=$(printf '%s' "$meta_cols" | sed 's/[^|]/-/g; s/-|/---|/g')

    crit_lines=$(jq -r ".tasks[$i].criteria[] | \"- [ ] \" + .text + (if (.hints|length)>0 then \" \" + ((.hints|map(\"\`\" + . + \"\`\"))|join(\" \")) else \"\" end)" "$PRD_JSON")

    body_file=$(cat <<EOF | write_tmp_body
Part of #${enum}

${tmarker}

${meta_cols}
${sep}
${meta_vals}

${blocked_line}

## Description

${tdesc}

## Acceptance Criteria

${crit_lines}
EOF
)
    run_gh issue edit "${T_NUM[$i]}" --body-file "$body_file" -R "$REPO" >/dev/null || true
  done

  # (5) epic body
  local table
  # Not `$(printf ...)`: command substitution strips the trailing newline,
  # which glued the separator row to the first task row.
  table='| Task | Effort | Status |'$'\n''|---|---|---|'$'\n'
  for i in $(seq 0 $((task_count-1))); do
    table="${table}| [${T_TITLE[$i]}](https://github.com/${REPO}/issues/${T_NUM[$i]}) | ${T_EFFORT[$i]} | Todo |"$'\n'
  done
  local epic_body scope_line=""
  if [ -n "$SCOPE_ARG" ]; then
    scope_line="Part of #${SCOPE_ARG}"$'\n\n'
  fi
  epic_body="${scope_line}${emarker}"$'\n\n'"${prd_intro}"$'\n\n'"## Tasks"$'\n\n'"${table}"
  if [ "$subissue_mode" = "fallback" ]; then
    epic_body="${epic_body}"$'\n'"### Checklist (sub-issues unavailable)"$'\n\n'"${fallback_checklist}"
  fi
  local final_epic_body_file
  final_epic_body_file=$(printf '%s' "$epic_body" | write_tmp_body)
  run_gh issue edit "$enum" --body-file "$final_epic_body_file" -R "$REPO" >/dev/null || true

  # (5b) --scope: wire epic under the given scope issue
  local scope_mode=""
  if [ -n "$SCOPE_ARG" ]; then
    scope_mode="native"
    case "$(post_edge "repos/$OWNER/$NAME/issues/$SCOPE_ARG/sub_issues" \
      -F "sub_issue_id=$epic_dbid")" in
      unavailable)
        scope_mode="fallback"
        # Append `- [ ] #<epic>` to a ## Phases checklist on the scope issue.
        local sf
        sf=$(printf '## Phases\n\n- [ ] #%s\n' "$enum" | write_tmp_body)
        run_gh issue comment "$SCOPE_ARG" --body-file "$sf" -R "$REPO" >/dev/null || true
        ;;
    esac
  fi

  # (6) summary
  echo
  echo "Summary:"
  echo "  milestone: $milestone_title (#$mnum)"
  echo "  epic: $prd_title (#$enum)"
  for i in $(seq 0 $((task_count-1))); do
    echo "  task: ${T_TITLE[$i]} (#${T_NUM[$i]}) [effort:${T_EFFORT[$i]}]"
  done
  echo "  wiring: sub-issues=$subissue_mode dependencies=$dep_mode"
  if [ -n "$scope_mode" ]; then
    echo "  scope-link: #$SCOPE_ARG mode=$scope_mode"
  fi
}

# ---------- sync-status ----------
resolve_run_dir() {
  if [ -n "$SLUG_ARG" ]; then
    printf '%s\n' ".zurdo/$SLUG_ARG"
    return
  fi
  local base
  base=$(basename "$PRD" .md)
  local match
  match=$(ls -1dt .zurdo/${base}-*/ 2>/dev/null | head -1 || true)
  if [ -z "$match" ]; then
    echo "error: no run directory found for $base" >&2
    exit 1
  fi
  printf '%s\n' "${match%/}"
}

do_sync_status() {
  local run_dir prd_run
  run_dir=$(resolve_run_dir)
  prd_run="$run_dir/prd.json"
  if [ ! -f "$prd_run" ] && ! $DRY_RUN; then
    echo "error: $prd_run not found" >&2
    exit 1
  fi

  local task_count
  task_count=$(jq -r '.tasks | length' "$PRD_JSON")

  # Rows the epic table refresh will rewrite: issue number -> display status.
  local -a EPIC_ROW_NUM=() EPIC_ROW_STATUS=()
  local i tid tmarker num status run_task
  for i in $(seq 0 $((task_count-1))); do
    tid=$(jq -r ".tasks[$i].id" "$PRD_JSON")
    tmarker=$(marker_task "$tid")
    num=$(find_issue_by_marker "$tmarker")
    if [ -z "$num" ]; then
      if $DRY_RUN; then
        num=$((200 + i))
      else
        echo "warn: no issue for $tid (marker not found)"
        continue
      fi
    fi

    if [ -f "$prd_run" ]; then
      status=$(jq -r --arg id "$tid" '.tasks[$id].status // "unknown"' "$prd_run")
      run_task=$(jq --arg id "$tid" '.tasks[$id]' "$prd_run")
    else
      status="passed-pending-review"
      run_task='{}'
    fi

    local row_status
    case "$status" in
      passed)                row_status="Done" ;;
      passed-pending-review) row_status="Pending Review" ;;
      failed)                row_status="Failed" ;;
      in_progress|running)   row_status="In Progress" ;;
      blocked-by-dependency) row_status="Todo" ;;
      *)                     row_status="Todo" ;;
    esac
    EPIC_ROW_NUM+=("$num")
    EPIC_ROW_STATUS+=("$row_status")

    case "$status" in
      passed)
        local last attempts model tin tout cost
        last=$(printf '%s' "$run_task" | jq -r '.iterations[-1] // {}')
        attempts=$(printf '%s' "$run_task" | jq -r '.attempts // 0')
        model=$(printf '%s' "$last" | jq -r '.model // "unknown"')
        tin=$(printf '%s' "$last" | jq -r '.tokens_in // 0')
        tout=$(printf '%s' "$last" | jq -r '.tokens_out // 0')
        cost=$(printf '%s' "$last" | jq -r '.cost_usd_est // 0')
        run_gh issue edit "$num" --remove-label "zurdo:pending-review" --remove-label "zurdo:failed" -R "$REPO" >/dev/null || true
        local cf
        cf=$(printf 'Zurdo run: passed\nattempts: %s\nlast model: %s\ntokens_in: %s\ntokens_out: %s\ncost_usd_est: %s\n' \
          "$attempts" "$model" "$tin" "$tout" "$cost" | write_tmp_body)
        run_gh issue comment "$num" --body-file "$cf" -R "$REPO" >/dev/null || true
        run_gh issue close "$num" -R "$REPO" >/dev/null || true
        ;;
      passed-pending-review)
        local last attempts model tin tout cost
        last=$(printf '%s' "$run_task" | jq -r '.iterations[-1] // {}')
        attempts=$(printf '%s' "$run_task" | jq -r '.attempts // 0')
        model=$(printf '%s' "$last" | jq -r '.model // "unknown"')
        tin=$(printf '%s' "$last" | jq -r '.tokens_in // 0')
        tout=$(printf '%s' "$last" | jq -r '.tokens_out // 0')
        cost=$(printf '%s' "$last" | jq -r '.cost_usd_est // 0')
        run_gh issue edit "$num" --remove-label "zurdo:failed" --add-label "zurdo:pending-review" -R "$REPO" >/dev/null || true
        local cf
        cf=$(printf 'Zurdo run: passed pending review\nattempts: %s\nlast model: %s\ntokens_in: %s\ntokens_out: %s\ncost_usd_est: %s\n' \
          "$attempts" "$model" "$tin" "$tout" "$cost" | write_tmp_body)
        run_gh issue comment "$num" --body-file "$cf" -R "$REPO" >/dev/null || true
        ;;
      failed)
        local failed_hints
        failed_hints=$(printf '%s' "$run_task" | jq -r '(.iterations[-1].criteria_results // []) | map(select(.passed == false)) | map("- " + (.hint // "?")) | join("\n")')
        run_gh issue edit "$num" --remove-label "zurdo:pending-review" --add-label "zurdo:failed" -R "$REPO" >/dev/null || true
        local cf
        cf=$(printf 'Zurdo run: failed\nFailing criteria:\n%s\n' "$failed_hints" | write_tmp_body)
        run_gh issue comment "$num" --body-file "$cf" -R "$REPO" >/dev/null || true
        ;;
      blocked-by-dependency)
        : ;;
      *) : ;;
    esac
  done

  # Refresh the epic's task table. Rewrites only the Status cell of each row it
  # can resolve to a task issue number, so a hand-edited epic body survives;
  # same-page `(#N)` anchors left by older runs are normalized to issue URLs.
  local emarker enum
  emarker=$(marker_epic)
  enum=$(find_issue_by_marker "$emarker")
  if [ -z "$enum" ] && ! $DRY_RUN; then
    echo "warn: epic issue not found (marker missing); task table not refreshed" >&2
    return 0
  fi
  [ -z "$enum" ] && enum=1

  if [ ${#EPIC_ROW_NUM[@]} -eq 0 ]; then
    echo "warn: no task rows resolved; epic #$enum task table not refreshed" >&2
    return 0
  fi

  local map="" k
  for k in $(seq 0 $((${#EPIC_ROW_NUM[@]}-1))); do
    map="${map}${EPIC_ROW_NUM[$k]}=${EPIC_ROW_STATUS[$k]};"
  done

  if $DRY_RUN; then
    echo "DRY: gh issue edit $enum --body-file <epic body, Status column set to: ${map%;}> -R $REPO"
    return 0
  fi

  local epic_body
  epic_body=$(gh issue view "$enum" --json body --jq .body -R "$REPO" 2>/dev/null || true)
  if [ -z "$epic_body" ]; then
    echo "warn: could not read epic #$enum body; task table not refreshed" >&2
    return 0
  fi

  # awk writes the rewritten body and the row count to separate files, so the
  # count never has to be fished back out of an interleaved stream.
  local body_out count_out rewritten
  body_out="$TMPDIR_ROOT/epic-body.refreshed"
  count_out="$TMPDIR_ROOT/epic-rows.count"
  printf '%s\n' "$epic_body" | awk -v map="$map" -v repo="$REPO" \
      -v out="$body_out" -v cnt="$count_out" '
    BEGIN {
      n = split(map, kv, ";")
      for (i = 1; i <= n; i++) {
        if (kv[i] == "") continue
        split(kv[i], pair, "=")
        S[pair[1]] = pair[2]
      }
      changed = 0
    }
    /^\| \[/ {
      num = ""
      if (match($0, /\/issues\/[0-9]+\)/)) {
        num = substr($0, RSTART + 8, RLENGTH - 9)
      } else if (match($0, /\(#[0-9]+\)/)) {
        num = substr($0, RSTART + 2, RLENGTH - 3)
      }
      if (num != "" && (num in S)) {
        sub(/\(#[0-9]+\)/, "(https://github.com/" repo "/issues/" num ")")
        sub(/\|[^|]*\|[ \t]*$/, "| " S[num] " |")
        changed++
        print > out
        next
      }
    }
    { print > out }
    END { printf "%d\n", changed > cnt }
  '
  rewritten=$(cat "$count_out" 2>/dev/null || echo 0)

  if [ "$rewritten" = "0" ] || [ -z "$rewritten" ]; then
    echo "warn: epic #$enum has no task table rows matching this PRD's issues; not refreshed" >&2
    return 0
  fi

  local ebf
  ebf=$(write_tmp_body < "$body_out")
  if run_gh issue edit "$enum" --body-file "$ebf" -R "$REPO" >/dev/null; then
    echo "epic #$enum task table refreshed ($rewritten rows)"
  else
    echo "warn: epic #$enum task table edit failed" >&2
  fi
}

# ---------- board (Projects v2) ----------
do_board() {
  # Check project scope
  if ! $DRY_RUN; then
    if ! gh auth status 2>&1 | grep -q "project"; then
      echo "error: missing 'project' scope. Run: gh auth refresh -s project" >&2
      exit 3
    fi
  fi

  local plist project_id project_number title
  if [ -n "$PROJECT_ARG" ]; then
    title="$PROJECT_ARG"
  else
    title="$NAME"
  fi
  plist=$(run_gh project list --owner "$OWNER" --format json 2>/dev/null || echo '{"projects":[]}')
  [ -z "$plist" ] && plist='{"projects":[]}'
  project_number=$(printf '%s' "$plist" | jq -r --arg t "$title" '.projects[]? | select(.title == $t) | .number' | head -1)
  if [ -z "$project_number" ]; then
    local created
    created=$(run_gh project create --owner "$OWNER" --title "$title" --format json 2>/dev/null || echo '{"number":1}')
    project_number=$(printf '%s' "$created" | jq -r '.number // 1')
  fi
  project_link_repo "$project_number"

  local fields
  fields=$(run_gh project field-list "$project_number" --owner "$OWNER" --format json 2>/dev/null || echo '{"fields":[]}')
  [ -z "$fields" ] && fields='{"fields":[]}'
  local status_field
  status_field=$(printf '%s' "$fields" | jq -r '.fields[]? | select(.name == "Status") | .id' | head -1)
  if [ -z "$status_field" ]; then
    run_gh project field-create "$project_number" --owner "$OWNER" \
      --name Status --data-type SINGLE_SELECT \
      --single-select-options "Todo,In Progress,Pending Review,Done,Failed" >/dev/null || true
    # Re-read: the create returns the field id but not its option ids, and the
    # option id is what `item-edit` actually needs.
    fields=$(run_gh project field-list "$project_number" --owner "$OWNER" --format json 2>/dev/null || echo '{"fields":[]}')
    [ -z "$fields" ] && fields='{"fields":[]}'
    status_field=$(printf '%s' "$fields" | jq -r '.fields[]? | select(.name == "Status") | .id' | head -1)
  fi

  # `project item-edit` takes **node ids**, not the project number, not a
  # synthesized item id, and not the literal field and option names. All three
  # are resolved here, once, and a missing one downgrades to a warning rather
  # than a silent no-op.
  local project_node_id
  project_node_id=$(run_gh project view "$project_number" --owner "$OWNER" --format json 2>/dev/null | jq -r '.id // empty' || true)
  if [ -z "$project_node_id" ] || [ -z "$status_field" ]; then
    echo "warn: board Status not settable (project node id or Status field unresolved); items will be added without a status" >&2
  fi

  local task_count run_dir prd_run
  task_count=$(jq -r '.tasks | length' "$PRD_JSON")

  run_dir=""
  if [ -n "$SLUG_ARG" ]; then
    run_dir=".zurdo/$SLUG_ARG"
  else
    run_dir=$(ls -1dt .zurdo/$(basename "$PRD" .md)-*/ 2>/dev/null | head -1 || true)
    run_dir="${run_dir%/}"
  fi
  prd_run=""
  [ -n "$run_dir" ] && [ -f "$run_dir/prd.json" ] && prd_run="$run_dir/prd.json"

  local i tid tmarker num status board_status
  for i in $(seq 0 $((task_count-1))); do
    tid=$(jq -r ".tasks[$i].id" "$PRD_JSON")
    tmarker=$(marker_task "$tid")
    num=$(find_issue_by_marker "$tmarker")
    [ -z "$num" ] && num=$((300 + i))

    if [ -n "$prd_run" ]; then
      status=$(jq -r --arg id "$tid" '.tasks[$id].status // "unknown"' "$prd_run")
    else
      status="unknown"
    fi
    case "$status" in
      passed)                board_status="Done" ;;
      passed-pending-review) board_status="Pending Review" ;;
      failed)                board_status="Failed" ;;
      in_progress|running)   board_status="In Progress" ;;
      *)                     board_status="Todo" ;;
    esac
    local item_id option_id
    item_id=$(run_gh project item-add "$project_number" --owner "$OWNER" \
      --url "https://github.com/$REPO/issues/$num" --format json 2>/dev/null | jq -r '.id // empty' || true)
    option_id=$(printf '%s' "$fields" | jq -r --arg n "$board_status" \
      '.fields[]? | select(.name == "Status") | .options[]? | select(.name == $n) | .id' | head -1)
    if [ -z "$option_id" ]; then
      # A project created by `gh project create` carries only Todo / In Progress
      # / Done, so `Pending Review` and `Failed` have no option until the field
      # is extended. Say so instead of writing nothing.
      echo "warn: Status option \"$board_status\" does not exist on this project; issue #$num left unset" >&2
    elif [ -n "$project_node_id" ] && [ -n "$status_field" ] && [ -n "$item_id" ]; then
      run_gh project item-edit --project-id "$project_node_id" \
        --id "$item_id" --field-id "$status_field" \
        --single-select-option-id "$option_id" >/dev/null || true
    fi
  done
}

# ---------- scope parser (awk) ----------
parse_scope_file() {
  local file="$1" out="$2"
  awk '
  function jesc(s) {
    gsub(/\\/, "\\\\", s); gsub(/"/, "\\\"", s)
    gsub(/\r/, "", s); gsub(/\t/, "\\t", s); gsub(/\n/, "\\n", s)
    return "\"" s "\""
  }
  function append(buf, line) { return (buf=="") ? line : buf "\n" line }
  function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
  function fail(msg, line) { print "PARSE ERROR: " msg ": " line > "/dev/stderr"; exit 2 }
  BEGIN { state = "pre"; title = ""; nphases = 0 }
  state == "pre" {
    if (match($0, /^# Scope: /)) { title = substr($0, 10); state = "body"; sec = "" }
    next
  }
  {
    if (match($0, /^## /)) {
      name = substr($0, 4)
      if      (name == "Destination")        sec = "destination"
      else if (name == "Notes")              sec = "notes"
      else if (name == "Decisions so far")   sec = "decisions"
      else if (name == "Phases")             sec = "phases"
      else if (name == "Not yet specified")  sec = "not_yet"
      else if (name == "Out of scope")       sec = "out_of_scope"
      else                                   sec = "other_" name
      next
    }
    if (sec == "phases" && match($0, /^\|[ \t]*phase-/)) {
      # parse the row
      row = $0
      # split on | ; awk split treats empty fields
      n = split(row, cells, /\|/)
      # cells[1] = "" (before first |), cells[2]=phase, cells[3]=title, cells[4]=prd, cells[5]=status
      p = trim(cells[2]); t = trim(cells[3]); pr = trim(cells[4]); st = trim(cells[5])
      if (st != "planned" && st != "researching" && st != "ready" && st != "running" && st != "done") {
        fail("phase Status outside enum", $0)
      }
      nphases++
      ph_phase[nphases] = p
      ph_title[nphases] = t
      ph_prd[nphases]   = pr
      ph_status[nphases] = st
    }
    if (sec != "") sections[sec] = append(sections[sec], $0)
  }
  END {
    if (state == "pre") { fail("missing H1 (# Scope: <title>)", "") }
    for (k in sections) { sub(/\n+$/, "", sections[k]); sub(/^\n+/, "", sections[k]) }
    printf "{"
    printf "\"title\":%s", jesc(title)
    printf ",\"sections\":{"
    printf "\"destination\":%s",   jesc(sections["destination"])
    printf ",\"notes\":%s",         jesc(sections["notes"])
    printf ",\"decisions\":%s",     jesc(sections["decisions"])
    printf ",\"phases\":%s",        jesc(sections["phases"])
    printf ",\"not_yet\":%s",       jesc(sections["not_yet"])
    printf ",\"out_of_scope\":%s",  jesc(sections["out_of_scope"])
    printf "}"
    printf ",\"phases\":["
    for (i = 1; i <= nphases; i++) {
      if (i > 1) printf ","
      printf "{\"phase\":%s,\"title\":%s,\"prd\":%s,\"status\":%s}", \
        jesc(ph_phase[i]), jesc(ph_title[i]), jesc(ph_prd[i]), jesc(ph_status[i])
    }
    printf "]}\n"
  }
  ' "$file" > "$out"
  if ! jq -e '.' "$out" >/dev/null 2>&1; then
    echo "PARSE ERROR: scope awk produced invalid JSON" >&2; exit 2
  fi
}

# ---------- ticket parser (awk) ----------
parse_ticket_file() {
  local file="$1" out="$2"
  awk '
  function jesc(s) {
    gsub(/\\/, "\\\\", s); gsub(/"/, "\\\"", s)
    gsub(/\r/, "", s); gsub(/\t/, "\\t", s); gsub(/\n/, "\\n", s)
    return "\"" s "\""
  }
  function append(buf, line) { return (buf=="") ? line : buf "\n" line }
  function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
  function fail(msg, line) { print "PARSE ERROR: " msg ": " line > "/dev/stderr"; exit 2 }
  function parse_list(v,   arr, n, i, x, out) {
    v = trim(v)
    sub(/^\[/, "", v); sub(/\]$/, "", v)
    if (v == "") return "[]"
    n = split(v, arr, ",")
    out = "["
    for (i = 1; i <= n; i++) {
      x = trim(arr[i])
      if (i > 1) out = out ","
      out = out jesc(x)
    }
    return out "]"
  }
  BEGIN { state = "pre"; body = ""; findings = ""; in_findings = 0
          ttype = ""; tquestion = ""; tstatus = ""; tblocks = "[]"; tblocked = "[]" }
  state == "pre" {
    if ($0 == "---") { state = "fm" }
    next
  }
  state == "fm" {
    if ($0 == "---") { state = "body"; next }
    line = $0
    p = index(line, ":")
    if (p == 0) next
    key = trim(substr(line, 1, p-1))
    val = substr(line, p+1)
    if      (key == "type")       ttype = trim(val)
    else if (key == "question")   tquestion = trim(val)
    else if (key == "status")     tstatus = trim(val)
    else if (key == "blocks")     tblocks = parse_list(val)
    else if (key == "blocked-by") tblocked = parse_list(val)
    next
  }
  state == "body" {
    if (match($0, /^## Findings/)) { in_findings = 1; next }
    if (in_findings) {
      if (match($0, /^## /)) { in_findings = 0; body = append(body, $0); next }
      findings = append(findings, $0)
    } else {
      body = append(body, $0)
    }
  }
  END {
    if (state == "pre" || state == "fm") { fail("missing frontmatter fences", "") }
    if (ttype != "research" && ttype != "grilling") { fail("type outside enum research|grilling", ttype) }
    if (tstatus != "open" && tstatus != "resolved")  { fail("status outside enum open|resolved", tstatus) }
    sub(/^\n+/, "", body); sub(/\n+$/, "", body)
    sub(/^\n+/, "", findings); sub(/\n+$/, "", findings)
    printf "{\"type\":%s,\"question\":%s,\"status\":%s,\"blocks\":%s,\"blocked_by\":%s,\"body\":%s,\"findings\":%s}\n", \
      jesc(ttype), jesc(tquestion), jesc(tstatus), tblocks, tblocked, jesc(body), jesc(findings)
  }
  ' "$file" > "$out"
  if ! jq -e '.' "$out" >/dev/null 2>&1; then
    echo "PARSE ERROR: ticket awk produced invalid JSON" >&2; exit 2
  fi
}

marker_scope()  { printf '<!-- zurdo-github scope=%s -->' "$1"; }
marker_ticket() { printf '<!-- zurdo-github scope=%s ticket=%s -->' "$1" "$2"; }

# Render the phases table with Epic + Milestone columns.
render_phases_table() {
  local scope_json="$1"
  local nph i phase title prd status epic mile emarker enum mile_title
  nph=$(jq -r '.phases | length' "$scope_json")
  printf '| Phase | Title | PRD | Epic | Milestone | Status |\n'
  printf '|---|---|---|---|---|---|\n'
  for i in $(seq 0 $((nph-1))); do
    phase=$(jq -r ".phases[$i].phase" "$scope_json")
    title=$(jq -r ".phases[$i].title" "$scope_json")
    prd=$(jq -r ".phases[$i].prd" "$scope_json")
    status=$(jq -r ".phases[$i].status" "$scope_json")
    epic=""; mile_title=""
    if [ -n "$prd" ]; then
      emarker="<!-- zurdo-github prd=$prd epic -->"
      enum=$(find_issue_by_marker "$emarker")
      if [ -n "$enum" ]; then
        epic="#$enum"
        mile_title=$(run_gh api "repos/$OWNER/$NAME/issues/$enum" --jq '.milestone.title // ""' 2>/dev/null || echo "")
      fi
    fi
    printf '| %s | %s | %s | %s | %s | %s |\n' "$phase" "$title" "$prd" "$epic" "$mile_title" "$status"
  done
}

# Ensure project scope; print skip message and return 1 if missing.
ensure_project_scope() {
  if $DRY_RUN; then return 0; fi
  if gh auth status 2>&1 | grep -q "project"; then return 0; fi
  echo "skip: project scope missing, run gh auth refresh -s project"
  return 1
}

# Link a Projects v2 project to the target repository so it appears under the
# repo's Projects tab. Idempotent: gh errors when already linked; that is swallowed.
project_link_repo() {
  local project_number="$1"
  run_gh project link "$project_number" --owner "$OWNER" --repo "$REPO" >/dev/null 2>&1 || true
}

# Project description and README are projections of scope.md: the description
# is the first Destination paragraph (GitHub caps it at 256 chars), the README
# is the scope body without the marker. Overwritten on every scope run; never
# written by board, which has no scope.md in hand.
project_set_metadata() {
  local project_number="$1" description="$2" readme_file="$3"
  description=$(printf '%s' "$description" | awk 'BEGIN{RS=""} NR==1{gsub(/\n/," "); print; exit}')
  description=$(printf '%s' "$description" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')
  if [ "${#description}" -gt 256 ]; then
    description="${description:0:253}..."
  fi
  run_gh project edit "$project_number" --owner "$OWNER" \
    --description "$description" \
    --readme "$(cat "$readme_file")" >/dev/null 2>&1 || true
}

# Add issue to project, creating project + Status field if needed.
project_ensure_and_add() {
  local title="$1" issue_num
  shift
  local plist project_number fields status_field
  plist=$(run_gh project list --owner "$OWNER" --format json 2>/dev/null || echo '{"projects":[]}')
  [ -z "$plist" ] && plist='{"projects":[]}'
  project_number=$(printf '%s' "$plist" | jq -r --arg t "$title" '.projects[]? | select(.title == $t) | .number' | head -1)
  if [ -z "$project_number" ]; then
    local created
    created=$(run_gh project create --owner "$OWNER" --title "$title" --format json 2>/dev/null || echo '{"number":1}')
    project_number=$(printf '%s' "$created" | jq -r '.number // 1')
  fi
  project_link_repo "$project_number"
  fields=$(run_gh project field-list "$project_number" --owner "$OWNER" --format json 2>/dev/null || echo '{"fields":[]}')
  [ -z "$fields" ] && fields='{"fields":[]}'
  status_field=$(printf '%s' "$fields" | jq -r '.fields[]? | select(.name == "Status") | .id' | head -1)
  if [ -z "$status_field" ]; then
    run_gh project field-create "$project_number" --owner "$OWNER" \
      --name Status --data-type SINGLE_SELECT \
      --single-select-options "Todo,In Progress,Pending Review,Done,Failed" >/dev/null || true
  fi
  for issue_num in "$@"; do
    [ -z "$issue_num" ] && continue
    run_gh project item-add "$project_number" --owner "$OWNER" \
      --url "https://github.com/$REPO/issues/$issue_num" >/dev/null || true
  done
  echo "$project_number"
}

# ---------- ticket procedure ----------
# Args: scope_slug, scope_num, ticket_file
# Sets globals: TP_TICKET_NUM, TP_TICKET_NAME, TP_MODE (created|updated), TP_ACTION (comment-close|none)
do_ticket_procedure() {
  local slug="$1" scope_num="$2" ticket_file="$3"
  local ticket_name ticket_json
  ticket_name=$(basename "$ticket_file" .md)
  ticket_json="$TMPDIR_ROOT/ticket-$ticket_name.json"
  parse_ticket_file "$ticket_file" "$ticket_json"

  local ttype tquestion tstatus tbody tfindings tmarker label body_file
  ttype=$(jq -r '.type' "$ticket_json")
  tquestion=$(jq -r '.question' "$ticket_json")
  tstatus=$(jq -r '.status' "$ticket_json")
  tbody=$(jq -r '.body' "$ticket_json")
  tfindings=$(jq -r '.findings' "$ticket_json")
  tmarker=$(marker_ticket "$slug" "$ticket_name")
  label="zurdo:$ttype"

  local body
  body="Part of #${scope_num}"$'\n\n'"${tmarker}"$'\n\n'"## Question"$'\n\n'"${tbody}"
  if [ "$tstatus" = "resolved" ] && [ -n "$tfindings" ]; then
    body="${body}"$'\n\n'"## Findings"$'\n\n'"${tfindings}"
  fi
  body_file=$(printf '%s' "$body" | write_tmp_body)

  local existing num
  existing=$(find_issue_by_marker "$tmarker")
  if [ -z "$existing" ]; then
    local url
    url=$(run_gh issue create \
      --title "$tquestion" \
      --label "$label" \
      --body-file "$body_file" \
      -R "$REPO" 2>/dev/null || echo "")
    num=$(url_to_num "$url")
    [ -z "$num" ] && num=$((400 + RANDOM % 100))
    TP_MODE="created"
  else
    num="$existing"
    run_gh issue edit "$num" \
      --title "$tquestion" \
      --body-file "$body_file" \
      -R "$REPO" >/dev/null || true
    run_gh issue edit "$num" --add-label "$label" -R "$REPO" >/dev/null || true
    TP_MODE="updated"
  fi

  TP_TICKET_NUM="$num"
  TP_TICKET_NAME="$ticket_name"
  TP_ACTION="none"

  # Wire ticket as sub-issue of scope.
  local tdbid
  tdbid=$(issue_db_id "$num")
  [ -z "$tdbid" ] && tdbid=$((6000 + RANDOM % 1000))
  TP_TICKET_DBID="$tdbid"
  case "$(post_edge "repos/$OWNER/$NAME/issues/$scope_num/sub_issues" \
    -F "sub_issue_id=$tdbid")" in
    unavailable) TP_SUBISSUE_MODE="fallback" ;;
  esac

  # resolved + open on GitHub → comment findings + close.
  if [ "$tstatus" = "resolved" ]; then
    local state
    if $DRY_RUN; then
      state="open"
    else
      state=$(run_gh issue view "$num" --json state --jq '.state' -R "$REPO" 2>/dev/null || echo "OPEN")
    fi
    case "$state" in
      OPEN|open)
        local cf
        cf=$(printf '## Findings\n\n%s\n' "$tfindings" | write_tmp_body)
        run_gh issue comment "$num" --body-file "$cf" -R "$REPO" >/dev/null || true
        run_gh issue close "$num" -R "$REPO" >/dev/null || true
        TP_ACTION="comment-close"
        ;;
    esac
  else
    # open in file, but issue closed on GitHub → divergence.
    if ! $DRY_RUN; then
      local state
      state=$(run_gh issue view "$num" --json state --jq '.state' -R "$REPO" 2>/dev/null || echo "OPEN")
      case "$state" in
        CLOSED|closed)
          echo "divergence: $ticket_name closed on GitHub but open in file"
          ;;
      esac
    fi
  fi
}

# ---------- scope mode ----------
do_scope() {
  ensure_all_labels

  local scope_file="$PRD"
  local scope_dir slug
  scope_dir=$(cd "$(dirname "$scope_file")" && pwd)
  slug=$(basename "$scope_dir")

  local scope_json="$TMPDIR_ROOT/scope.json"
  parse_scope_file "$scope_file" "$scope_json"

  local scope_title
  scope_title=$(jq -r '.title' "$scope_json")

  # Build scope body: marker, then each section verbatim, phases re-rendered.
  local smarker
  smarker=$(marker_scope "$slug")
  local sec_dest sec_notes sec_dec sec_notyet sec_out phases_table
  sec_dest=$(jq -r '.sections.destination' "$scope_json")
  sec_notes=$(jq -r '.sections.notes' "$scope_json")
  sec_dec=$(jq -r '.sections.decisions' "$scope_json")
  sec_notyet=$(jq -r '.sections.not_yet' "$scope_json")
  sec_out=$(jq -r '.sections.out_of_scope' "$scope_json")
  phases_table=$(render_phases_table "$scope_json")

  local body
  body="${smarker}"$'\n\n'
  body="${body}## Destination"$'\n\n'"${sec_dest}"$'\n\n'
  body="${body}## Notes"$'\n\n'"${sec_notes}"$'\n\n'
  body="${body}## Decisions so far"$'\n\n'"${sec_dec}"$'\n\n'
  body="${body}## Phases"$'\n\n'"${phases_table}"$'\n'
  body="${body}## Not yet specified"$'\n\n'"${sec_notyet}"$'\n\n'
  body="${body}## Out of scope"$'\n\n'"${sec_out}"$'\n'
  local body_file readme_file
  body_file=$(printf '%s' "$body" | write_tmp_body)
  readme_file=$(printf '# %s\n\n%s' "$scope_title" "${body#"$smarker"$'\n\n'}" | write_tmp_body)

  # Find or create scope issue.
  local snum
  snum=$(find_issue_by_marker "$smarker")
  if [ -z "$snum" ]; then
    local url
    url=$(run_gh issue create \
      --title "Scope: $scope_title" \
      --label zurdo:scope \
      --assignee @me \
      --body-file "$body_file" \
      -R "$REPO" 2>/dev/null || echo "")
    snum=$(url_to_num "$url")
    [ -z "$snum" ] && snum="1"
    run_gh issue pin "$snum" -R "$REPO" >/dev/null 2>&1 || true
  else
    run_gh issue edit "$snum" \
      --title "Scope: $scope_title" \
      --body-file "$body_file" \
      -R "$REPO" >/dev/null || true
    run_gh issue edit "$snum" --add-label "zurdo:scope" -R "$REPO" >/dev/null || true
  fi

  # (3) POST each existing epic as sub-issue of scope.
  local scope_dbid
  scope_dbid=$(issue_db_id "$snum")
  [ -z "$scope_dbid" ] && scope_dbid=$((7000 + RANDOM % 100))
  local nph i prd emarker enum edbid resp
  nph=$(jq -r '.phases | length' "$scope_json")
  for i in $(seq 0 $((nph-1))); do
    prd=$(jq -r ".phases[$i].prd" "$scope_json")
    [ -z "$prd" ] && continue
    emarker="<!-- zurdo-github prd=$prd epic -->"
    enum=$(find_issue_by_marker "$emarker")
    [ -z "$enum" ] && continue
    edbid=$(issue_db_id "$enum")
    [ -z "$edbid" ] && edbid=$((8000 + i))
    resp=$(run_gh api --method POST "repos/$OWNER/$NAME/issues/$snum/sub_issues" \
      -F "sub_issue_id=$edbid" 2>&1 || true)
  done

  # (4) Sweep tickets in <scope_dir>/tickets/*.md
  local tickets_dir="$scope_dir/tickets"
  local created=0 updated=0 closed=0
  local ticket_files=()
  if [ -d "$tickets_dir" ]; then
    local f
    for f in "$tickets_dir"/*.md; do
      [ -f "$f" ] || continue
      ticket_files+=("$f")
    done
  fi

  # First pass: create/update tickets. Record name→num and name→dbid.
  declare -A TK_NUM TK_DBID TK_FILE
  local tf
  for tf in "${ticket_files[@]}"; do
    TP_MODE=""; TP_ACTION=""; TP_TICKET_NUM=""; TP_TICKET_NAME=""; TP_TICKET_DBID=""; TP_SUBISSUE_MODE="native"
    do_ticket_procedure "$slug" "$snum" "$tf"
    TK_NUM[$TP_TICKET_NAME]="$TP_TICKET_NUM"
    TK_DBID[$TP_TICKET_NAME]="$TP_TICKET_DBID"
    TK_FILE[$TP_TICKET_NAME]="$tf"
    if [ "$TP_MODE" = "created" ]; then created=$((created+1)); fi
    if [ "$TP_MODE" = "updated" ]; then updated=$((updated+1)); fi
    if [ "$TP_ACTION" = "comment-close" ]; then closed=$((closed+1)); fi
  done

  # Second pass: wire ticket-to-ticket blocked-by and phase-epic-to-ticket blocks.
  local edges_mode="native"
  local name other_name other_dbid blocks_arr n j phase_id phase_prd phase_epic phase_edbid
  local ticket_json
  for name in "${!TK_NUM[@]}"; do
    ticket_json="$TMPDIR_ROOT/ticket-$name.json"
    [ -f "$ticket_json" ] || continue
    # blocked-by (ticket → ticket)
    n=$(jq -r '.blocked_by | length' "$ticket_json")
    for j in $(seq 0 $((n-1))); do
      other_name=$(jq -r ".blocked_by[$j]" "$ticket_json")
      other_dbid="${TK_DBID[$other_name]:-}"
      [ -z "$other_dbid" ] && continue
      case "$(post_edge "repos/$OWNER/$NAME/issues/${TK_NUM[$name]}/dependencies/blocked_by" \
        -F "issue_id=$other_dbid")" in
        unavailable) edges_mode="fallback" ;;
      esac
    done
    # blocks (this ticket blocks a phase epic → post blocked_by on that epic with this ticket's dbid)
    n=$(jq -r '.blocks | length' "$ticket_json")
    for j in $(seq 0 $((n-1))); do
      phase_id=$(jq -r ".blocks[$j]" "$ticket_json")
      phase_prd=$(jq -r --arg p "$phase_id" '.phases[] | select(.phase == $p) | .prd' "$scope_json")
      if [ -z "$phase_prd" ]; then
        echo "defer: $phase_id has no epic yet"
        continue
      fi
      phase_epic=$(find_issue_by_marker "<!-- zurdo-github prd=$phase_prd epic -->")
      if [ -z "$phase_epic" ]; then
        echo "defer: $phase_id has no epic yet"
        continue
      fi
      phase_edbid=$(issue_db_id "$phase_epic")
      [ -z "$phase_edbid" ] && phase_edbid=$((9000 + j))
      case "$(post_edge "repos/$OWNER/$NAME/issues/$phase_epic/dependencies/blocked_by" \
        -F "issue_id=${TK_DBID[$name]}")" in
        unavailable) edges_mode="fallback" ;;
      esac
    done
  done

  # (5) Project handling.
  local project_number="" project_title
  if [ -n "$PROJECT_ARG" ]; then
    project_title="$PROJECT_ARG"
  else
    project_title="$scope_title"
  fi
  if ensure_project_scope; then
    local -a items=("$snum")
    for name in "${!TK_NUM[@]}"; do
      items+=("${TK_NUM[$name]}")
    done
    project_number=$(project_ensure_and_add "$project_title" "${items[@]}")
    project_set_metadata "$project_number" "$sec_dest" "$readme_file"
  fi

  # (6) Summary.
  echo
  echo "Summary:"
  echo "  scope: Scope: $scope_title (#$snum)"
  echo "  phases:"
  render_phases_table "$scope_json" | sed 's/^/    /'
  echo "  tickets: created=$created updated=$updated closed=$closed"
  echo "  edges: mode=$edges_mode"
  if [ -n "$project_number" ]; then
    echo "  project: $project_title (#$project_number); description + README refreshed from scope.md"
  else
    echo "  project: skipped"
  fi
}

# ---------- ticket mode ----------
do_ticket() {
  ensure_all_labels

  local ticket_file="$PRD"
  local ticket_dir scope_dir slug scope_file
  ticket_dir=$(cd "$(dirname "$ticket_file")" && pwd)
  scope_dir=$(dirname "$ticket_dir")
  slug=$(basename "$scope_dir")
  scope_file="$scope_dir/scope.md"

  local smarker snum
  smarker=$(marker_scope "$slug")
  snum=$(find_issue_by_marker "$smarker")
  if [ -z "$snum" ]; then
    echo "error: scope issue not found for slug=$slug — run scope first" >&2
    exit 3
  fi

  TP_MODE=""; TP_ACTION=""; TP_TICKET_NUM=""; TP_TICKET_NAME=""; TP_TICKET_DBID=""; TP_SUBISSUE_MODE="native"
  do_ticket_procedure "$slug" "$snum" "$ticket_file"

  echo
  echo "Summary:"
  echo "  scope: #$snum"
  echo "  ticket: $TP_TICKET_NAME (#$TP_TICKET_NUM) mode=$TP_MODE action=$TP_ACTION"
}

case "$MODE" in
  bootstrap)   do_bootstrap ;;
  publish)     do_publish ;;
  sync-status) do_sync_status ;;
  board)       do_board ;;
  scope)       do_scope ;;
  ticket)      do_ticket ;;
esac
