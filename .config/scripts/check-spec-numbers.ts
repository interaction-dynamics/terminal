// Fails when two feature spec folders in specs/ share a number.
// See .agents/rules/feature-specs.md.
import { existsSync, readdirSync } from 'node:fs';
import { join } from 'node:path';

const specsDir = join(import.meta.dir, '..', '..', 'specs');
const folderPattern = /^(\d{3})-[^.]+$/;

if (!existsSync(specsDir)) {
  console.log('No specs/ folder, nothing to check.');
  process.exit(0);
}

const foldersByNumber = new Map<string, string[]>();
for (const name of readdirSync(specsDir).toSorted()) {
  const match = folderPattern.exec(name);
  if (!match) continue;
  const number = match[1];
  foldersByNumber.set(number, [...(foldersByNumber.get(number) ?? []), name]);
}

const duplicates = [...foldersByNumber].filter(([, folders]) => folders.length > 1);

if (duplicates.length > 0) {
  console.error('Duplicate feature spec numbers in specs/:');
  for (const [number, folders] of duplicates) {
    console.error(`  ${number}: ${folders.join(', ')}`);
  }
  console.error('Give each new spec the next free number after the highest existing one.');
  process.exit(1);
}

console.log(`${foldersByNumber.size} feature specs, no duplicate numbers.`);
