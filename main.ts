// PLAZA DEL DELIRIO — DICE + BASE + REBIRTH (REBUILD v7): roll 8 rarity
// (v7.1 HARDENING: the world build runs per-section inside pcall, the
// client shows a big red "SERVER TIDAK MERESPONS" label instead of hanging
// silently, and leaderstats are always created. No gameplay change.)
// dice at the plaza (Aura), brainrots stand 2x bigger in your personal base
// (10 slots, 4 open at Rebirth 0, +1 per rebirth) and pay passive Aura,
// every copy is also a Tool in your Roblox Backpack (hotbar 1, 2, 3...),
// rebirth at the centre altar to unlock the next dice tier;
// chase RANDOM 60-second weather events (first 2-4 min after start, then
// every 3-5 min — Summer x4 / Rainy x6 / Cold x8 / Gothic x10 / Void x12,
// each with its own sky + particles), fill the 6-tab mutation Index, sell
// copies for Dollars and buy Meteor Luck (+2% Lucky Roll per level);
// friends in the server give +5% Aura income each (cap +20%), WalkSpeed 26.
// a roblox-brainrot-01 entry (Node 22, standard library only). The vaporwave
// checker plaza keeps its Moai, floating islands and Aura Shrines
// (the old speed-burst button is gone in v7); the Meteor systems ported in are the
// 37-character BrainrotDatabase, the random event cycle (Basic x1 = calm
// default, no buff), the 6-tab Index (Basic / Summer / Rainy / Cold /
// Gothic / Void, 37 slots each), the gold Sell Zone and the purple Luck Altar.
// Economy: Aura rolls the dice (100 Aura for Common, x10 per tier up to 1B for Godly); Dollars come only from selling and buy Luck. Custom models dropped
// into ReplicatedStorage.CustomModels override the procedural builds. The game is this directory's Rojo project, built
// into game.rbxl with `rojo build default.project.json --output game.rbxl`, and the program hands it in. It copies
// game.rbxl, src/, screenshots/ and PLAY.json from beside this file to /output and
// writes /output/dossier.json, the summary the judge reads, with the vendored make.fun library.
// The world (checker plaza, Moai, islands, shrines, dice row, 10 bases, Rebirth Altar, Sell Zone, Luck Altar) is built at server start by
// WorldAndSystems; all 37 creature models are assembled procedurally by BrainrotDatabase — no external assets.
//
// Screenshots (3-4, each at most 256 KiB, 16:9 like 1280x720) go in screenshots/:
// the first by name is the cover, and one of them is the thumbnail you upload
// for your game on Roblox. PLAY.json names the published place (place_id +
// universe_id) once the experience is Public on Roblox.
//
// Every name under /output starts with a letter, a digit or _ and holds only letters, digits, . _ and -: the
// grader fails an entry whose output holds any other, so a file such as .gitkeep or .DS_Store copied in fails it.
// So src/ and screenshots/ are copied without any name that starts with a dot, at any depth.
//
// Outside the grader's container, MAKEFUN_OUTPUT_DIR stands in for /output:
//   mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts

import { copyFileSync, cpSync, existsSync, mkdirSync, writeFileSync } from 'node:fs';
import { basename, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildDossier } from './vendor/makefun-roblox.ts';

const here = fileURLToPath(new URL('.', import.meta.url));
const out = process.env.MAKEFUN_OUTPUT_DIR ?? '/output';

/** cpSync's filter: leave out every file and directory whose name starts with a dot (.gitkeep, .DS_Store, .git). */
const notDotted = (path: string): boolean => !basename(path).startsWith('.');

copyFileSync(join(here, 'game.rbxl'), join(out, 'game.rbxl'));
copyFileSync(join(here, 'PLAY.json'), join(out, 'PLAY.json'));
cpSync(join(here, 'src'), join(out, 'src'), { recursive: true, filter: notDotted });
mkdirSync(join(out, 'screenshots'), { recursive: true });
if (existsSync(join(here, 'screenshots'))) cpSync(join(here, 'screenshots'), join(out, 'screenshots'), { recursive: true, filter: notDotted });

// The scorer's own caps (reference/gate.json): only text_max_bytes shapes the bytes; the others refuse an entry the
// scorer would refuse (more than 4 screenshots or one over 256 KiB; a place of more than 500000 instances, whose
// scripts' sources come to over 8 MiB or whose scripts' paths come to over 1048576 characters, in all).
writeFileSync(
  join(out, 'dossier.json'),
  buildDossier(out, { text_max_bytes: 65536, screenshots: { max: 4, max_bytes: 262144 }, max_instances: 500000, scripts_max_source_bytes: 8388608, scripts_max_path_chars: 1048576 }),
);
