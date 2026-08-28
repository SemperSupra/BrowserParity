const { test, expect, chromium } = require('@playwright/test');
const fs = require('node:fs');
const http = require('node:http');
const os = require('node:os');
const path = require('node:path');

const PROBE_NAME = 'BrowserParity VM Playwright Probe';

function probeUserscript() {
  return `// ==UserScript==\n// @name        ${PROBE_NAME}\n// @namespace   https://github.com/SemperSupra/BrowserParity/issues/2\n// @version     0.0.1\n// @description Public disposable probe for BrowserParity issue #2\n// @match       http://127.0.0.1/*\n// @run-at      document-end\n// @grant       GM_addStyle\n// ==/UserScript==\n\n(() => {\n  document.documentElement.dataset.vmPlaywrightProbe = 'executed';\n  GM_addStyle('#probe-target { outline: 7px solid rgb(1, 2, 3) !important; }');\n})();\n`;
}

async function startFixtureServer() {
  const server = http.createServer((req, res) => {
    if (req.url === '/probe.user.js') {
      res.writeHead(200, {
        'content-type': 'application/javascript; charset=utf-8',
        'cache-control': 'no-store',
      });
      res.end(probeUserscript());
      return;
    }
    if (req.url === '/fixture') {
      res.writeHead(200, {
        'content-type': 'text/html; charset=utf-8',
        'cache-control': 'no-store',
      });
      res.end('<!doctype html><html><head><title>VM probe fixture</title></head><body><div id="probe-target">probe target</div></body></html>');
      return;
    }
    res.writeHead(404, { 'content-type': 'text/plain; charset=utf-8' });
    res.end('not found');
  });

  await new Promise((resolve, reject) => {
    server.once('error', reject);
    server.listen(0, '127.0.0.1', resolve);
  });
  const address = server.address();
  return {
    server,
    baseUrl: `http://127.0.0.1:${address.port}`,
  };
}

async function snapshotPages(context) {
  if (!context) return [];
  return Promise.all(context.pages().map(async (page) => ({
    url: page.url(),
    title: await page.title().catch(() => ''),
    body: (await page.locator('body').innerText().catch(() => '')).slice(0, 2000),
  })));
}

async function findProbeInstallPage(context, extensionId, timeoutMs = 12_000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    for (const page of context.pages()) {
      if (!page.url().startsWith(`chrome-extension://${extensionId}/`)) continue;
      const text = await page.locator('body').innerText().catch(() => '');
      if (text.includes(PROBE_NAME)) return page;
    }
    await new Promise(resolve => setTimeout(resolve, 250));
  }
  return null;
}

test('real Violentmonkey can install and execute a public probe in headless Chromium', async ({}, testInfo) => {
  const extensionPath = process.env.VM_EXTENSION_PATH;
  expect(extensionPath, 'VM_EXTENSION_PATH must point at the built unpacked Violentmonkey extension').toBeTruthy();
  expect(fs.existsSync(path.join(extensionPath, 'manifest.json')), 'Violentmonkey manifest.json must exist').toBeTruthy();

  fs.mkdirSync('artifacts', { recursive: true });
  const evidence = {
    schemaVersion: 1,
    experiment: 'BrowserParity#2',
    playwrightVersion: require('@playwright/test/package.json').version,
    violentmonkeyRevision: process.env.VM_REVISION || null,
    extensionPath,
    rungs: {
      extensionLoaded: false,
      installIntercepted: false,
      installCompleted: false,
      probeExecuted: false,
      gmAddStyleObserved: false,
    },
  };

  const { server, baseUrl } = await startFixtureServer();
  const userDataDir = fs.mkdtempSync(path.join(os.tmpdir(), 'browserparity-vm-probe-'));
  let context;

  try {
    context = await chromium.launchPersistentContext(userDataDir, {
      channel: 'chromium',
      headless: true,
      args: [
        `--disable-extensions-except=${extensionPath}`,
        `--load-extension=${extensionPath}`,
      ],
    });

    let serviceWorker = context.serviceWorkers().find(worker => worker.url().startsWith('chrome-extension://'));
    if (!serviceWorker) {
      serviceWorker = await context.waitForEvent('serviceworker', { timeout: 15_000 });
    }
    evidence.serviceWorkerUrl = serviceWorker.url();
    const extensionId = new URL(serviceWorker.url()).host;
    evidence.extensionId = extensionId;
    evidence.rungs.extensionLoaded = true;

    const navigationPage = await context.newPage();
    const userscriptUrl = `${baseUrl}/probe.user.js`;
    evidence.userscriptUrl = userscriptUrl;

    try {
      await navigationPage.goto(userscriptUrl, { waitUntil: 'domcontentloaded', timeout: 15_000 });
    } catch (error) {
      evidence.userscriptNavigationError = String(error);
    }

    const installPage = await findProbeInstallPage(context, extensionId);
    evidence.pagesAfterUserscriptNavigation = await snapshotPages(context);
    expect(installPage, 'Violentmonkey should own a visible installation page containing the probe name').not.toBeNull();
    evidence.installPageUrl = installPage.url();
    evidence.rungs.installIntercepted = true;

    const buttons = await installPage.getByRole('button').allTextContents().catch(() => []);
    evidence.installPageButtons = buttons;
    const installButton = installPage.getByRole('button', { name: /install/i }).first();
    await expect(installButton, `Expected an ordinary visible Install button; observed buttons: ${JSON.stringify(buttons)}`).toBeVisible();
    await installButton.click();
    evidence.rungs.installCompleted = true;

    const fixturePage = await context.newPage();
    await fixturePage.goto(`${baseUrl}/fixture`, { waitUntil: 'domcontentloaded' });
    await expect.poll(
      () => fixturePage.locator('html').getAttribute('data-vm-playwright-probe'),
      { message: 'The probe should execute through Violentmonkey on the controlled fixture' },
    ).toBe('executed');
    evidence.rungs.probeExecuted = true;

    const outlineWidth = await fixturePage.locator('#probe-target').evaluate(el => getComputedStyle(el).outlineWidth);
    evidence.outlineWidth = outlineWidth;
    expect(outlineWidth).toBe('7px');
    evidence.rungs.gmAddStyleObserved = true;
  } finally {
    evidence.finalPages = await snapshotPages(context);
    fs.writeFileSync('artifacts/evidence.json', `${JSON.stringify(evidence, null, 2)}\n`);
    await testInfo.attach('experiment-evidence', {
      path: 'artifacts/evidence.json',
      contentType: 'application/json',
    }).catch(() => {});
    if (context) await context.close().catch(() => {});
    await new Promise(resolve => server.close(resolve));
    fs.rmSync(userDataDir, { recursive: true, force: true });
  }
});
