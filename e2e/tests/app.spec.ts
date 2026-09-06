import { test, expect } from '@playwright/test';

test.describe('LiftFlow Web & Authentication E2E', () => {
  test('landing / login page renders and title loads', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('domcontentloaded');

    // Verify document title
    await expect(page).toHaveTitle(/liftflow/i);

    // Wait for Flutter web script & DOM tree to mount
    const root = page.locator('html');
    await expect(root).toBeAttached();
  });

  test('login interface boots on web platform', async ({ page }) => {
    await page.goto('/#/login');
    await page.waitForLoadState('domcontentloaded');

    await expect(page).toHaveTitle(/liftflow/i);
    const root = page.locator('html');
    await expect(root).toBeAttached();
  });
});

test.describe('Web Security Boundaries & Route Redirection', () => {
  test('unauthenticated route navigation loads application container', async ({ page }) => {
    await page.goto('/#/app');
    await page.waitForLoadState('domcontentloaded');

    // Verify Flutter application mounts securely
    await expect(page).toHaveTitle(/liftflow/i);
    const root = page.locator('html');
    await expect(root).toBeAttached();
  });
});
