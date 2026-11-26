// Machine-enforced hexagonal architecture and feature folder boundaries.
// Rule text: .agents/rules/hexagonal-architecture.md, .agents/rules/feature-layout.md
// Rationale: .docs/decisions/0026-enforce-import-boundaries-with-dependency-cruiser.md
// Run with: bun run lint:boundaries

const ADAPTERS = '^infrastructure/adapters/src/';
const FEATURES = '^apps/web/src/features/';

// Public entry points of a capability folder. Everything else under
// infrastructure/adapters/src/<capability>/ (vendor subfolders, helpers) is private.
// - index.ts(x): the capability port + vendor selection
// - interfaces.ts: the port types
// - wrappers.ts: build-time Next.js config wrappers (content-management, dev-tools)
// - monitoring/{client,server,telemetry}: runtime-specific entry points
//   (browser bundle, Node/Edge request path, instrumentation hook). They pick
//   the vendor themselves, so they are entry points, not vendors.
// - env.ts at the root: composes every capability's env schema for the app
//   (ADR 0027). It reads config only and loads no vendor SDK.
const CAPABILITY_ENTRY_POINTS = [
  `${ADAPTERS}env\\.ts$`,
  `${ADAPTERS}[^/]+/(index|interfaces|wrappers)\\.tsx?$`,
  `${ADAPTERS}monitoring/(client|server|telemetry)/index\\.ts$`,
];

// Vendor SDKs and the only vendor subfolder(s) allowed to import them.
// Framework packages (next, react), React-only libraries (@react-email/*)
// and the `flags` SDK (the experimentation port itself, see ADR 0002) are exempt.
const VENDOR_SDKS = [
  { sdk: '@next/third-parties', vendors: ['analytics/google'] },
  { sdk: '@vercel/analytics', vendors: ['analytics/vercel'] },
  { sdk: 'better-auth', vendors: ['authentication/better-auth'] },
  { sdk: '@next/mdx', vendors: ['content-management/markdown'] },
  { sdk: '@mdx-js/[^/]+', vendors: ['content-management/markdown'] },
  { sdk: 'drizzle-orm', vendors: ['database/drizzle'] },
  { sdk: 'drizzle-kit', vendors: ['database/drizzle'] },
  { sdk: '@neondatabase/serverless', vendors: ['database/drizzle'] },
  { sdk: '@vercel/toolbar', vendors: ['dev-tools/vercel-toolbar'] },
  { sdk: 'mailgun\\.js', vendors: ['email/mailgun'] },
  { sdk: 'form-data', vendors: ['email/mailgun'] },
  { sdk: 'resend', vendors: ['email/resend'] },
  { sdk: '@flags-sdk/posthog', vendors: ['experimentation/posthog'] },
  { sdk: '@flags-sdk/statsig', vendors: ['experimentation/statsig'] },
  { sdk: '@flags-sdk/vercel', vendors: ['experimentation/vercel'] },
  { sdk: '@vercel/otel', vendors: ['monitoring/vercel-otel'] },
  { sdk: 'stripe', vendors: ['payment/stripe'] },
];

// Tooling config files that legitimately load a vendor CLI outside src/.
const VENDOR_TOOLING = ['^infrastructure/adapters/drizzle\\.config\\.ts$'];

const vendorSdkRules = VENDOR_SDKS.map(({ sdk, vendors }) => ({
  name: `vendor-sdk-confined:${sdk.replaceAll('\\', '')}`,
  severity: 'error',
  comment:
    `${sdk.replaceAll('\\', '')} is a vendor SDK: import it only inside ` +
    `${vendors.map((v) => `infrastructure/adapters/src/${v}/`).join(' or ')}. ` +
    'Everything else goes through the capability port (@ship-it/adapters/<capability>).',
  from: {
    pathNot: [...vendors.map((v) => `${ADAPTERS}${v}/`), ...VENDOR_TOOLING],
  },
  // Matches the resolved node_modules path, or the bare specifier when the package
  // is not even installed in the importing workspace.
  to: { path: [`(^|/)node_modules/${sdk}/`, `^${sdk}(/|$)`] },
}));

/** @type {import('dependency-cruiser').IConfiguration} */
module.exports = {
  forbidden: [
    {
      name: 'app-imports-capability-only',
      severity: 'error',
      comment:
        'App code must import @ship-it/adapters/<capability> (or a documented entry point such as ' +
        'monitoring/client), never a vendor subfolder such as authentication/better-auth. ' +
        'If the app needs something only one vendor provides, expose it on the capability port.',
      from: { path: '^apps/' },
      to: { path: ADAPTERS, pathNot: CAPABILITY_ENTRY_POINTS },
    },
    {
      name: 'cross-capability-through-entry-point',
      severity: 'error',
      comment:
        'An adapter may reach into its own capability folder freely, but another capability only ' +
        'through that capability public entry point (@ship-it/adapters/<capability>).',
      from: { path: `${ADAPTERS}([^/]+)/` },
      to: {
        path: ADAPTERS,
        pathNot: [`${ADAPTERS}$1/`, ...CAPABILITY_ENTRY_POINTS],
      },
    },
    {
      name: 'entities-stay-pure',
      severity: 'error',
      comment:
        'Domain entities are the source of truth: they must not depend on the app, adapters or ' +
        'the ORM. Persistence mirrors the entity, not the other way round.',
      from: { path: '^domain/entities/' },
      to: {
        path: [
          '^(apps|infrastructure)/',
          '(^|/)node_modules/(drizzle-[^/]+|@ship-it/adapters)/',
          '^(drizzle-[^/]+|@ship-it/adapters)(/|$)',
        ],
      },
    },
    // Feature folders (.agents/rules/feature-layout.md, ADR 0047). A feature is
    // either a route folder with a `feature: true` README, whose `_private`
    // folders stay inside app/, or apps/web/src/features/<feature>/, whose root
    // files are its public API and whose subfolders are private to it.
    // Imports between two route folders are not checked: they need the README
    // to tell route features apart, which dependency-cruiser cannot read.
    {
      name: 'route-private-folders-stay-in-routes',
      severity: 'error',
      comment:
        'Private route folders (_components/, _use-cases/…) belong to their route. When code outside ' +
        'app/ needs them, the feature is not tied to one route: move it to apps/web/src/features/.',
      from: { path: '^apps/web/src/', pathNot: '^apps/web/src/app/' },
      to: { path: ['^apps/web/src/app/_[^/]*/', '^apps/web/src/app/.*/_[^/]*/'] },
    },
    {
      name: 'features-and-shared-code-skip-routes',
      severity: 'error',
      comment:
        'features/, components/, lib/ and config/ are rendered by routes, so they must not depend on ' +
        'app/. Move the code they need out of the route.',
      from: { path: '^apps/web/src/(features|components|lib|config)/' },
      to: { path: '^apps/web/src/app/' },
    },
    {
      name: 'feature-through-public-api',
      severity: 'error',
      comment:
        'A feature may use its own files freely, but another feature only through the files at the ' +
        'root of its folder (index.ts, server.ts), never its subfolders. Move code used by several ' +
        'features to components/, lib/ or config/.',
      from: { path: `${FEATURES}([^/]+)/` },
      to: { path: `${FEATURES}[^/]+/.+/`, pathNot: `${FEATURES}$1/` },
    },
    {
      name: 'app-uses-feature-public-api',
      severity: 'error',
      comment:
        'Routes, adapters and shared code import a feature only through the files at the root of ' +
        'its folder (@/features/<feature>), never its subfolders.',
      from: { path: '^apps/web/src/', pathNot: FEATURES },
      to: { path: `${FEATURES}[^/]+/.+/` },
    },
    {
      name: 'shared-code-stays-feature-free',
      severity: 'error',
      comment:
        'components/, lib/ and config/ hold code shared by several features, so they must not ' +
        'depend on a feature. Code that needs a feature belongs in that feature.',
      from: { path: '^apps/web/src/(components|lib|config)/' },
      to: { path: FEATURES },
    },
    ...vendorSdkRules,
    {
      name: 'no-unresolvable',
      severity: 'error',
      comment:
        'Unresolved imports cannot be checked against the rules above. Fix the import, or teach the ' +
        'resolver about it in .config/dependency-cruiser.cjs.',
      from: {},
      to: { couldNotResolve: true },
    },
  ],
  options: {
    parser: 'swc',
    moduleSystems: ['es6', 'cjs'],
    doNotFollow: { path: '(^|/)node_modules/' },
    exclude: {
      path: '(^|/)(\\.next|\\.turbo|coverage|test-results|playwright-report)/',
    },
    tsConfig: { fileName: 'apps/web/tsconfig.json' },
    enhancedResolveOptions: {
      exportsFields: ['exports'],
      conditionNames: ['import', 'require', 'node', 'default'],
      mainFields: ['module', 'main'],
      extensions: ['.ts', '.tsx', '.d.ts', '.js', '.jsx', '.mjs', '.cjs', '.json'],
    },
  },
};
