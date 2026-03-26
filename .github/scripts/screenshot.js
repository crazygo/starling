const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const BASE_URL = 'http://localhost:8080';
const OUTPUT_DIR = 'screenshots';

// The app uses bottom tab navigation (not URL routing).
// We navigate to the root URL and interact with tabs.
const TABS = [
  { name: 'home',     tabIndex: 0, label: '首页' },
  { name: 'explore',  tabIndex: 1, label: '巡天' },
  { name: 'settings', tabIndex: 2, label: '设置' },
];

// Flutter canvas needs extra time after networkidle to finish rendering
const FLUTTER_WAIT_MS = 4000;

async function main() {
  fs.mkdirSync(OUTPUT_DIR, { recursive: true });

  const browser = await chromium.launch();
  const page = await browser.newPage();
  await page.setViewportSize({ width: 390, height: 844 }); // iPhone 14 size

  // Load the app once and wait for Flutter to initialise
  console.log('Loading app...');
  await page.goto(BASE_URL, { waitUntil: 'networkidle' });
  await page.waitForTimeout(FLUTTER_WAIT_MS);

  for (const { name, tabIndex, label } of TABS) {
    console.log(`Screenshotting tab ${tabIndex} (${label}) ...`);

    // Click the bottom navigation item by its position in the bar
    const navItems = await page.locator('flt-semantics[role="tab"]').all();
    if (navItems.length > tabIndex) {
      await navItems[tabIndex].click();
    } else {
      // Fallback: click by pixel position in the bottom nav bar
      const viewportSize = page.viewportSize();
      const barY = viewportSize.height - 30;
      const segmentWidth = viewportSize.width / TABS.length;
      const x = segmentWidth * tabIndex + segmentWidth / 2;
      await page.mouse.click(x, barY);
    }

    await page.waitForTimeout(FLUTTER_WAIT_MS);
    await page.screenshot({
      path: path.join(OUTPUT_DIR, `${name}.png`),
      fullPage: false,
    });
    console.log(`  → saved ${name}.png`);
  }

  await browser.close();
}

main().catch(err => { console.error(err); process.exit(1); });
