// Builds the app and assembles build/Terminal.app.
//
//   bun scripts/bundle.ts            # release build
//   bun scripts/bundle.ts --debug    # debug build (faster to compile)
//   bun scripts/bundle.ts --open     # build, then launch it
//
// Needs libghostty first: `bun scripts/build-libghostty.ts`.
// The bundle is signed ad hoc, so it runs on this Mac only.

import { $ } from "bun";
import { existsSync } from "node:fs";
import { mkdir, rm, cp, writeFile } from "node:fs/promises";
import { join } from "node:path";

// App identity lives here (the name is still an open question, specs/08-open-questions.md).
const APP_NAME = "Terminal";
const BUNDLE_ID = "io.interaction-dynamics.terminal";
const VERSION = "0.1.0";
const MIN_MACOS = "14.0";

const root = join(import.meta.dir, "..");
const debug = process.argv.includes("--debug");
const open = process.argv.includes("--open");
const config = debug ? "debug" : "release";

const ghosttyShare = join(root, "Vendor", "ghostty", "share");
if (!existsSync(join(root, "Vendor", "ghostty", "GhosttyKit.xcframework"))) {
  console.error("libghostty is missing. Run: bun scripts/build-libghostty.ts");
  process.exit(1);
}

console.log(`Building (${config})…`);
await $`swift build -c ${config} --product ${APP_NAME}`.cwd(root);
const binDir = (await $`swift build -c ${config} --show-bin-path`.cwd(root).text()).trim();

const app = join(root, "build", `${APP_NAME}.app`);
const contents = join(app, "Contents");
const resources = join(contents, "Resources");
await rm(app, { recursive: true, force: true });
await mkdir(join(contents, "MacOS"), { recursive: true });
await mkdir(resources, { recursive: true });

await cp(join(binDir, APP_NAME), join(contents, "MacOS", APP_NAME));

// Ghostty resources: themes, and terminfo next to them (libghostty looks for
// ../terminfo from its resources dir). Ghostty's own shell integration is left
// out: we ship our own (App/Resources/shell-integration).
await cp(join(ghosttyShare, "ghostty", "themes"), join(resources, "ghostty", "themes"), { recursive: true });
await cp(join(ghosttyShare, "terminfo"), join(resources, "terminfo"), { recursive: true });
await cp(join(root, "App", "Resources", "shell-integration"), join(resources, "shell-integration"), { recursive: true });

await writeFile(
  join(contents, "Info.plist"),
  `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>${APP_NAME}</string>
  <key>CFBundleDisplayName</key><string>${APP_NAME}</string>
  <key>CFBundleExecutable</key><string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleVersion</key><string>${VERSION}</string>
  <key>LSMinimumSystemVersion</key><string>${MIN_MACOS}</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSSupportsAutomaticGraphicsSwitching</key><true/>
</dict>
</plist>
`,
);

await $`codesign --force --deep --sign - ${app}`.quiet();
console.log(`Done: ${app}`);

if (open) await $`open ${app}`;
