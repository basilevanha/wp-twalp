#!/usr/bin/env node

/**
 * Dev orchestrator
 *
 * Launches sync.js (watch) + Vite dev server as child processes.
 * Displays a clear startup message with the correct URLs.
 * Cleanly kills both processes on SIGINT/SIGTERM.
 * Auto-starts Docker containers if needed.
 * Detects actual Vite port (fallback if 5173 is busy).
 *
 * Usage: node bin/dev.js (or npm run dev)
 */

import { spawn, execSync } from "child_process";
import { resolve, dirname } from "path";
import { config } from "dotenv";
import { fileURLToPath } from "url";
import { existsSync, writeFileSync, unlinkSync, mkdirSync } from "fs";

// ──────────────────────────────────────────────
// Detect package manager (same approach as create-next-app / create-vite)
// Priority: npm_config_user_agent → lock file → npm
// ──────────────────────────────────────────────
function detectPM() {
    const ua = process.env.npm_config_user_agent || "";
    if (ua.startsWith("pnpm")) return { name: "pnpm", exec: "pnpm", execArgs: ["exec", "vite"] };
    if (ua.startsWith("yarn")) return { name: "yarn", exec: "yarn", execArgs: ["exec", "vite"] };
    if (ua.startsWith("bun"))  return { name: "bun", exec: "bunx", execArgs: ["vite"] };
    if (ua.startsWith("npm"))  return { name: "npm", exec: "npx", execArgs: ["vite"] };

    // Fallback: lock file detection
    const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
    if (existsSync(resolve(root, "pnpm-lock.yaml"))) return { name: "pnpm", exec: "pnpm", execArgs: ["exec", "vite"] };
    if (existsSync(resolve(root, "yarn.lock"))) return { name: "yarn", exec: "yarn", execArgs: ["exec", "vite"] };
    if (existsSync(resolve(root, "bun.lockb")) || existsSync(resolve(root, "bun.lock"))) return { name: "bun", exec: "bunx", execArgs: ["vite"] };
    return { name: "npm", exec: "npx", execArgs: ["vite"] };
}

const PM = detectPM();

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const ROOT = resolve(__dirname, "..");

// ──────────────────────────────────────────────
// Check .env exists
// ──────────────────────────────────────────────
if (!existsSync(resolve(ROOT, ".env"))) {
    console.error(`\n\x1b[31mError: .env file not found. Run "${PM} run setup" first.\x1b[0m\n`);
    process.exit(1);
}

config({ path: resolve(ROOT, ".env") });

// ──────────────────────────────────────────────
// Read config from .env
// ──────────────────────────────────────────────
const WP_PORT = process.env.WP_PORT || "8080";
const PMA_PORT = process.env.PMA_PORT || "8081";
let vitePort = "5173"; // will be updated once Vite reports its actual port
const WP_HOME = process.env.WP_HOME || `http://localhost:${WP_PORT}`;
const THEME_DIR = resolve(ROOT, process.env.THEME_DIR || "./public/wp-content/themes/starter-theme");

const DOCKER_COMPOSE = `docker compose -f ${resolve(ROOT, "docker/docker-compose.yml")} --env-file ${resolve(ROOT, ".env")}`;

// ──────────────────────────────────────────────
// Colors
// ──────────────────────────────────────────────
const BOLD = "\x1b[1m";
const GREEN = "\x1b[32m";
const CYAN = "\x1b[36m";
const DIM = "\x1b[2m";
const YELLOW = "\x1b[33m";
const RED = "\x1b[31m";
const NC = "\x1b[0m";

// ──────────────────────────────────────────────
// Docker helpers
// ──────────────────────────────────────────────
function isDockerProject() {
    return !!process.env.VENDOR_PATH;
}

function areContainersRunning() {
    try {
        const output = execSync(`${DOCKER_COMPOSE} ps --status running -q`, {
            encoding: "utf-8",
            stdio: ["pipe", "pipe", "pipe"],
        });
        return output.trim().length > 0;
    } catch {
        return false;
    }
}

async function ensureDocker() {
    if (!isDockerProject()) return;

    if (areContainersRunning()) {
        console.log(`${GREEN}✔${NC}  Docker containers already running`);
        return;
    }

    console.log(`${CYAN}ℹ${NC}  Starting Docker containers...`);
    try {
        execSync(`${DOCKER_COMPOSE} up -d`, {
            cwd: ROOT,
            stdio: "inherit",
        });
        console.log(`${GREEN}✔${NC}  Docker containers started`);
    } catch {
        console.error(`\n${RED}Error: Failed to start Docker containers. Is Docker running?${NC}\n`);
        process.exit(1);
    }

    // Wait for WordPress to be ready (max 30s)
    console.log(`${DIM}Waiting for WordPress...${NC}`);
    for (let i = 0; i < 30; i += 2) {
        try {
            execSync(`curl -s -o /dev/null -w "%{http_code}" http://localhost:${WP_PORT} | grep -qE "200|302"`, {
                stdio: "pipe",
            });
            console.log(`${GREEN}✔${NC}  WordPress is ready`);
            return;
        } catch {
            await new Promise((r) => setTimeout(r, 2000));
        }
    }
    console.log(`${YELLOW}⚠${NC}  WordPress may still be starting up...`);
}

// ──────────────────────────────────────────────
// Hot file helpers
// ──────────────────────────────────────────────
function writeHotFile(port) {
    const distDir = resolve(THEME_DIR, "dist");
    if (!existsSync(distDir)) {
        mkdirSync(distDir, { recursive: true });
    }
    writeFileSync(resolve(distDir, "hot"), `http://localhost:${port}`);
}

function removeHotFile() {
    try {
        unlinkSync(resolve(THEME_DIR, "dist/hot"));
    } catch {}
}

// ──────────────────────────────────────────────
// Track child processes
// ──────────────────────────────────────────────
const children = [];
let shuttingDown = false;

function cleanup() {
    if (shuttingDown) return;
    shuttingDown = true;

    console.log(`\n${DIM}Stopping dev server...${NC}`);

    removeHotFile();

    for (const child of children) {
        try {
            process.kill(-child.pid, "SIGTERM");
        } catch {}
    }

    // Force kill after 2 seconds
    setTimeout(() => {
        for (const child of children) {
            try {
                process.kill(-child.pid, "SIGKILL");
            } catch {}
        }
        process.exit(0);
    }, 2000);
}

process.on("SIGINT", cleanup);
process.on("SIGTERM", cleanup);
process.on("exit", () => {
    for (const child of children) {
        try {
            process.kill(-child.pid, "SIGKILL");
        } catch {}
    }
});

// ──────────────────────────────────────────────
// Ensure Docker is running (if Docker project)
// ──────────────────────────────────────────────
await ensureDocker();

// ──────────────────────────────────────────────
// Launch sync.js --watch
// ──────────────────────────────────────────────
const syncProc = spawn("node", [resolve(ROOT, "bin/sync.js"), "--watch"], {
    cwd: ROOT,
    stdio: ["ignore", "pipe", "pipe"],
    detached: true,
});
children.push(syncProc);

syncProc.stdout.on("data", (data) => {
    const line = data.toString().trim();
    if (line) console.log(`${DIM}${line}${NC}`);
});

syncProc.stderr.on("data", (data) => {
    const line = data.toString().trim();
    if (line) console.error(`${DIM}[sync] ${line}${NC}`);
});

syncProc.on("exit", (code) => {
    if (!shuttingDown && code !== 0) {
        console.error(`\n[sync] Process exited with code ${code}`);
        cleanup();
    }
});

// ──────────────────────────────────────────────
// Launch Vite
// ──────────────────────────────────────────────
const viteProc = spawn(PM.exec, PM.execArgs, {
    cwd: ROOT,
    stdio: ["ignore", "pipe", "pipe"],
    detached: true,
});
children.push(viteProc);

let viteReady = false;
let bannerShown = false;

viteProc.stdout.on("data", (data) => {
    const lines = data.toString().split("\n");
    for (const rawLine of lines) {
        const line = rawLine.trim();
        if (!line) continue;

        // Detect actual Vite port from its output (comes after "ready in")
        const localMatch = line.match(/Local:\s+http:\/\/localhost:(\d+)/);
        if (localMatch) {
            vitePort = localMatch[1];
            writeHotFile(vitePort);
            // Now we have the port — show banner if Vite was already ready
            if (viteReady && !bannerShown) {
                bannerShown = true;
                showBanner();
            }
            continue;
        }

        // Detect Vite ready message
        if (!viteReady && line.includes("ready in")) {
            viteReady = true;
            // Don't show banner yet — wait for "Local:" line to get the port
            continue;
        }

        // Suppress Vite's default URL output (we show our own)
        if (viteReady && (line.includes("Network:") || line.includes("press h"))) {
            continue;
        }

        // Pass through other Vite output (HMR updates, etc.)
        if (bannerShown && line) {
            console.log(line);
        }
    }
});

viteProc.stderr.on("data", (data) => {
    const line = data.toString().trim();
    if (line) console.error(line);
});

viteProc.on("exit", (code) => {
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
    const viteUrl = `http://localhost:${vitePort}`;
    const pmaUrl = `http://localhost:${PMA_PORT}`;

    console.log("");
    console.log(`${BOLD}╔══════════════════════════════════════════╗${NC}`);
    console.log(`${BOLD}║       Development server ready           ║${NC}`);
    console.log(`${BOLD}╠══════════════════════════════════════════╣${NC}`);
    console.log(`${BOLD}║${NC}  ${GREEN}WordPress${NC} :  ${wpUrl.padEnd(27)}${BOLD}║${NC}`);
    console.log(`${BOLD}║${NC}  ${CYAN}Vite HMR${NC}  :  ${viteUrl.padEnd(27)}${BOLD}║${NC}`);
    console.log(`${BOLD}║${NC}  ${DIM}phpMyAdmin${NC} :  ${pmaUrl.padEnd(26)}${BOLD}║${NC}`);
    console.log(`${BOLD}╚══════════════════════════════════════════╝${NC}`);
    console.log("");
    console.log(`  Ouvrez ${BOLD}${wpUrl}${NC} dans votre navigateur.`);
    console.log(`  Vite gère le HMR (hot reload CSS/JS automatique).`);
    if (vitePort !== "5173") {
        console.log(`  ${YELLOW}Note: port 5173 occupé, Vite utilise le port ${vitePort}.${NC}`);
    }
    console.log("");
    console.log(`  ${DIM}Ctrl+C pour arrêter Vite. Docker continue en arrière-plan.${NC}`);
    console.log(`  ${DIM}Pour tout stopper : ${PM} run stop${NC}`);
    console.log("");
}
