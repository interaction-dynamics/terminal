import { expect, test } from '@playwright/test';

test('sends anonymous visitors of the admin panel to the login page', async ({ page }) => {
  await page.goto('/admin');

  await expect(page).toHaveURL(/\/login\?redirect_url=%2Fadmin$/);
});
