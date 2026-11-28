// Zips build/Terminal.app for a GitHub release and signs the zip
// (specs/10-updates.md). The release workflow runs it after
// `bun scripts/bundle.ts --version <version>`.
//
//   UPDATE_SIGNING_KEY="$(cat key.pem)" bun scripts/release-package.ts 0.2.0
//
// Output: dist/Terminal-<version>.zip and dist/Terminal-<version>.zip.sig
// (base64 Ed25519 signature of the zip). The app checks the signature against
// App/Resources/update-public-key.txt before installing.

import { $ } from "bun";
import { createPrivateKey, createPublicKey, sign, verify } from "node:crypto";
import { existsSync } from "node:fs";
import { mkdir, readFile, rm, writeFile } from "node:fs/promises";
import { join } from "node:path";

const APP_NAME = "Terminal";
const root = join(import.meta.dir, "..");
const version = process.argv[2];
if (!version || !/^\d+\.\d+\.\d+$/.test(version)) {
  console.error("Usage: bun scripts/release-package.ts <major.minor.patch>");
  process.exit(1);
}
const pem = process.env.UPDATE_SIGNING_KEY;
if (!pem) {
  console.error("UPDATE_SIGNING_KEY is not set (the private key, PEM). See scripts/release-keys.ts.");
  process.exit(1);
}

const app = join(root, "build", `${APP_NAME}.app`);
const plist = join(app, "Contents", "Info.plist");
if (!existsSync(app)) throw new Error(`${app} is missing: run bun scripts/bundle.ts --version ${version}`);
const built = (await $`/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" ${plist}`.text()).trim();
if (built !== version) throw new Error(`build/${APP_NAME}.app is version ${built}, expected ${version}`);

const dist = join(root, "dist");
await rm(dist, { recursive: true, force: true });
await mkdir(dist, { recursive: true });
const zip = join(dist, `${APP_NAME}-${version}.zip`);
// ditto keeps the bundle's symlinks, permissions and code signature.
await $`ditto -c -k --sequesterRsrc --keepParent ${app} ${zip}`;

const data = await readFile(zip);
const key = createPrivateKey(pem);
const signature = sign(null, data, key);

// Check against the public key the app ships with, so a wrong secret fails here.
const shipped = (await readFile(join(root, "App", "Resources", "update-public-key.txt"), "utf8")).trim();
const publicKey = createPublicKey({ key: { kty: "OKP", crv: "Ed25519", x: Buffer.from(shipped, "base64").toString("base64url") }, format: "jwk" });
if (!verify(null, data, publicKey, signature)) {
  throw new Error("UPDATE_SIGNING_KEY does not match App/Resources/update-public-key.txt");
}

await writeFile(`${zip}.sig`, signature.toString("base64") + "\n");
console.log(`Done: ${zip} (+ .sig), ${(data.length / 1e6).toFixed(1)} MB`);
