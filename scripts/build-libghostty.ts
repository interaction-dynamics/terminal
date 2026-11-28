// Builds libghostty (GhosttyKit.xcframework) from a pinned Ghostty release.
//
//   bun scripts/build-libghostty.ts            # clone if needed, build
//   bun scripts/build-libghostty.ts --clean    # rebuild from scratch
//
// Output (gitignored):
//   Vendor/ghostty/src/                      pinned Ghostty checkout
//   Vendor/ghostty/GhosttyKit.xcframework    static lib + C header
//   Vendor/ghostty/share/                    resources (terminfo, themes)
//
// Needs: Zig (pinned in mise.toml) and Xcode with the Metal Toolchain
// (`xcodebuild -downloadComponent MetalToolchain`).
// Upgrade Ghostty on purpose: change GHOSTTY_TAG, rebuild, re-run the bench.

import { $ } from "bun";
import { existsSync } from "node:fs";
import { join } from "node:path";

export const GHOSTTY_TAG = "v1.4.0";
const GHOSTTY_REPO = "https://github.com/ghostty-org/ghostty";

const root = join(import.meta.dir, "..");
const vendor = join(root, "Vendor", "ghostty");
const src = join(vendor, "src");
const clean = process.argv.includes("--clean");

if (clean) await $`rm -rf ${src}/zig-out ${src}/.zig-cache ${src}/macos/GhosttyKit.xcframework`;

if (!existsSync(src)) {
  console.log(`Cloning Ghostty ${GHOSTTY_TAG}…`);
  await $`git clone --depth 1 --branch ${GHOSTTY_TAG} ${GHOSTTY_REPO} ${src}`;
} else {
  const tag = (await $`git -C ${src} describe --tags --exact-match`.nothrow().text()).trim();
  if (tag !== GHOSTTY_TAG) {
    throw new Error(`Vendor/ghostty/src is at "${tag}", expected ${GHOSTTY_TAG}. Delete it and re-run.`);
  }
}

console.log("Building libghostty (ReleaseFast, native arch)…");
await $`mise exec -- zig build -Doptimize=ReleaseFast -Demit-xcframework=true -Demit-macos-app=false -Dxcframework-target=native`.cwd(src);

await $`rm -rf ${vendor}/GhosttyKit.xcframework ${vendor}/share`;
await $`cp -R ${src}/macos/GhosttyKit.xcframework ${vendor}/GhosttyKit.xcframework`;
await $`cp -R ${src}/zig-out/share ${vendor}/share`;
await $`cp ${src}/LICENSE ${vendor}/LICENSE`;

console.log(`Done: Vendor/ghostty/GhosttyKit.xcframework (Ghostty ${GHOSTTY_TAG})`);
