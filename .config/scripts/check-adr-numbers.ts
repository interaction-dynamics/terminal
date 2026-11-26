// Fails when two decision records in .docs/decisions share a number.
// See .docs/decisions/0000-madr-template.md and .agents/rules/decision-records.md.
import { readdirSync } from 'node:fs';
import { join } from 'node:path';

const decisionsDir = join(import.meta.dir, '..', '..', '.docs', 'decisions');
const recordPattern = /^(\d{4})-.+\.md$/;

const filesByNumber = new Map<string, string[]>();
for (const file of readdirSync(decisionsDir).toSorted()) {
  const match = recordPattern.exec(file);
  if (!match) continue;
  const number = match[1];
  filesByNumber.set(number, [...(filesByNumber.get(number) ?? []), file]);
}

const duplicates = [...filesByNumber].filter(([, files]) => files.length > 1);

if (duplicates.length > 0) {
  console.error('Duplicate decision record numbers in .docs/decisions:');
  for (const [number, files] of duplicates) {
    console.error(`  ${number}: ${files.join(', ')}`);
  }
  console.error('Give each new record the next free number after the highest existing one.');
  process.exit(1);
}

console.log(`${filesByNumber.size} decision records, no duplicate numbers.`);
