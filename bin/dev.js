#!/usr/bin/env node

/**
 * Dev orchestrator
 *
 * Launches sync.js (watch) + Vite dev server as child processes.
 * Displays a clear startup message with the correct URLs.
 * Cleanly kills both processes on SIGINT/SIGTERM.
 *
 * Usage: node bin/dev.js (or npm run dev)
 */

import { spawn } from 'child_process';
import { resolve, dirname } from 'path';
import { config } from 'dotenv';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const ROOT = resolve(__dirname, '..');

config({ path: resolve(ROOT, '.env') });

// ──────────────────────────────────────────────
// Read config from .env
// ──────────────────────────────────────────────
const WP_PORT = process.env.WP_PORT || '8080';
const PMA_PORT = process.env.PMA_PORT || '8081';
const VITE_PORT = '5173';
const WP_HOME = process.env.WP_HOME || `http://localhost:${WP_PORT}`;

// ──────────────────────────────────────────────
// Colors
// ──────────────────────────────────────────────
const BOLD = '\x1b[1m';
const GREEN = '\x1b[32m';
const CYAN = '\x1b[36m';
const DIM = '\x1b[2m';
const NC = '\x1b[0m';

// ──────────────────────────────────────────────
// Track child processes
// ──────────────────────────────────────────────
const children = [];
let shuttingDown = false;

function cleanup() {
  if (shuttingDown) return;
  shuttingDown = true;

  console.log(`\n${DIM}Stopping dev server...${NC}`);

  for (const child of children) {
    try { process.kill(-child.pid, 'SIGTERM'); } catch {}
  }

  // Force kill after 2 seconds
  setTimeout(() => {
    for (const child of children) {
      try { process.kill(-child.pid, 'SIGKILL'); } catch {}
    }
    process.exit(0);
  }, 2000);
}

process.on('SIGINT', cleanup);
process.on('SIGTERM', cleanup);
process.on('exit', () => {
  // Last resort: kill children on exit
  for (const child of children) {
    try { process.kill(-child.pid, 'SIGKILL'); } catch {}
  }
});

// ──────────────────────────────────────────────
// Launch sync.js --watch
// ──────────────────────────────────────────────
const syncProc = spawn('node', [resolve(ROOT, 'bin/sync.js'), '--watch'], {
  cwd: ROOT,
  stdio: ['ignore', 'pipe', 'pipe'],
  detached: true,
});
children.push(syncProc);

syncProc.stdout.on('data', (data) => {
  const line = data.toString().trim();
  if (line) console.log(`${DIM}${line}${NC}`);
});

syncProc.stderr.on('data', (data) => {
  const line = data.toString().trim();
  if (line) console.error(`${DIM}[sync] ${line}${NC}`);
});

syncProc.on('exit', (code) => {
  if (!shuttingDown && code !== 0) {
    console.error(`\n[sync] Process exited with code ${code}`);
    cleanup();
  }
});

// ──────────────────────────────────────────────
// Launch Vite
// ──────────────────────────────────────────────
const viteProc = spawn('npx', ['vite'], {
  cwd: ROOT,
  stdio: ['ignore', 'pipe', 'pipe'],
  detached: true,
});
children.push(viteProc);

let viteReady = false;

viteProc.stdout.on('data', (data) => {
  const line = data.toString().trim();

  // Detect Vite ready message, then show our banner
  if (!viteReady && line.includes('ready in')) {
    viteReady = true;
    showBanner();
    return;
  }

  // Suppress Vite's default URL output (we show our own)
  if (viteReady && (line.includes('Local:') || line.includes('Network:') || line.includes('press h'))) {
    return;
  }

  // Pass through other Vite output (HMR updates, etc.)
  if (viteReady && line) {
    console.log(line);
  }
});

viteProc.stderr.on('data', (data) => {
  const line = data.toString().trim();
  if (line) console.error(line);
});

viteProc.on('exit', (code) => {
  if (!shuttingDown && code !== 0) {
    console.error(`\n[vite] Process exited with code ${code}`);
    cleanup();
  }
});

// ──────────────────────────────────────────────
// Banner
// ──────────────────────────────────────────────
function showBanner() {
  const wpUrl = WP_HOME;
  const viteUrl = `http://localhost:${VITE_PORT}`;
  const pmaUrl = `http://localhost:${PMA_PORT}`;

  console.log('');
  console.log(`${BOLD}╔══════════════════════════════════════════╗${NC}`);
  console.log(`${BOLD}║       Development server ready            ║${NC}`);
  console.log(`${BOLD}╠══════════════════════════════════════════╣${NC}`);
  console.log(`${BOLD}║${NC}  ${GREEN}WordPress${NC} :  ${wpUrl.padEnd(28)}${BOLD}║${NC}`);
  console.log(`${BOLD}║${NC}  ${CYAN}Vite HMR${NC}  :  ${viteUrl.padEnd(28)}${BOLD}║${NC}`);
  console.log(`${BOLD}║${NC}  ${DIM}phpMyAdmin${NC} :  ${pmaUrl.padEnd(28)}${BOLD}║${NC}`);
  console.log(`${BOLD}╚══════════════════════════════════════════╝${NC}`);
  console.log('');
  console.log(`  Ouvrez ${BOLD}${wpUrl}${NC} dans votre navigateur.`);
  console.log(`  Vite gère le HMR (hot reload CSS/JS automatique).`);
  console.log('');
  console.log(`  ${DIM}Ctrl+C pour arrêter Vite. Docker continue en arrière-plan.${NC}`);
  console.log(`  ${DIM}Pour tout stopper : npm run stop${NC}`);
  console.log('');
}
