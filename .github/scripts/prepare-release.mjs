import fs from 'node:fs';

const version = process.argv[2];

if (!/^\d+\.\d+\.\d+$/.test(version)) {
  throw new Error(`Expected a stable semantic version, got "${version}".`);
}

const pubspecPath = 'pubspec.yaml';
const pubspec = fs.readFileSync(pubspecPath, 'utf8');
const updated = pubspec.replace(/^version:\s+\S+$/m, `version: ${version}+1`);

if (updated === pubspec) {
  throw new Error('Could not update the version in pubspec.yaml.');
}

fs.writeFileSync(pubspecPath, updated);
fs.writeFileSync('.next-release-version', `${version}\n`);
