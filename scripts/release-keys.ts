// Creates the Ed25519 key pair that signs release zips (specs/10-updates.md).
// Run once. The app only installs updates signed by this key.
//
//   bun scripts/release-keys.ts                # create the keys
//   bun scripts/release-keys.ts --set-secret   # also store the private key as
//                                              # the UPDATE_SIGNING_KEY GitHub secret
//
// Public key  -> App/Resources/update-public-key.txt (commit it)
// Private key -> ~/.config/terminal-release/update-signing-key.pem (mode 600).
//                Keep a copy in a password manager: without it, the installed
//                apps can't be updated any more.

import { $ } from "bun";
import { generateKeyPairSync } from "node:crypto";
import { existsSync } from "node:fs";
import { chmod, mkdir, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";

const REPO = "interaction-dynamics/terminal";
const root = join(import.meta.dir, "..");
const publicPath = join(root, "App", "Resources", "update-public-key.txt");
const privateDir = join(homedir(), ".config", "terminal-release");
const privatePath = join(privateDir, "update-signing-key.pem");

if (existsSync(privatePath)) {
  console.error(`${privatePath} already exists. Delete it first if you really want new keys:`);
  console.error("apps signed with the old key would stop accepting updates.");
  process.exit(1);
}

const { publicKey, privateKey } = generateKeyPairSync("ed25519");
// Raw 32-byte public key, base64: what CryptoKit's Curve25519 expects.
const raw = Buffer.from(publicKey.export({ format: "jwk" }).x!, "base64url").toString("base64");
const pem = privateKey.export({ format: "pem", type: "pkcs8" }).toString();

await mkdir(privateDir, { recursive: true });
await writeFile(privatePath, pem, { mode: 0o600 });
await chmod(privatePath, 0o600);
await writeFile(publicPath, raw + "\n");

console.log(`Public key:  ${publicPath} (commit it)`);
console.log(`Private key: ${privatePath} (keep a copy somewhere safe)`);

if (process.argv.includes("--set-secret")) {
  await $`gh secret set UPDATE_SIGNING_KEY --repo ${REPO} < ${privatePath}`;
  console.log(`GitHub secret UPDATE_SIGNING_KEY set on ${REPO}.`);
} else {
  console.log(`Then: gh secret set UPDATE_SIGNING_KEY --repo ${REPO} < ${privatePath}`);
}
