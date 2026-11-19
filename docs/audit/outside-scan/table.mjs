// Renders the findings table of docs/audit/outside-scan.md from the redacted data (fix-review.json holds every
// finding in its latest state) and Crow's triage (triage.json). T-555.
//   node docs/audit/outside-scan/table.mjs           print the table
//   node docs/audit/outside-scan/table.mjs --write   replace the table between the page's two markers
// tests/outside-scan.test.ts fails when the page's table is not what this script renders.
import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
export const PAGE = join(here, '..', 'outside-scan.md');
export const START = '<!-- findings table: rendered by node docs/audit/outside-scan/table.mjs --write -->';
export const END = '<!-- end of findings table -->';

const read = (f) => JSON.parse(readFileSync(join(here, f), 'utf8'));
// A Markdown table cell: backslashes first, then the pipe, so a title cannot end a cell or escape the next one.
const cell = (s) => String(s ?? '').replace(/\\/g, '\\\\').replace(/\|/g, '\\|').replace(/\s+/g, ' ').trim();
const SHORT = { Informational: 'Info' };
export const STATUS_ORDER = ['open', 'fixed in part', 'fixed in the new version', 'fixed off chain', 'deploy check', 'accepted limit', 'not a defect'];
const SEVERITY_ORDER = ['Critical', 'High', 'Medium', 'Low', 'Informational'];

export function findings() {
  const first = new Set(read('first-scan.json').artifacts.filter((a) => a.kind === 'finding').map((a) => a.id));
  const review = read('fix-review.json').artifacts.filter((a) => a.kind === 'finding');
  const triage = read('triage.json').findings;
  const byId = new Map(review.map((a) => [a.id, a]));
  // Open items first, then by what Crow did, then by the scan's rating, then by ID.
  const rank = (list, v) => { const i = list.indexOf(v); return i < 0 ? list.length : i; };
  const rows = Object.keys(triage).map((id) => ({ id, a: byId.get(id), t: triage[id] })).sort((x, y) =>
    rank(STATUS_ORDER, x.t.status) - rank(STATUS_ORDER, y.t.status)
    || rank(SEVERITY_ORDER, x.a?.data.severity) - rank(SEVERITY_ORDER, y.a?.data.severity)
    || x.id.localeCompare(y.id));
  return { first, review, triage, rows };
}

export function renderTable() {
  const { first, review, triage, rows } = findings();
  const count = (f) => rows.filter(f).length;
  const statuses = [...new Set(rows.map((r) => r.t.status))];
  const lines = [
    START,
    '',
    `${review.length} findings: ${first.size} from the first scan and ${review.length - first.size} new in the fix review. By Crow's status: ${statuses.map((s) => `${s} ${count((r) => r.t.status === s)}`).join(', ')}. Every row is in \`triage.json\` (${Object.keys(triage).length} rows).`,
    '',
    '| ID | The finding (the scan\'s title) | Scan | Disposition | Crow | Triage | Status | Fix review | Note |',
    '| --- | --- | --- | --- | --- | --- | --- | --- | --- |',
    ...rows.map(({ id, a, t }) => {
      const d = a?.data ?? {};
      const disposition = d.duplicate_of ? `duplicate of \`${d.duplicate_of}\`` : d.disposition;
      return `| \`${id}\` | ${cell(d.title)} | ${SHORT[d.severity] ?? d.severity} | ${cell(disposition)} | ${SHORT[t.rating] ?? t.rating} | ${t.outcome} | ${t.status} | ${t.review || 'no change'} | ${cell(t.note)} |`;
    }),
    '',
    END,
  ];
  return lines.join('\n');
}

export function pageWithTable(page) {
  const s = page.indexOf(START), e = page.indexOf(END);
  if (s < 0 || e < s) throw new Error(`${PAGE} lacks the table markers`);
  return page.slice(0, s) + renderTable() + page.slice(e + END.length);
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  if (process.argv.includes('--write')) { writeFileSync(PAGE, pageWithTable(readFileSync(PAGE, 'utf8'))); console.log('wrote the table in docs/audit/outside-scan.md'); }
  else console.log(renderTable());
}
