// Rebuilds patches/for-web/ from upstream, so the Russian catalog can be
// regenerated after an upstream bump instead of being hand-maintained.
//
//   node scripts/regen-web-catalog.mjs <upstream-checkout> <donor-ref> <extra.json>
//
// <upstream-checkout>  a for-web clone, already at the pinned WEB_TAG
// <donor-ref>          a newer ref whose ru catalog is more complete (e.g. a
//                      later release tag); its translations are copied for any
//                      msgid the pinned revision leaves empty
// <extra.json>         {msgid: msgstr} for whatever the donor does not cover
//
// Placeholders are verified rather than trusted: lingui renders a dropped
// {0} as literal braces at runtime instead of failing the build, so a silent
// mismatch would ship.
import { execFileSync } from "node:child_process";
import { readFileSync, writeFileSync } from "node:fs";

const [, , checkout, donorRef, extraPath] = process.argv;
if (!checkout || !donorRef || !extraPath) {
  console.error("usage: regen-web-catalog.mjs <checkout> <donor-ref> <extra.json>");
  process.exit(2);
}

const CATALOG = "packages/client/components/i18n/catalogs/ru/messages.po";
const git = (...args) =>
  execFileSync("git", ["-C", checkout, ...args], { encoding: "utf8", maxBuffer: 64e6 });

// Read through git rather than the working tree: on Windows the checkout may
// be CRLF, which would make every line of the patch a spurious change.
const target = git("show", `HEAD:${CATALOG}`);
const donor = git("show", `${donorRef}:${CATALOG}`);
const extra = JSON.parse(readFileSync(extraPath, "utf8"));

const parse = (text) =>
  text.split(/\n\n+/).map((raw) => {
    const id = raw.match(/^msgid "((?:[^"\\]|\\.)*)"$/m);
    const str = raw.match(/^msgstr "((?:[^"\\]|\\.)*)"$/m);
    return { raw, id: id?.[1] ?? null, str: str?.[1] ?? null };
  });

const donorMap = new Map(
  parse(donor).filter((e) => e.id && e.str).map((e) => [e.id, e.str]),
);

const holders = (s) => (s.match(/\{[^}]*\}|<\/?\d+>/g) || []).sort().join("|");

let fromDonor = 0, fromExtra = 0;
const empty = [], mismatched = [];

const out = parse(target).map((e) => {
  if (!e.id || e.str !== "") return e.raw;
  const donated = donorMap.get(e.id);
  const manual = extra[e.id];
  const tr = donated ?? manual;
  if (tr === undefined) { empty.push(e.id); return e.raw; }
  if (holders(e.id) !== holders(tr)) mismatched.push(e.id);
  donated !== undefined ? fromDonor++ : fromExtra++;
  return e.raw.replace(/^msgstr ""$/m, `msgstr "${tr.replace(/"/g, '\\"')}"`);
});

if (mismatched.length) {
  console.error("placeholder mismatch in:");
  for (const m of mismatched) console.error("  " + JSON.stringify(m));
  process.exit(1);
}

writeFileSync(`${checkout}/${CATALOG}`, out.join("\n\n").replace(/\n*$/, "\n"));

console.log(`from donor (${donorRef}) : ${fromDonor}`);
console.log(`from ${extraPath}        : ${fromExtra}`);
console.log(`still untranslated       : ${empty.length}`);
for (const m of empty) console.log("  " + JSON.stringify(m));
console.log("\nNow commit in the checkout and run git format-patch -1 -o patches/for-web");
