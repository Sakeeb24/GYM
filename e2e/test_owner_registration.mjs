import { chromium } from '@playwright/test';

async function run() {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext();
  const page = await context.newPage();

  page.on('console', msg => console.log('[BROWSER CONSOLE]', msg.type(), msg.text()));
  page.on('pageerror', err => console.log('[BROWSER PAGEERROR]', err.message));
  page.on('requestfailed', req => console.log('[REQUEST FAILED]', req.method(), req.url(), req.failure()?.errorText));
  page.on('request', req => {
    if (req.url().includes('supabase') || req.url().includes('functions')) {
      console.log('[SUPABASE REQUEST]', req.method(), req.url(), JSON.stringify(req.headers()));
    }
  });
  page.on('response', res => {
    if (res.url().includes('supabase') || res.url().includes('functions')) {
      console.log('[SUPABASE RESPONSE]', res.status(), res.url(), JSON.stringify(res.headers()));
    }
  });

  console.log('Navigating to owner register page...');
  await page.goto('https://sakeeb24.github.io/GYM/#/owner-register');
  await page.waitForTimeout(4000);

  // Take screenshot before interaction
  await page.screenshot({ path: 'e2e_owner_register_initial.png' });

  // Find all inputs
  const inputs = await page.locator('input').all();
  console.log('Found semantic inputs:', inputs.length);
  for (let i = 0; i < inputs.length; i++) {
    const placeholder = await inputs[i].getAttribute('placeholder');
    const ariaLabel = await inputs[i].getAttribute('aria-label');
    console.log(`Input ${i}: ${ariaLabel || placeholder || '(no label)'}`);
  }

  // Click on the canvas center to focus or interact
  await page.mouse.click(600, 400);
  await page.waitForTimeout(1000);

  await page.screenshot({ path: 'e2e_owner_register_after_click.png' });
  console.log('Diagnostic screenshots saved.');

  await browser.close();
}

run().catch(err => console.error(err));
