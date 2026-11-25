import { View, div, svg } from "gpui-kit";
import { v_flex, h_flex, InputState, Input, Scrollbar, v_virtual_list } from "gpui-base";
import { spaces, panes, terminals, focused, exec, readTextFile, watchFolder, theme, settings, window } from "herdr";

// The panels share data in one VM, but their host tasks belong to separate copies.
const scans = globalThis[Symbol.for("herdr.repoStatus.v2")] ??= new Map();

async function repoStatus(root, on, { after, visiting, urgent, allowInactive }, cx, current) {
  const repo = JSON.stringify([on, root]), now = Date.now();
  for (const [key, scan] of scans) {
    if (scan.pollAt <= now || (!scan.pollAt && scan.task.is_done())) scans.delete(key);
  }
  while (current()) {
    let scan = scans.get(repo);
    const pending = scan && !scan.pollAt && !scan.task.is_done();
    const reusable = scan?.status?.code === 0 && Date.now() < scan.pollAt
      && (scan.started >= after || (!urgent && Date.now() < scan.watchAt));
    if (!reusable && (!pending || (visiting && scan.started !== undefined && scan.started < after))) {
      if (!allowInactive && window()?.active === false) return null;
      const next = {};
      next.task = cx.spawn(async cx => {
        await cx.sleep(25); // Let both listeners for a watch batch join before starting Git.
        if (!allowInactive && window()?.active === false) return;
        next.started = Date.now();
        try {
          next.status = await exec("git", ["--no-optional-locks", "-c", "core.fsmonitor=false", "status", "--porcelain=v1", "-z", "--no-renames", "--untracked-files=all"], { cwd: root, on });
        } catch (error) {
          next.error = error;
        } finally {
          const finished = Date.now(), duration = finished - next.started;
          const delay = duration < 500 ? 0 : Math.min(60000, 5 * duration);
          next.watchAt = finished + delay;
          next.pollAt = finished + Math.max(10000, delay);
          if (next.status?.code !== 0 && scans.get(repo) === next) scans.delete(repo);
        }
      });
      scans.set(repo, next);
      scan = next;
    }
    // Resume through our own host task, so another copy's close cannot cancel our follow-up work.
    while (current() && !scan.pollAt && !scan.task.is_done()) await cx.sleep(50);
    if (!current()) return null;
    if (!scan.pollAt) continue; // The scanning copy closed or reloaded.
    return scan;
  }
  return null;
}

// The checkout picked for each agent ("" = its own folder; unset = the default), kept while this copy lives.
const choices = new Map();
const urgency = { blocked: 3, done: 2, working: 1 };
const bare = (address) => address?.includes("/") ? address.split("/").pop() : address;

// Where a terminal works now: the folder its Claude Code session moved to (`workdir` label,
// set by herdr-kit's herdr-workdir hook), else its process's live folder.
const workdir = (k) => k?.labels?.workdir || k?.cwd || null;

// The agent you're looking at, its own folder, and the other folders its live sub-agents
// (lead's workers) work in.
function checkouts() {
  const f = focused();
  const subject = f?.shown || f?.agent || f?.terminal || null;
  if (!subject) return { subject, own: null, latest: null, ownTree: null, list: [] };
  const all = terminals(), groups = new Map(), seen = new Set();
  const term = all.find(k => bare(k.address) === bare(subject));
  // A peeked or shown sub-agent has no pane: its terminal's folder is the one to use.
  const own = term?.labels?.workdir || ((f?.shown || f?.agent) ? term?.cwd : null) || null;
  // Worktrees the session edited (herdr-workdir hook's `worktrees` label), most recent first.
  const edited = (term?.labels?.worktrees ?? "").split(":").filter(Boolean);
  for (const cwd of edited) {
    groups.set(cwd, { cwd, names: [], status: null, edited: true });
  }
  const visit = (address) => {
    for (const k of all) {
      if (bare(k.parent) !== bare(address) || k.state !== "live" || seen.has(k.address)) continue;
      seen.add(k.address);
      const cwd = workdir(k);
      if (cwd) {
        const g = groups.get(cwd) ?? { cwd, names: [], status: null };
        g.names.push(k.name || k.address);
        if ((urgency[k.status] ?? 0) > (urgency[g.status] ?? 0)) g.status = k.status;
        groups.set(cwd, g);
      }
      visit(k.address);
    }
  };
  visit(subject);
  // The session's own folder is "This session", not a button, even when it's inside one of them.
  const home = own || term?.cwd, inside = (path, root) => Boolean(path) && (path === root || path.startsWith(root + "/"));
  // The worktree the session is in now, when it's one it edited (its button is named after it).
  const ownTree = edited.find(w => inside(home, w)) ?? null;
  return { subject, own, latest: edited[0] ?? null, ownTree, list: [...groups.values()].filter(g => !inside(home, g.cwd)) };
}

// The folder to show for the subject: a pick, else the worktree it last edited (its own folder
// when that's where it is now), else its own.
function chosenCheckout({ subject, latest, list }) {
  const chosen = choices.get(subject);
  if (chosen === "") return null;
  if (list.some(g => g.cwd === chosen)) return chosen;
  return list.some(g => g.cwd === latest) ? latest : null;
}
const basename = (path) => path.replace(/\/+$/, "").split("/").pop();

function location() {
  const space = spaces().find((s) => s.active), f = focused();
  const pane = f?.pane ? panes().find(p => p.pane === f.pane) : null;
  const on = f?.pane === null ? (f.terminal?.includes("/") ? f.terminal.split("/")[0] : null) : space?.machine ?? null;
  const found = checkouts(), { own } = found, picked = chosenCheckout(found);
  return { cwd: picked || own || pane?.cwd || f?.cwd || space?.folder, on };
}
// Branch view (default): the branch's whole change; off: only uncommitted changes.
let branchView = true;
// A commit picked in the Commits list: its own change replaces the list and diff.
let pickedCommit = null;
// What the branch is compared with: its open pull request's base ("pr"), so a stacked branch
// shows only its own work, or the repo's default branch ("default").
let baseMode = "pr";
const key = () => JSON.stringify({ ...location(), branchView, pickedCommit, baseMode });
// The last result for each folder and view, shown at once on switching back while a fresh
// one loads. The most recent 20 are kept.
const snapshots = new Map();
const SNAPSHOT = ["root", "on", "hasHead", "base", "shownCommit", "fork", "baseName", "prBase", "defaultBase", "log", "branch", "tracking", "files", "limited"];
// Reads write nothing under .git (no index refresh or lock, no fsmonitor cookie):
// the folder watch would see it, and every refresh would start the next one.
const READ = ["--no-optional-locks", "-c", "core.fsmonitor=false", "-c", "diff.autoRefreshIndex=false"];
const countLines = (text) => text ? text.split("\n").length - Number(text.endsWith("\n")) : 0;
const wideGlyph = /[\p{Ideographic}\p{Emoji_Presentation}\p{Extended_Pictographic}\u1100-\u115f\u2e80-\ua4cf\uac00-\ud7a3\ufe10-\ufe19\ufe30-\ufe6f\uff01-\uff60\uffe0-\uffe6]/gu;

// Keep room for spacing marks and give wide glyphs at least two columns.
function displayColumns(text) {
  let columns = text.length;
  for (const glyph of text.match(wideGlyph) ?? []) {
    if (glyph.length === 1) columns++;
  }
  return columns;
}

// The diff was laid out for 11px text: 20px rows, 7px characters.
const rowHeight = size => Math.ceil(size * 1.8), charWidth = size => size * 0.64;

// Text draws a tab as nothing: pad each to the next 4-column stop.
const untab = (text) => text.replace(/[^\t]*\t/g, (s) => s.slice(0, -1).padEnd((s.length - 1) - (s.length - 1) % 4 + 4));

// Numbers each diff line once, so a frame only draws the rows on screen.
function diffRows(lines) {
  let old = 0, next = 0;
  return lines.map((line) => {
    const match = /^@@ -(\d+)(?:,\d+)? \+(\d+)/.exec(line);
    if (match) { old = +match[1]; next = +match[2]; return { kind: "@", text: line }; }
    const kind = line[0];
    // `raw`: the line as written (tabs kept), for copying.
    if (kind === "-") return { kind, number: old++, text: untab(line.slice(1)) || " ", raw: line.slice(1) };
    if (kind === "+") return { kind, number: next++, text: untab(line.slice(1)) || " ", raw: line.slice(1) };
    if (kind === " ") { old++; return { kind, number: next++, text: untab(line.slice(1)) || " ", raw: line.slice(1) }; }
    return { kind: "", text: line };
  });
}

// Changed files as a folder tree. A folder whose only child is one folder joins it
// ("SharedPackages/ToastChat"), so deep paths don't become a staircase of single rows.
function fileTree(files) {
  const root = { dirs: new Map(), files: [] };
  for (const f of files) {
    const parts = f.path.split("/"), name = parts.pop();
    let node = root;
    for (const part of parts) {
      if (!node.dirs.has(part)) node.dirs.set(part, { dirs: new Map(), files: [] });
      node = node.dirs.get(part);
    }
    node.files.push({ ...f, name });
  }
  return root;
}

// Rows on screen, depth first: folders first, then files, each sorted by name.
function treeRows(node, collapsed, depth = 0, prefix = "") {
  const rows = [];
  for (const [name, child] of [...node.dirs].sort(([a], [b]) => a.localeCompare(b))) {
    let label = name, dir = child;
    while (!dir.files.length && dir.dirs.size === 1) {
      const [[next, only]] = dir.dirs;
      label += "/" + next; dir = only;
    }
    const path = prefix + label, inside = treeRows(dir, collapsed, depth + 1, path + "/");
    const files = [], walk = (n) => { files.push(...n.files); n.dirs.forEach(walk); };
    walk(dir);
    const open = !collapsed.has(path);
    rows.push({ kind: "dir", path, label, depth, open, add: files.reduce((n, f) => n + f.add, 0), del: files.reduce((n, f) => n + f.del, 0) });
    if (open) rows.push(...inside);
  }
  for (const f of [...node.files].sort((a, b) => a.name.localeCompare(b.name))) rows.push({ kind: "file", file: f, depth });
  return rows;
}

// Each branch's open pull request base, from `gh` (about a second, so in the background and
// kept 5 minutes). Until it answers, the default branch stands in.
const prBases = new Map();
const GH = ["gh", "/opt/homebrew/bin/gh", "/usr/local/bin/gh"];
function prBase(root, on, branch) {
  const k = JSON.stringify([on, root, branch]);
  let entry = prBases.get(k);
  if (!entry || (entry.done && Date.now() - entry.at > 300000)) {
    const next = { done: false, base: entry?.base ?? null, pr: entry?.pr ?? null };
    next.promise = (async () => {
      for (const gh of GH) {
        try {
          const r = await exec(gh, ["pr", "view", branch, "--json", "baseRefName,number,state"], { cwd: root, on, timeout: 8000 });
          if (r.code === 127) continue;
          const pr = r.code === 0 ? JSON.parse(r.stdout) : null;
          next.base = pr?.state === "OPEN" ? pr.baseRefName : null;
          next.pr = pr?.state === "OPEN" ? pr.number : null;
          return;
        } catch { /* not found here: try the next path */ }
      }
    })().finally(() => { next.done = true; next.at = Date.now(); });
    prBases.set(k, next);
    entry = next;
  }
  return entry;
}

// The branch's own commits since it left its base, and which are pushed.
async function branchInfo(git, root, on) {
  const [ref, current] = await Promise.all([git(["symbolic-ref", "--quiet", "--short", "refs/remotes/origin/HEAD"]), git(["branch", "--show-current"])]);
  const defaultBase = ref.code === 0 ? ref.stdout.trim() : "origin/main", branch = current.stdout.trim();
  const pr = branch ? prBase(root, on, branch) : null;
  // A pull request onto the default branch is no different from it.
  let stacked = pr?.base ? `origin/${pr.base}` : null;
  if (stacked === defaultBase || (stacked && (await git(["rev-parse", "--verify", "--quiet", stacked])).code !== 0)) stacked = null;
  const prBaseInfo = stacked ? { name: stacked, pr: pr.pr } : null;
  const baseName = baseMode === "pr" && stacked ? stacked : defaultBase;
  const pending = pr && !pr.done ? pr.promise : null;
  const none = { fork: null, baseName, prBase: prBaseInfo, defaultBase, log: [], pending };
  const [mb, head, u] = await Promise.all([git(["merge-base", "HEAD", baseName]), git(["rev-parse", "HEAD"]),
    git(["rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{upstream}"])]);
  if (mb.code !== 0 || head.code !== 0 || mb.stdout.trim() === head.stdout.trim()) return none;
  const fork = mb.stdout.trim();
  // Pushed: on the branch's upstream (else origin/<branch>). Rebased but not yet
  // force-pushed commits have new hashes, so they count as local, as they are.
  let upstream = u.code === 0 ? u.stdout.trim() : null;
  if (!upstream && branch && (await git(["rev-parse", "--verify", "--quiet", `refs/remotes/origin/${branch}`])).code === 0) upstream = `origin/${branch}`;
  const [r, on2] = await Promise.all([git(["log", "--no-color", "-n", "200", "--format=%H%x09%h%x09%cr%x09%s", `${fork}..HEAD`]),
    upstream ? git(["rev-list", "-n", "1000", `${fork}..${upstream}`]) : null]);
  const pushed = new Set(on2?.code === 0 ? on2.stdout.split("\n").filter(Boolean) : []);
  const log = r.code !== 0 ? [] : r.stdout.split("\n").filter(Boolean).map(l => {
    const [full, sha, when, ...s] = l.split("\t");
    return { sha, when, subject: s.join("\t"), pushed: pushed.has(full), upstream };
  });
  return { ...none, fork, log, branch, tracking: u.code === 0 };
}

export default class Changes extends View {
  init(_props, cx) {
    this.files = []; this.log = []; this.collapsed = new Set(); this.rows = []; this.longest = 0; this.gutterChars = 4; this.message = ""; this.handle = cx.focus_handle();
    this.input = InputState.new({ placeholder: "Commit message" });
    this.input.on("change", (_e, cx) => {
      const hadMessage = Boolean(this.message.trim());
      this.message = this.input.value();
      if (hadMessage !== Boolean(this.message.trim())) cx.notify();
    });
    this.input.on("submit", (_e, cx) => this.commit(cx));
    this.input.on("focus", (_e, cx) => { this.typing = true; cx.notify(); });
    this.input.on("blur", (_e, cx) => { this.typing = false; cx.notify(); });
    this.refresh(cx);
    cx.timer.every(500, cx => this.refreshIfDue(cx));
  }

  refreshIfDue(cx) {
    const active = window()?.active !== false, context = this.context;
    const refocused = active && this.windowActive === false;
    this.windowActive = active;
    if (!context) return;
    if (refocused && (context.dirtyAt || !context.watch)) context.catchUp = true;
    if (!active || this.loading || this.busy) return;
    const now = Date.now();
    if (context.catchUp || (context.dirtyAt && now >= context.watchAt) || now >= context.pollAt) this.refresh(cx);
  }

  watch(root, context, cx) {
    if (context.on || context.watch?.root === root) return;
    context.watch?.pending?.cancel();
    const watch = { root };
    context.watch = watch;
    cx.spawn(async cx => {
      try {
        while (this.context === context && context.watch === watch) {
          watch.pending = watchFolder(root);
          const paths = await watch.pending;
          if (paths.length && context.watch === watch && this.current(context)) {
            context.dirtyAt = Date.now() + 1;
            this.refreshIfDue(cx);
          }
        }
      } catch {
        if (context.watch === watch) context.watch = null;
      }
    });
  }

  // One visit to a folder: results from an earlier visit to the same folder are stale too.
  current(context) {
    return this.context === context && key() === context.key;
  }

  refresh(cx, force = false) {
    const { cwd, on } = location(), next = key();
    const visiting = next !== this.context?.key;
    if (visiting) {
      this.context?.watch?.pending?.cancel();
      this.context = { key: next, on, dirtyAt: 0 }; this.collapsed = new Set(); this.root = null; this.files = []; this.log = []; this.fork = null; this.base = null; this.open = null;
      this.setLines([]); this.message = ""; this.input.set_value(""); this.error = null; this.note = null; this.limited = false;
      this.loading = false;
      const snapshot = snapshots.get(next);
      if (snapshot) Object.assign(this, snapshot);
    }
    // A load left behind in another folder (a slow git, a read that never ends) must not hold this one.
    const context = this.context;
    const now = Date.now();
    if (!cwd) {
      context.catchUp = false;
      context.dirtyAt = 0;
      context.pollAt = now + 10000;
      return;
    }
    if (this.loading || this.busy) return;
    if (force || (context.catchUp && !context.dirtyAt)) context.dirtyAt = now + 1;
    const request = {
      after: visiting ? now + 1 : context.dirtyAt || (context.lastStatus ?? -1) + 1,
      visiting,
      urgent: force || visiting || context.catchUp,
      allowInactive: force || visiting,
    };
    context.catchUp = false;
    context.pollAt = context.watchAt = now + 10000;
    this.loading = true;
    cx.spawn(async (cx) => {
      try {
        const top = await exec("git", ["rev-parse", "--show-toplevel"], { cwd, on });
        if (!this.current(context)) return;
        if (top.code !== 0) { this.root = null; this.files = []; this.setLines([]); this.open = null; this.error = "Not a git repository"; return; }
        const root = top.stdout.trim(), git = (args) => exec("git", [...READ, ...args], { cwd: root, on });
        this.watch(root, context, cx);
        // Commits and the fork point don't need the working tree: look them up while git status runs.
        const branching = branchInfo(git, root, on).catch(() => ({ fork: null, baseName: null, log: [] }));
        const scan = await repoStatus(root, on, request, cx, () => this.context === context);
        if (!scan || !this.current(context)) return;
        const { status, started, pollAt, watchAt } = scan;
        context.lastStatus = started;
        context.pollAt = pollAt;
        context.watchAt = watchAt;
        // A failed scan still answers the edit that asked for it: retrying at once would spin.
        if (context.dirtyAt <= started) context.dirtyAt = 0;
        if (scan.error) throw scan.error;
        if (status.code !== 0) throw new Error(status.stderr);
        if (request.urgent && request.after > started) context.catchUp = true;
        const statusEntries = status.stdout.split("\0").filter(Boolean);
        const { fork, baseName, prBase: stackedOn, defaultBase, log, pending, branch, tracking } = await branching;
        // When the pull request lookup answers, look again with its base.
        pending?.then(() => { if (this.context === context) context.catchUp = true; });
        // Branch view: everything the branch changed, committed or not, so a session that
        // commits as it goes still shows its work.
        // A picked commit that isn't on this branch (another folder, a rebase) is dropped.
        const commit = log.some(c => c.sha === pickedCommit) ? pickedCommit : null;
        if (pickedCommit && !commit) pickedCommit = null;
        const base = commit ? null : branchView ? fork : null;
        // What the list compares: one commit, the branch since its fork, or HEAD.
        const against = (...args) => commit ? ["show", "--format=", ...args, commit] : ["diff", base || "HEAD", ...args];
        let entries = statusEntries, numstat = null;
        if (base || commit) {
          let names;
          [names, numstat] = await Promise.all([git(against("--name-status", "-z", "--no-renames")), git(against("--numstat", "-z", "--no-renames"))]);
          if (names.code !== 0) throw new Error(names.stderr);
          const parts = names.stdout.split("\0"), changed = [];
          for (let i = 0; i + 1 < parts.length; i += 2) if (parts[i]) changed.push(`${parts[i][0]}  ${parts[i + 1]}`);
          entries = commit ? changed : [...changed, ...statusEntries.filter(e => e.startsWith("??"))];
        }
        const shown = entries.slice(0, 1000);
        const tracked = shown.some(entry => !entry.startsWith("??"));
        const hasHead = Boolean(base || commit) || (tracked && (await git(["rev-parse", "--verify", "HEAD"])).code === 0);
        const stats = {};
        const results = !tracked ? [] : hasHead ? [numstat ?? await git(against("--numstat", "-z", "--no-renames"))] : [await git(["diff", "--cached", "--numstat", "-z", "--no-renames"]), await git(["diff", "--numstat", "-z", "--no-renames"])];
        for (const result of results) {
          if (result.code !== 0) throw new Error(result.stderr);
          for (const entry of result.stdout.split("\0")) {
            const [a, d, ...parts] = entry.split("\t");
            if (!parts.length) continue;
            const path = parts.join("\t"), old = stats[path] ?? { add: 0, del: 0 };
            stats[path] = { add: old.add + (Number(a) || 0), del: old.del + (Number(d) || 0), binary: a === "-" };
          }
        }
        const files = [];
        for (const entry of shown) {
          const xy = entry.slice(0, 2), path = entry.slice(3), fresh = xy === "??";
          const conflict = xy.includes("U") || xy === "AA" || xy === "DD";
          const s = conflict ? "U" : xy.includes("D") ? "D" : fresh || xy.includes("A") ? "A" : "M";
          const stat = stats[path] ?? { add: 0, del: 0 };
          files.push({ path, status: s, fresh, ...stat });
        }
        if (!this.current(context)) return;
        this.root = root; this.on = on; this.hasHead = hasHead; this.base = base; this.shownCommit = commit; this.fork = fork; this.baseName = baseName; this.prBase = stackedOn; this.defaultBase = defaultBase; this.log = log; this.branch = branch; this.tracking = tracking; this.files = files; this.limited = entries.length > 1000; this.error = null;
        snapshots.delete(context.key);
        snapshots.set(context.key, Object.fromEntries(SNAPSHOT.map(k => [k, this[k]])));
        if (snapshots.size > 20) snapshots.delete(snapshots.keys().next().value);
        if (this.open && !files.some((f) => f.path === this.open)) { this.open = null; this.setLines([]); }
        if (this.open) {
          try { await this.load(this.open, context); }
          catch { if (this.current(context)) this.setLines(["Cannot preview this diff (too large or unreadable)"]); }
        }
      } catch (e) { if (this.current(context)) this.error = String(e); }
      finally {
        if (this.context === context) this.loading = false;
        cx.notify();
      }
    });
  }

  async load(path, context) {
    const file = this.files.find((f) => f.path === path), root = this.root, on = this.on;
    if (!file) return;
    let lines;
    if (file.fresh || (!this.hasHead && file.status === "A")) {
      const text = await readTextFile(`${root}/${path}`, { on }).catch(() => null);
      if (text === null) lines = ["Cannot preview this file (binary, too large, or unreadable)"];
      else if (text.includes("\0")) lines = ["Binary file · no text diff"];
      else {
        file.add = countLines(text);
        lines = [`@@ -0,0 +1,${file.add} @@`, ...text.slice(0, 400000).replace(/\n$/, "").split("\n").slice(0, 1500).map(l => `+${l}`)];
      }
    } else {
      const how = ["--no-ext-diff", "--no-textconv", "--no-color"];
      const args = this.shownCommit ? ["show", "--format=", ...how, this.shownCommit] : ["diff", ...(this.hasHead ? [this.base || "HEAD"] : []), ...how];
      const r = await exec("git", [...READ, ...args, "--", path], { cwd: root, on });
      if (r.code !== 0) throw new Error(r.stderr);
      const all = r.stdout.replace(/\n$/, "").split("\n"), first = all.findIndex((l) => l.startsWith("@@"));
      lines = first < 0 ? [file.binary ? "Binary file changed" : "No text diff available"] : all.slice(first);
    }
    if (this.current(context) && this.open === path) this.setLines(lines.slice(0, 1500).map(line => line.length > 4000 ? line.slice(0, 4000) + "… (line truncated)" : line));
  }

  setLines(lines) {
    this.rows = diffRows(lines); this.sel = null; this.copied = null;
    this.longest = Math.max(0, ...this.rows.map(row => displayColumns(row.text)));
    this.gutterChars = Math.max(4, String(Math.max(0, ...this.rows.map(row => row.number ?? 0))).length);
  }

  pick(path, cx) {
    this.open = this.open === path ? null : path; this.setLines([]); this.note = null;
    const context = this.context;
    if (this.open) cx.spawn(async (cx) => {
      try { await this.load(path, context); }
      catch (e) { if (this.current(context) && this.open === path) this.note = `Cannot preview this diff (too large or unreadable): ${e}`; }
      cx.notify();
    });
    cx.notify();
  }

  // Pushes the branch: to its upstream, or to origin under its own name (and tracks it there).
  // Never forces: a rejected push (the remote moved, or a rebase needs --force-with-lease) only
  // says why. Not offered on claude/* branches, which stay local (as the push hook requires).
  pushButton(t) {
    const busy = this.pushing;
    return div().id("push").h(20).px(8).flex().items_center().rounded(5).text_size(11)
      .bg(busy ? t.raised : t.solid).text_color(busy ? t.dim : t.solid_foreground)
      .when(!busy, (e) => e.cursor_pointer()).tooltip(this.tracking ? "git push" : `git push -u origin ${this.branch}`)
      .on_click((_e, cx) => this.push(cx)).child(busy ? "Pushing…" : "Push");
  }

  push(cx) {
    if (this.pushing || !this.root || !this.branch || this.branch.startsWith("claude/")) return;
    const root = this.root, on = this.on, context = this.context;
    const args = this.tracking ? ["push"] : ["push", "-u", "origin", this.branch];
    this.pushing = true; this.note = null;
    cx.spawn(async (cx) => {
      try {
        const r = await exec("git", args, { cwd: root, on, timeout: 120000 });
        if (r.code !== 0) {
          const why = (r.stderr || r.stdout).trim().split("\n").filter(l => !l.startsWith("remote:")).slice(-3).join(" ");
          throw new Error(/non-fast-forward|fetch first|stale info/.test(why)
            ? `the remote branch has commits this one doesn't (after a rebase, push with --force-with-lease). ${why}` : why);
        }
      } catch (e) { if (this.current(context)) this.note = `Push failed: ${e.message ?? e}`; }
      finally { this.pushing = false; this.refresh(cx, true); cx.notify(); }
    });
    cx.notify();
  }

  commit(cx) {
    if (!this.message.trim() || !this.root || this.busy || this.loading || this.context?.key !== key()) return;
    const root = this.root, on = this.on, context = this.context, message = this.message.trim();
    this.busy = true; this.note = null;
    cx.spawn(async (cx) => {
      try {
        for (const args of [["add", "-A"], ["commit", "-m", message]]) {
          const r = await exec("git", args, { cwd: root, on });
          if (r.code !== 0) throw new Error((r.stderr || r.stdout).trim());
        }
        if (this.current(context)) { this.message = ""; this.input.set_value(""); }
      } catch (e) { if (this.current(context)) this.note = `Commit failed: ${e}`; }
      finally { this.busy = false; this.refresh(cx, true); cx.notify(); }
    });
    cx.notify();
  }

  // Which changes the list shows: the branch's whole change, or only what's uncommitted.
  scopeToggle(t) {
    const seg = (id, label, on, tip) => div().id(id).px(6).py(1).rounded(4).text_size(10.5).cursor_pointer().tooltip(tip)
      .bg(on ? t.selected : t.background).text_color(on ? t.foreground : t.muted).hover((s) => s.bg(t.hover))
      .on_click((_e, cx) => { branchView = id === "scope-branch"; cx.notify(); }).child(label);
    return h_flex().gap(2).p(1).rounded(5).border_1().border_color(t.border)
      .child(seg("scope-branch", "Branch", branchView, `Everything since the branch left ${this.baseName}, committed or not`))
      .child(seg("scope-uncommitted", "Uncommitted", !branchView, "Only changes not committed yet"));
  }

  // A folder (click to fold) or a changed file (click to show its diff), indented by depth.
  treeRow(row, t) {
    const indent = 8 + row.depth * 14, counts = (el, add, del, dim) => el
      .when(add > 0, (e) => e.child(div().flex_none().text_size(11).text_color(dim ? t.dim : t.ansi2).child(`+${add}`)))
      .when(del > 0, (e) => e.child(div().flex_none().text_size(11).text_color(dim ? t.dim : t.ansi1).child(`−${del}`)));
    if (row.kind === "dir") {
      return counts(h_flex().id(`dir-${row.path}`).h(26).flex_none().pl(indent).pr(8).gap(6).items_center().rounded(7).cursor_pointer().hover((s) => s.bg(t.hover)).tooltip(row.path)
        .on_click((_e, cx) => { if (row.open) this.collapsed.add(row.path); else this.collapsed.delete(row.path); cx.notify(); })
        .child(svg(`mods/changes-worktrees/chevron-${row.open ? "down" : "right"}.svg`).size(12).flex_none().text_color(t.dim))
        .child(svg("mods/changes-worktrees/folder.svg").size(13).flex_none().text_color(t.muted))
        .child(div().flex_1().min_w(0).truncate().text_color(t.muted).child(row.label)), row.add, row.del, true);
    }
    const f = row.file;
    return counts(h_flex().id(`change-${f.path}`).h(26).flex_none().pl(indent + 18).pr(8).gap(8).items_center().rounded(7).cursor_pointer().tooltip(f.path)
      .when(this.open === f.path, (e) => e.bg(t.selected)).hover((s) => s.bg(t.hover)).on_click((_e, cx) => this.pick(f.path, cx))
      .child(div().w(12).flex_none().text_size(11).text_color(f.status === "A" ? t.ansi2 : f.status === "D" || f.status === "U" ? t.ansi1 : t.blocked).child(f.status))
      .child(div().flex_1().min_w(0).truncate().child(f.name)), f.add, f.del, false);
  }

  // The commit being shown, with a way back to the whole branch.
  commitChip(t) {
    return h_flex().id("commit-chip").min_w(0).px(6).py(1).gap(5).rounded(4).border_1().border_color(t.accent).text_size(10.5).cursor_pointer()
      .hover((s) => s.bg(t.hover)).tooltip("Back to all changes")
      .on_click((_e, cx) => { pickedCommit = null; this.open = null; cx.notify(); })
      .child(div().text_color(t.accent).child(this.shownCommit)).child(div().text_color(t.muted).child("✕"));
  }

  // The base the branch is compared with. Stacked branches (an open pull request onto another
  // branch) can switch between that branch and the default one.
  baseSwitch(t) {
    const short = (name) => name?.replace(/^origin\//, "") ?? "";
    if (!this.prBase) return div().text_color(t.muted).child(short(this.baseName));
    const seg = (id, label, on, mode, tip) => div().id(id).px(5).rounded(4).cursor_pointer().tooltip(tip)
      .bg(on ? t.selected : t.background).text_color(on ? t.foreground : t.muted).hover((s) => s.bg(t.hover))
      .on_click((_e, cx) => { baseMode = mode; this.open = null; cx.notify(); }).child(label);
    const stacked = this.baseName === this.prBase.name;
    return h_flex().gap(2).p(1).rounded(5).border_1().border_color(t.border)
      .child(seg("base-pr", short(this.prBase.name), stacked, "pr", `The base of pull request #${this.prBase.pr}`))
      .child(seg("base-default", short(this.defaultBase), !stacked, "default", "The repository's default branch"));
  }

  // The branch's commits, newest first. Click one to see only its change.
  commits(t) {
    return v_flex().flex_none().border_t(1).border_color(t.border)
      .child(h_flex().h(28).flex_none().px(12).gap(6).items_center().text_size(11).text_color(t.muted)
        .child(div().font_semibold().text_color(t.foreground).child("Commits"))
        .child(div().child(`${this.log.length}${this.log.length >= 200 ? "+" : ""} since`))
        .child(this.baseSwitch(t))
        .children(this.log.some(c => !c.pushed) ? [div().text_color(t.blocked).child(`· ${this.log.filter(c => !c.pushed).length} not pushed`)] : [])
        .child(div().flex_1())
        .children(this.log.some(c => !c.pushed) && this.branch && !this.branch.startsWith("claude/") ? [this.pushButton(t)] : []))
      .child(div().h(Math.min(this.log.length, 6) * 24 + 4).flex_none().relative()
        .child(v_flex().id("changes-commits").absolute().inset_0().overflow_y_scroll().px(6).pb(4).children(this.log.map((c) =>
          h_flex().id(`commit-${c.sha}`).h(24).flex_none().px(6).gap(8).items_center().rounded(6).text_size(11.5).cursor_pointer().when(this.shownCommit === c.sha, (e) => e.bg(t.selected)).hover((s) => s.bg(t.hover))
            .on_click((_e, cx) => { pickedCommit = pickedCommit === c.sha ? null : c.sha; this.open = null; cx.notify(); }).tooltip(`${c.sha} · ${c.when} · ${c.pushed ? `pushed to ${c.upstream}` : c.upstream ? `not on ${c.upstream}` : "no remote branch"}\n${c.subject}`)
            // Filled: pushed. Hollow: only on this machine.
            .child(div().size(7).flex_none().rounded(4).when(c.pushed, (e) => e.bg(t.ansi2)).when(!c.pushed, (e) => e.border_1().border_color(t.blocked)))
            .child(div().flex_none().font_family(settings().font_family ?? "JetBrains Mono").text_size(10.5).text_color(t.accent).child(c.sha))
            .child(div().flex_1().min_w(0).truncate().child(c.subject))
            .child(div().flex_none().text_size(10.5).text_color(t.dim).child(c.when.replace(/ ago$/, ""))))))
        .child(Scrollbar.vertical("changes-commits").absolute().inset_0()));
  }

  gutter(size) { return Math.ceil(this.gutterChars * charWidth(size)) + 2; }

  // One pill for the agent's own folder, then one per folder its workers run in.
  picker(found, t) {
    const { subject, own, ownTree, list } = found, chosen = chosenCheckout(found);
    const pill = (id, label, tip, on, status, cwd) => h_flex().id(id).h(24).px(8).gap(5).flex_none().items_center().rounded(6)
      .text_size(11.5).bg(on ? t.selected : t.background).text_color(on ? t.foreground : t.muted).border_1().border_color(on ? t.border : t.background)
      .cursor_pointer().hover((s) => s.bg(t.hover)).tooltip(tip)
      .on_click((_e, cx) => { choices.set(subject, cwd ?? ""); cx.notify(); })
      .when(Boolean(status), (el) => el.child(div().size(6).rounded(3).bg(t[status])))
      .child(div().max_w(160).truncate().child(label));
    // overflow_x_scrollbar() wraps the row, so the fixed height has to sit on an outer box.
    return div().h(37).flex_none().border_b(1).border_color(t.border)
      .child(h_flex().id("changes-checkouts").size_full().px(8).gap(4).items_center().overflow_x_scrollbar()
        .child(pill("checkout-own", ownTree ? basename(ownTree) : "This session",
          `Where this session is working now\n${own || "The focused agent's own folder"}`, !chosen, null, null))
        .children(list.map((g, i) => pill(`checkout-${i}`,
          g.edited ? basename(g.cwd) : g.names[0] + (g.names.length > 1 ? ` +${g.names.length - 1}` : ""),
          [g.edited && "Edited by this session", g.names.length && g.names.join(", "), g.cwd].filter(Boolean).join("\n"),
          chosen === g.cwd, g.status, g.cwd))));
  }

  // Line selection in the diff: click a line, shift-click to extend; clicking the only selected
  // line clears it. Cmd+C copies the selected lines' code (no +/- markers or hunk headers),
  // Cmd+A selects every line, Escape clears. The list reports no modifiers with a click, so
  // Shift comes from the panel's own key events (it has the keyboard after the first click).
  pickLine(i, cx) {
    this.handle.focus();
    if (this.shift && this.sel) this.sel = { anchor: this.sel.anchor, head: i };
    else this.sel = this.sel && this.sel.anchor === i && this.sel.head === i ? null : { anchor: i, head: i };
    this.copied = null;
    cx.notify();
  }

  selected(i) {
    if (!this.sel) return false;
    const [a, b] = [this.sel.anchor, this.sel.head].sort((x, y) => x - y);
    return i >= a && i <= b;
  }

  copySelection(cx) {
    if (!this.sel) return;
    const [a, b] = [this.sel.anchor, this.sel.head].sort((x, y) => x - y);
    const lines = this.rows.slice(a, b + 1).filter(r => r.raw !== undefined).map(r => r.raw);
    if (!lines.length) return;
    cx.write_to_clipboard(lines.join("\n"));
    this.copied = `Copied ${lines.length} line${lines.length === 1 ? "" : "s"}`;
    cx.notify();
  }

  // The open file's path above its diff.
  diffBar(t) {
    return h_flex().h(30).flex_none().px(12).gap(8).items_center().border_b(1).border_color(t.border).text_size(11).text_color(t.muted)
      .child(div().id("diff-path").flex_1().min_w(0).truncate().cursor_pointer().hover((s) => s.text_color(t.foreground)).tooltip("Copy path")
        .on_click((_e, cx) => { cx.write_to_clipboard(this.open); this.copied = "Copied path"; cx.notify(); }).child(this.open))
      .children(this.copied ? [div().flex_none().text_color(t.ansi2).child(this.copied)]
        : this.sel ? [div().flex_none().text_color(t.dim).child("⇧-click to extend · ⌘C to copy")] : [])
      // Close: back to the file list alone (pick() on the open file unselects it).
      .child(div().id("diff-close").size(20).flex_none().flex().items_center().justify_center().rounded(5).cursor_pointer()
        .hover((s) => s.bg(t.hover)).tooltip("Close").on_click((_e, cx) => this.pick(this.open, cx))
        .child(svg("mods/changes-worktrees/close.svg").size(12).text_color(t.muted)));
  }

  diffRow({ kind, number, text }, t, size, i) {
    // No handlers in here: a virtual list's rows can't have them (clicks go to pickLine).
    const height = rowHeight(size), on = this.selected(i);
    if (kind === "@") return (div().w_full().px(12).h(height).flex_none().truncate().bg(on ? (t.selection ?? t.selected) : t.raised).text_color(t.dim).child(text));
    return h_flex().w_full().h(height).flex_none().gap(10).when(on, (e) => e.bg(t.selection ?? t.selected)).when(!on && kind === "+", (e) => e.bg(t.ansi2 + "18")).when(!on && kind === "-", (e) => e.bg(t.ansi1 + "18"))
      .child(div().w(this.gutter(size)).flex_none().text_right().text_color(t.dim).child(number === undefined ? "" : String(number)))
      .child(div().flex_1().min_w(0).truncate().child(text));
  }

  render(cx) {
    if (key() !== this.context?.key) this.refresh(cx);
    else this.refreshIfDue(cx);
    // The diff's text size, in px (it follows zoom like the rest of the panel).
    const t = theme(), size = 10, add = this.files.reduce((n, f) => n + f.add, 0), del = this.files.reduce((n, f) => n + f.del, 0);
    const enabled = Boolean(this.message.trim() && this.root && !this.busy && !this.loading);
    const worktrees = checkouts(), tree = treeRows(fileTree(this.files), this.collapsed);
    return v_flex().id("changes").size_full().min_h(0).rounded(10).overflow_hidden().bg(t.background).border_1().border_color(t.border).text_color(t.foreground).text_size(13).track_focus(this.handle)
      .on_modifiers_changed((e) => { this.shift = e.modifiers.shift; })
      .on_key_down((e, cx) => {
        if (e.key === "escape" && this.typing) { this.typing = false; this.handle.focus(); cx.stop_propagation(); cx.notify(); return; }
        if (this.typing) return;
        if (e.keystroke === "cmd-c" && this.sel) { this.copySelection(cx); cx.stop_propagation(); }
        else if (e.keystroke === "cmd-a" && this.rows.length) { this.sel = { anchor: 0, head: this.rows.length - 1 }; this.copied = null; cx.stop_propagation(); cx.notify(); }
        else if (e.key === "escape" && this.sel) { this.sel = null; this.copied = null; cx.stop_propagation(); cx.notify(); }
      })
      .child(h_flex().h(42).flex_none().px(14).gap(8).items_center().border_b(1).border_color(t.border)
        .child(div().font_semibold().child("Changes"))
        .when(Boolean(this.fork) && !this.shownCommit, (e) => e.child(this.scopeToggle(t)))
        .children(this.shownCommit ? [this.commitChip(t)] : [])
        .child(div().px(5).py(1).rounded(4).border_1().border_color(t.border).text_size(10).text_color(t.muted).child(`${this.files.length} files`))
        .child(div().flex_1()).child(div().text_size(11).text_color(t.ansi2).child(`+${add}`)).child(div().text_size(11).text_color(t.ansi1).child(`−${del}`)))
      .when(worktrees.list.length > 0 || Boolean(worktrees.ownTree), (e) => e.child(this.picker(worktrees, t)))
      // overflow_y_scrollbar() wraps the list, so its flex sizing never reached the panel's layout.
      // Nothing selected: no diff area, and the list takes the whole panel.
      .child(div().flex_1().min_h(44).when(Boolean(this.open), (e) => e.max_h(tree.length * 26 + 12).border_b(1).border_color(t.border)).relative()
        .child(v_flex().id("changes-list").absolute().inset_0().overflow_y_scroll().p(6).children(tree.map((row) => this.treeRow(row, t))).when(!this.files.length, (e) => e.child(div().p(8).text_color(t.dim).child(this.error || (this.loading ? "Loading changes…" : this.root ? (this.base ? "No changes on this branch" : "No uncommitted changes") : "No folder")))))
        .child(Scrollbar.vertical("changes-list").absolute().inset_0()))
      .when(this.limited, el => el.child(div().px(12).py(4).text_size(11).text_color(t.dim).child("Showing the first 1,000 changed files")))
      .children(this.open ? [this.diffBar(t)] : [])
      .when(Boolean(this.open), (e) => e.child(div().flex_1().min_h(0).relative().font_family(settings().font_family ?? "JetBrains Mono").text_size(size)
        .child(div().id("changes-diff-x").size_full().overflow_x_scrollbar()
          .child(div().w_full().min_w(Math.max(300, this.longest * charWidth(size) + this.gutter(size) + 20)).h_full().child(v_virtual_list("changes-diff", this.rows.length, rowHeight(size), (i) => String(i),
            (range) => this.rows.slice(range.start, range.end).map((row, j) => this.diffRow(row, t, size, range.start + j))).size_full().on_item_click((k, cx) => this.pickLine(Number(k), cx)))))
        .child(Scrollbar.vertical("changes-diff").viewport_from_layout().absolute().inset_0())))
      .when(this.log?.length > 0, (e) => e.child(this.commits(t)))
      .when(Boolean(this.note), (e) => e.child(div().px(10).pb(8).text_size(11).text_color(t.ansi1).child(this.note)))
      .child(h_flex().flex_none().p(10).gap(8).border_t(1).border_color(t.border)
        .child(div().id("commit-message").flex_1().min_w(0).h(32).px(10).flex().items_center().rounded(8).border_1().border_color(this.typing ? t.accent : t.border).cursor_text().on_mouse_down("left", (_e, cx) => cx.stop_propagation()).child(Input.new(this.input).h_full().text_size(12).text_color(t.foreground)))
        .child(div().id("commit").h(32).px(14).flex().items_center().rounded(8).bg(enabled ? t.solid : t.raised).text_color(enabled ? t.solid_foreground : t.dim).text_size(12).when(enabled, (e) => e.cursor_pointer()).on_click((_e, cx) => this.commit(cx)).child(this.busy ? "Committing…" : "Commit")));
  }
}
