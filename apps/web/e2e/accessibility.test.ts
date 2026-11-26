import { expect, test } from '@playwright/test';
import { checkA11y, injectAxe } from 'axe-playwright';

for (const colorScheme of ['light', 'dark'] as const) {
  test(`should not have accessibility violations in ${colorScheme} mode`, async ({ page }) => {
    await page.emulateMedia({ colorScheme });
    // Start from the index page (the baseURL is set via the webServer in the playwright.config.ts)
    await page.goto('/');

    // The hero fades in once hydrated, and axe skips or misreads text that is still transparent.
    await expect(page.locator('h1').locator('..')).toHaveCSS('opacity', '1');

    await injectAxe(page);

    await checkA11y(page, undefined, {
      detailedReport: true,
      detailedReportOptions: { html: true },
    });
  });
}
