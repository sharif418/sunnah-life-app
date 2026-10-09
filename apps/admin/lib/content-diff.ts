// ─────────────────────────────────────────────────────────────────────────────
// What changed between two versions of a pack — for the reviewing scholar
// (who must see exactly what will reach the apps) and for the history. Entries
// are matched by id (by place when a pack has none); changed text is shown
// word by word, so a one-word fix in a hadith's translation stands out.
// ─────────────────────────────────────────────────────────────────────────────
import {
  entryKey,
  listOf,
  stableJson,
  type Doc,
  type Item,
  type PackConfig,
  type PackField,
} from "./content-packs";

export interface FieldChange {
  field: PackField;
  before: unknown;
  after: unknown;
}

export interface EntryChange {
  key: string;
  before: Item;
  after: Item;
  fields: FieldChange[];
  children?: ListDiff;
}

export interface ListDiff {
  added: { key: string; item: Item }[];
  removed: { key: string; item: Item }[];
  changed: EntryChange[];
  /** same entries, another order */
  reordered: boolean;
}

export interface PackDiff extends ListDiff {
  /** a side list (duas → categories) changed */
  extraChanged: boolean;
  /** anything else in the pack document changed */
  otherKeys: string[];
}

const same = (a: unknown, b: unknown) => stableJson(a) === stableJson(b);

function diffList(
  idKey: string | undefined,
  fields: PackField[],
  before: Item[],
  after: Item[],
  child?: { key: string; fields: PackField[]; idKey: string }
): ListDiff {
  const bMap = new Map(before.map((it, i) => [entryKey(idKey, it, i), it]));
  const aMap = new Map(after.map((it, i) => [entryKey(idKey, it, i), it]));
  const added = [...aMap].filter(([k]) => !bMap.has(k)).map(([key, item]) => ({ key, item }));
  const removed = [...bMap].filter(([k]) => !aMap.has(k)).map(([key, item]) => ({ key, item }));
  const changed: EntryChange[] = [];
  for (const [key, a] of aMap) {
    const b = bMap.get(key);
    if (!b || same(a, b)) continue;
    const fc = fields
      .filter((f) => !same(a[f.key], b[f.key]))
      .map((f) => ({ field: f, before: b[f.key], after: a[f.key] }));
    const children = child
      ? diffList(child.idKey, child.fields, listOf(b, child.key), listOf(a, child.key))
      : undefined;
    const childChanged = !!children && (children.added.length || children.removed.length || children.changed.length || children.reordered);
    if (fc.length || childChanged) changed.push({ key, before: b, after: a, fields: fc, children: childChanged ? children : undefined });
  }
  const common = (keys: string[], other: Map<string, Item>) => keys.filter((k) => other.has(k));
  const reordered = !same(common([...bMap.keys()], aMap), common([...aMap.keys()], bMap));
  return { added, removed, changed, reordered };
}

// the child's `order` follows the list — a reorder shows as "reordered", not
// as every entry's order changing
const withoutOrder = (fields: PackField[]) => fields.filter((f) => f.key !== "order");

export function diffPack(cfg: PackConfig, before: Doc | null, after: Doc | null): PackDiff {
  const base = diffList(
    cfg.idKey,
    cfg.fields,
    listOf(before, cfg.arrayKey),
    listOf(after, cfg.arrayKey),
    cfg.child ? { key: cfg.child.key, fields: withoutOrder(cfg.child.fields), idKey: "id" } : undefined
  );
  const extraChanged = !!cfg.extra && !same(before?.[cfg.extra.key], after?.[cfg.extra.key]);
  const known = new Set([cfg.arrayKey, cfg.extra?.key].filter(Boolean) as string[]);
  const keys = new Set([...Object.keys(before ?? {}), ...Object.keys(after ?? {})]);
  const otherKeys = [...keys].filter((k) => !known.has(k) && !same(before?.[k], after?.[k]));
  return { ...base, extraChanged, otherKeys };
}

export function diffIsEmpty(d: PackDiff): boolean {
  return !d.added.length && !d.removed.length && !d.changed.length && !d.reordered && !d.extraChanged && !d.otherKeys.length;
}

// ── word-level text diff ─────────────────────────────────────────────────────

export interface Segment {
  kind: "same" | "add" | "del";
  text: string;
}

/** Words and the spaces between them, so the joined segments rebuild the text. */
const tokens = (s: string) => s.match(/\s+|[^\s]+/g) ?? [];

/** LCS over words; above ~1,500 words a side it falls back to before/after. */
export function wordDiff(before: string, after: string): Segment[] {
  const a = tokens(before);
  const b = tokens(after);
  if (a.length * b.length > 2_500_000) {
    return [
      { kind: "del", text: before },
      { kind: "add", text: after },
    ];
  }
  const n = a.length;
  const m = b.length;
  // lengths of the LCS of a[i:] and b[j:]
  const dp = Array.from({ length: n + 1 }, () => new Uint16Array(m + 1));
  for (let i = n - 1; i >= 0; i--) {
    for (let j = m - 1; j >= 0; j--) {
      dp[i][j] = a[i] === b[j] ? dp[i + 1][j + 1] + 1 : Math.max(dp[i + 1][j], dp[i][j + 1]);
    }
  }
  const out: Segment[] = [];
  const push = (kind: Segment["kind"], text: string) => {
    const last = out[out.length - 1];
    if (last && last.kind === kind) last.text += text;
    else out.push({ kind, text });
  };
  let i = 0;
  let j = 0;
  while (i < n && j < m) {
    if (a[i] === b[j]) {
      push("same", a[i]);
      i++;
      j++;
    } else if (dp[i + 1][j] >= dp[i][j + 1]) push("del", a[i++]);
    else push("add", b[j++]);
  }
  while (i < n) push("del", a[i++]);
  while (j < m) push("add", b[j++]);
  return out;
}
