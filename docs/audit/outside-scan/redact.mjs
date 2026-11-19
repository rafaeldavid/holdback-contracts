// Writes the two redacted data files of Zero Cool's scan and fix review of Crow's contracts (T-555) from the files
// the firm's API returned, which Crow keeps privately. Run it again on the same input and it writes the same bytes.
//   node docs/audit/outside-scan/redact.mjs <folder that holds report/job.json, report/artifacts.json, fix-review/work.json>
// What it removes: the workspace, the account and the requester (name and avatar), the access and lineage records,
// the price in credits and the job IDs (each replaced by "first-scan" or "fix-review"). Each artifact ID is shortened
// to its first 8 characters, the form Crow's docs cite. It refuses to write a file in which a UUID or an email
// address remains. tests/outside-scan.test.ts checks the written files again.
import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

export const UUID = /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/gi;
export const EMAIL = /[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}/g;

const pick = (o, keys) => Object.fromEntries(keys.filter((k) => o && k in o).map((k) => [k, o[k]]));
const REQUEST = ['audit_mode', 'job_type', 'poc_policy', 'report_format', 'guidance', 'documents', 'targets'];
const RESULT = ['job_type', 'name', 'status', 'created_at', 'completed_at', 'duration_seconds', 'configuration', 'summary', 'targets'];

// Replace every known UUID in every string; each artifact's ID becomes its 8-character prefix.
function rewrite(value, names) {
  if (typeof value === 'string') return value.replace(UUID, (u) => names.get(u.toLowerCase()) ?? u);
  if (Array.isArray(value)) return value.map((v) => rewrite(v, names));
  if (value && typeof value === 'object') return Object.fromEntries(Object.entries(value).map(([k, v]) => [k, rewrite(v, names)]));
  return value;
}

function redactJob(job, label, parent) {
  const out = { job: label };
  if (parent) out.parent = parent;
  return { ...out, status: job.status, request: pick(job.request, REQUEST), result: pick(job.result, RESULT) };
}

export function redact(input) {
  const first = JSON.parse(readFileSync(join(input, 'report/job.json'), 'utf8')).job;
  const firstArtifacts = JSON.parse(readFileSync(join(input, 'report/artifacts.json'), 'utf8'));
  const work = JSON.parse(readFileSync(join(input, 'fix-review/work.json'), 'utf8'));
  const names = new Map([[first.id.toLowerCase(), 'first-scan'], [work.job.id.toLowerCase(), 'fix-review']]);
  for (const a of [...firstArtifacts, ...work.artifacts]) names.set(a.id.toLowerCase(), a.id.slice(0, 8).toLowerCase());
  const files = {
    'first-scan.json': rewrite({ ...redactJob(first, 'first-scan'), artifacts: firstArtifacts.map(({ id, kind, data }) => ({ id, kind, data })) }, names),
    'fix-review.json': rewrite({ ...redactJob(work.job, 'fix-review', 'first-scan'), artifacts: work.artifacts.map(({ id, kind, data }) => ({ id, kind, data })) }, names),
  };
  const text = Object.fromEntries(Object.entries(files).map(([f, v]) => [f, `${JSON.stringify(v, null, 2)}\n`]));
  for (const [f, t] of Object.entries(text)) {
    const left = [...(t.match(UUID) ?? []), ...(t.match(EMAIL) ?? [])];
    if (left.length) throw new Error(`${f}: ${left.length} UUID or email address left after redaction; nothing written`);
  }
  return text;
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  const input = process.argv[2];
  if (!input) { console.error('usage: node docs/audit/outside-scan/redact.mjs <private crow-scan folder>'); process.exit(2); }
  const here = dirname(fileURLToPath(import.meta.url));
  for (const [f, t] of Object.entries(redact(input))) { writeFileSync(join(here, f), t); console.log(`wrote docs/audit/outside-scan/${f} (${Buffer.byteLength(t)} bytes)`); }
}
