import { spawn } from 'node:child_process';
import { mkdtemp, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const [browser, url, output, debugPort, expression] = process.argv.slice(2);

if (!browser || !url || !output || !debugPort) {
  throw new Error('Expected: browser URL output debug-port');
}

const delay = (milliseconds) =>
  new Promise((resolve) => setTimeout(resolve, milliseconds));

async function fetchJson(url) {
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`Could not connect to Chromium (${response.status}).`);
  }
  return response.json();
}

async function waitForTarget(port) {
  for (let attempt = 0; attempt < 50; attempt += 1) {
    try {
      const targets = await fetchJson(`http://127.0.0.1:${port}/json`);
      const page = targets.find((target) => target.type === 'page');
      if (page) {
        return page;
      }
    } catch (_) {
      // Chromium has not opened its DevTools endpoint yet.
    }
    await delay(100);
  }
  throw new Error('Timed out waiting for Chromium DevTools.');
}

async function main() {
  const profileDir = await mkdtemp(join(tmpdir(), 'pcalc-chromium-'));
  const chrome = spawn(browser, [
    '--headless',
    '--enable-unsafe-swiftshader',
    '--use-gl=angle',
    '--use-angle=swiftshader',
    '--hide-scrollbars',
    '--window-size=393,852',
    `--remote-debugging-port=${debugPort}`,
    `--user-data-dir=${profileDir}`,
    'about:blank',
  ]);
  const chromeExited = new Promise((resolve) => {
    chrome.once('exit', resolve);
  });

  try {
    const target = await waitForTarget(debugPort);
    const socket = new WebSocket(target.webSocketDebuggerUrl);
    await new Promise((resolve, reject) => {
      socket.addEventListener('open', resolve, { once: true });
      socket.addEventListener('error', reject, { once: true });
    });

    let nextId = 0;
    const call = (method, params = {}) => new Promise((resolve, reject) => {
      const id = ++nextId;
      const listener = (event) => {
        const message = JSON.parse(event.data);
        if (message.id !== id) {
          return;
        }
        socket.removeEventListener('message', listener);
        if (message.error) {
          reject(new Error(message.error.message));
        } else {
          resolve(message.result);
        }
      };
      socket.addEventListener('message', listener);
      socket.send(JSON.stringify({ id, method, params }));
    });

    await call('Page.enable');
    await call('Runtime.enable');
    await call('Page.navigate', { url });
    await call('Runtime.evaluate', {
      expression: 'document.fonts.ready',
      awaitPromise: true,
    });
    await delay(15000);
    if (expression) {
      // The calculator focuses its expression field on startup.
      await call('Input.insertText', { text: expression });
      await call('Input.dispatchKeyEvent', {
        type: 'keyDown', key: 'Enter', code: 'Enter',
        windowsVirtualKeyCode: 13, nativeVirtualKeyCode: 13,
      });
      await call('Input.dispatchKeyEvent', {
        type: 'keyUp', key: 'Enter', code: 'Enter',
        windowsVirtualKeyCode: 13, nativeVirtualKeyCode: 13,
      });
      await delay(2000);
    }
    const screenshot = await call('Page.captureScreenshot', { format: 'png' });
    await writeFile(output, Buffer.from(screenshot.data, 'base64'));
    socket.close();
  } finally {
    chrome.kill();
    await chromeExited;
    await rm(profileDir, {
      recursive: true,
      force: true,
      maxRetries: 5,
      retryDelay: 100,
    });
  }
}

await main();
