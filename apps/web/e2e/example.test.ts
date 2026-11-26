import { expect, test } from '@playwright/test';
import project from '../../../project.json' with { type: 'json' };

test('should show the title', async ({ page }) => {
  // Start from the index page (the baseURL is set via the webServer in the playwright.config.ts)
  await page.goto('/');
  // The landing header shows the product name from project.json
  await expect(page.getByText(project.title, { exact: true })).toBeVisible();
});
