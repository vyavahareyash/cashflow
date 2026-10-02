import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { chromium } from 'playwright';

const root = path.resolve('build/web');
const outputBase = path.resolve('screenshots/web');

const VIEWPORTS = {
  mobile: { width: 390, height: 844, name: 'Mobile (390x844)' },
  tablet: { width: 768, height: 1024, name: 'Tablet (768x1024)' },
  desktop: { width: 1440, height: 900, name: 'Desktop (1440x900)' },
};

const MARKERS = [
  // Light Mode
  { id: '01-dashboard-light', route: '/#/dashboard', theme: 'light', name: 'Dashboard Overview' },
  { id: '01b-dashboard-privacy-light', route: '/#/dashboard', theme: 'light', name: 'Dashboard Privacy Mode' },
  { id: '05-budget-light', route: '/#/accounts/budgets', theme: 'light', name: 'Monthly Budgets' },
  { id: '08-goals-light', route: '/#/accounts/sinking-funds', theme: 'light', name: 'Sinking Funds & Goals' },
  { id: '12-accounts-light', route: '/#/accounts', theme: 'light', name: 'My Accounts' },
  { id: '15-activity-ledger-light', route: '/#/ledger', theme: 'light', name: 'Activity Ledger' },
  { id: '16-analytics-trends-light', route: '/#/analytics', theme: 'light', name: 'Spending Analytics' },
  { id: '18-backup-restore-light', route: '/#/settings', theme: 'light', name: 'Settings & Data Backup' },

  // Dark Mode
  { id: '19-dashboard-dark', route: '/#/dashboard', theme: 'dark', name: 'Dashboard Overview (Dark)' },
  { id: '19b-dashboard-privacy-dark', route: '/#/dashboard', theme: 'dark', name: 'Dashboard Privacy Mode (Dark)' },
  { id: '21-budget-dark', route: '/#/accounts/budgets', theme: 'dark', name: 'Monthly Budgets (Dark)' },
  { id: '22-goals-dark', route: '/#/accounts/sinking-funds', theme: 'dark', name: 'Sinking Funds & Goals (Dark)' },
  { id: '24-accounts-dark', route: '/#/accounts', theme: 'dark', name: 'My Accounts (Dark)' },
  { id: '26-activity-ledger-dark', route: '/#/ledger', theme: 'dark', name: 'Activity Ledger (Dark)' },
  { id: '27-analytics-trends-dark', route: '/#/analytics', theme: 'dark', name: 'Spending Analytics (Dark)' },
  { id: '29-backup-restore-dark', route: '/#/settings', theme: 'dark', name: 'Settings & Data Backup (Dark)' },
];

function startStaticServer(port = 8788) {
  const mimeTypes = {
    '.html': 'text/html; charset=utf-8',
    '.js': 'application/javascript; charset=utf-8',
    '.mjs': 'application/javascript; charset=utf-8',
    '.wasm': 'application/wasm',
    '.json': 'application/json; charset=utf-8',
    '.css': 'text/css; charset=utf-8',
    '.png': 'image/png',
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.svg': 'image/svg+xml',
    '.ico': 'image/x-icon',
    '.ttf': 'font/ttf',
    '.otf': 'font/otf',
  };

  const server = http.createServer((req, res) => {
    let filePath = path.join(root, req.url.split('?')[0]);
    if (!fs.existsSync(filePath) || fs.statSync(filePath).isDirectory()) {
      filePath = path.join(filePath, 'index.html');
    }
    if (!fs.existsSync(filePath)) {
      filePath = path.join(root, 'index.html');
    }

    try {
      const data = fs.readFileSync(filePath);
      const ext = path.extname(filePath).toLowerCase();
      res.writeHead(200, {
        'Content-Type': mimeTypes[ext] || 'application/octet-stream',
        'Cross-Origin-Embedder-Policy': 'credentialless',
        'Cross-Origin-Opener-Policy': 'same-origin',
      });
      res.end(data);
    } catch (_) {
      res.writeHead(500);
      res.end('Server error');
    }
  });

  return new Promise((resolve) => {
    server.listen(port, () => resolve(server));
  });
}

async function captureMultiViewportScreenshots() {
  const port = 8788;
  const server = await startStaticServer(port);
  console.log(`Web screenshot server active at http://127.0.0.1:${port}`);

  fs.mkdirSync(outputBase, { recursive: true });

  const browser = await chromium.launch({ headless: true });
  const manifest = {
    generated_at: new Date().toISOString(),
    viewports: Object.keys(VIEWPORTS),
    captures: [],
  };

  try {
    for (const [vpKey, vpConfig] of Object.entries(VIEWPORTS)) {
      console.log(`\n========================================`);
      console.log(`Capturing Viewport: ${vpConfig.name}`);
      console.log(`========================================`);

      const vpDir = path.join(outputBase, vpKey);
      fs.mkdirSync(vpDir, { recursive: true });

      const context = await browser.newContext({
        viewport: { width: vpConfig.width, height: vpConfig.height },
        colorScheme: 'light',
      });

      const page = await context.newPage();
      await page.goto(`http://127.0.0.1:${port}`);
      await page.waitForSelector('flutter-view, flt-glass-pane, canvas', { timeout: 30000 });
      await page.waitForTimeout(2000);

      // Dismiss initial walkthrough dialog and wait for welcome snackbar to fade away
      console.log(`  → Dismissing walkthrough carousel for ${vpKey}...`);
      const isSmall = vpConfig.height < 680;
      const diagH = isSmall ? 430 : 470;
      const diagW = Math.min(420, vpConfig.width - 32);
      const cx = vpConfig.width / 2;
      const diagTop = (vpConfig.height - diagH) / 2;
      const diagRight = cx + (diagW / 2);
      const skipX = diagRight - 36;
      const skipY = diagTop + 24;

      await page.mouse.click(skipX, skipY);
      await page.mouse.click(skipX - 10, skipY);
      await page.mouse.click(skipX + 10, skipY);
      await page.mouse.click(skipX, skipY + 5);
      await page.keyboard.press('Escape');

      console.log(`  → Waiting for welcome snackbar to disappear (5.5s)...`);
      await page.waitForTimeout(5500);

      for (const marker of MARKERS) {
        // Switch theme if dark
        if (marker.theme === 'dark') {
          await page.emulateMedia({ colorScheme: 'dark' });
        } else {
          await page.emulateMedia({ colorScheme: 'light' });
        }

        // Navigate to route
        await page.goto(`http://127.0.0.1:${port}${marker.route}`);
        await page.waitForTimeout(1000);

        const outPath = path.join(vpDir, `${marker.id}.png`);
        await page.screenshot({ path: outPath, fullPage: false });
        console.log(`  ✓ Captured [${vpKey}] ${marker.id} (${vpConfig.width}x${vpConfig.height})`);

        manifest.captures.push({
          viewport: vpKey,
          marker_id: marker.id,
          name: marker.name,
          theme: marker.theme,
          path: `web/${vpKey}/${marker.id}.png`,
        });
      }

      await context.close();
    }

    // Save manifest.json
    fs.writeFileSync(
      path.join(outputBase, 'manifest.json'),
      JSON.stringify(manifest, null, 2),
      'utf8',
    );
    console.log(`\nSaved multi-viewport manifest to ${outputBase}/manifest.json`);

    // Generate review gallery HTML
    generateGalleryHtml(manifest);
  } finally {
    await browser.close();
    server.close();
  }
}

function generateGalleryHtml(manifest) {
  const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Cashflow Web Multi-Viewport Screenshot Gallery</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #0f172a; color: #f8fafc; margin: 0; padding: 24px; }
    h1 { color: #10b981; font-size: 24px; margin-bottom: 8px; }
    p.sub { color: #94a3b8; font-size: 14px; margin-bottom: 24px; }
    .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(360px, 1fr)); gap: 20px; }
    .card { background: #1e293b; border-radius: 12px; overflow: hidden; border: 1px solid #334155; }
    .card img { width: 100%; height: auto; display: block; background: #000; }
    .card-meta { padding: 12px 16px; font-size: 13px; display: flex; justify-content: space-between; align-items: center; }
    .badge { padding: 2px 8px; border-radius: 4px; font-size: 11px; font-weight: 600; text-transform: uppercase; }
    .badge-mobile { background: #3b82f6; color: #fff; }
    .badge-tablet { background: #8b5cf6; color: #fff; }
    .badge-desktop { background: #10b981; color: #fff; }
  </style>
</head>
<body>
  <h1>Cashflow Web Multi-Viewport Gallery</h1>
  <p class="sub">Generated: ${manifest.generated_at} | Total Captures: ${manifest.captures.length}</p>
  <div class="grid">
    ${manifest.captures
      .map(
        (c) => `
      <div class="card">
        <img src="${c.viewport}/${c.marker_id}.png" alt="${c.name}" loading="lazy" />
        <div class="card-meta">
          <span>${c.name}</span>
          <span class="badge badge-${c.viewport}">${c.viewport}</span>
        </div>
      </div>
    `,
      )
      .join('')}
  </div>
</body>
</html>`;

  fs.writeFileSync(path.join(outputBase, 'index.html'), html, 'utf8');
  console.log(`Saved multi-viewport gallery to ${outputBase}/index.html`);
}

captureMultiViewportScreenshots().catch((err) => {
  console.error('Error capturing multi-viewport screenshots:', err);
  process.exit(1);
});
