import fs from 'node:fs';

const version = process.argv[2];

if (!/^\d+\.\d+\.\d+$/.test(version)) {
  throw new Error(`Expected a stable semantic version, got "${version}".`);
}

fs.writeFileSync('.next-release-version', `${version}\n`);
