const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage();

  const urls = [
    'http://127.0.0.1:4000/concepts/convertor.html',
    'http://127.0.0.1:4000/concepts/index.html',
    'http://127.0.0.1:4000/concepts/phases.html',
    'http://127.0.0.1:4000/phases/analyze.html',
    'http://127.0.0.1:4000/phases/migrate.html',
    'http://127.0.0.1:4000/advanced/human-checkpoints.html',
    'http://127.0.0.1:4000/convertor-reference/chef.html',
    'http://127.0.0.1:4000/convertor-reference/powershell.html',
    'http://127.0.0.1:4000/convertor-reference/ansible.html',
    'http://127.0.0.1:4000/platform/index.html',
    'http://127.0.0.1:4000/platform/authentication.html',
    'http://127.0.0.1:4000/platform/authorization.html',
    'http://127.0.0.1:4000/platform/mcp-server.html'
  ];

  for (const url of urls) {
    try {
      const name = url.replace('http://127.0.0.1:4000/', '').replace('.html', '').replace(/\//g, '_');
      await page.goto(url, { waitUntil: 'load', timeout: 10000 });
      await page.waitForTimeout(3000);
      await page.screenshot({ path: `/tmp/diagram_${name}.png`, fullPage: true });
      console.log(`Screenshot: ${name}`);
    } catch (error) {
      console.error(`Failed ${url}: ${error.message}`);
    }
  }

  await browser.close();
})();
