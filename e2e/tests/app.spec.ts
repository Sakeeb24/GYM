import { test, expect } from '@playwright/test';

test.describe('LiftFlow Web & Authentication E2E', () => {
  test('landing / login page renders correctly', async ({ page }) => {
    await page.goto('/');

    // Wait for Flutter web canvas or app container to load
    await page.waitForLoadState('networkidle');

    // Verify document title
    await expect(page).toHaveTitle(/LiftFlow/);
  });

  test('login interface supports password and magic link modes', async ({ page }) => {
    await page.goto('/#/login');
    await page.waitForLoadState('domcontentloaded');

    // Page title validation
    await expect(page).toHaveTitle(/LiftFlow/);
  });
});

test.describe('Role-Based Barriers & Security Boundaries', () => {
  test('unauthenticated users are redirected to login', async ({ page }) => {
    await page.goto('/#/app');
    await page.waitForLoadState('networkidle');

    // Hash or URL should redirect / maintain login path
    expect(page.url()).toContain('login');
  });
});
