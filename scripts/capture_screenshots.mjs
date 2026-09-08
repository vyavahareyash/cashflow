import { mkdir, writeFile } from 'node:fs/promises';
import { execFile as nodeExecFile, spawn } from 'node:child_process';
import { promisify } from 'node:util';

const execFile = promisify(nodeExecFile);

const root = new URL('..', import.meta.url).pathname;
const output = `${root}/screenshots`;
const adb = `${process.env.ANDROID_HOME ?? `${process.env.HOME}/Library/Android/sdk`}/platform-tools/adb`;
const device = process.env.ANDROID_DEVICE ?? 'emulator-5554';

await mkdir(output, { recursive: true });

const run = (args) => execFile(adb, ['-s', device, ...args], { encoding: 'buffer' });

async function capture(name) {
    const { stdout } = await run(['exec-out', 'screencap', '-p']);
    await writeFile(`${output}/${name}.png`, stdout);
    console.log(`Saved ${output}/${name}.png`);
}

const drive = spawn('flutter', [
    'drive',
    '--driver=test_driver/integration_test.dart',
    '--target=integration_test/screenshots_test.dart',
    '-d',
    device,
], { cwd: root, stdio: ['inherit', 'pipe', 'pipe'] });
const driveExit = new Promise((resolve) => drive.once('close', resolve));

const markerWaiters = new Map();
const receivedMarkers = new Set();
let driveClosed = false;

function waitForMarker(name) {
    if (receivedMarkers.delete(name)) {
        return Promise.resolve();
    }
    if (driveClosed) {
        return Promise.reject(new Error(`Flutter drive exited before ${name}`));
    }
    return new Promise((resolve, reject) => {
        markerWaiters.set(name, { resolve, reject });
        setTimeout(() => {
            const waiter = markerWaiters.get(name);
            if (!waiter) return;
            markerWaiters.delete(name);
            reject(new Error(`Timed out waiting for screenshot marker: ${name}`));
        }, 30000).unref();
    });
}

function handleOutput(chunk) {
    const text = chunk.toString();
    process.stdout.write(text);
    for (const match of text.matchAll(/SCREENSHOT_MARKER:([^\s\r\n]+)/g)) {
        const name = match[1];
        const waiter = markerWaiters.get(name);
        if (waiter) {
            waiter.resolve();
            markerWaiters.delete(name);
        } else {
            receivedMarkers.add(name);
        }
    }
}

drive.stdout.on('data', handleOutput);
drive.stderr.on('data', (chunk) => process.stderr.write(chunk));
drive.on('close', () => {
    driveClosed = true;
    for (const { reject } of markerWaiters.values()) {
        reject(new Error('Flutter drive exited before all screenshots were captured'));
    }
    markerWaiters.clear();
});

// Flutter emits each marker only after its semantic title finder succeeds.
for (const name of [
    '01-dashboard',
    '02-budget',
    '03-goals',
    '04-accounts',
    '05-analytics',
    '06-analytics-trends',
    '07-backup-restore',
]) {
    await waitForMarker(name);
    await capture(name);
}

const exitCode = await driveExit;
if (exitCode !== 0) process.exit(exitCode ?? 1);
