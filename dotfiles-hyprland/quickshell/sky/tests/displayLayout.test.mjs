// Tests for settings/displayLayout.js. Run: node --test tests/displayLayout.test.mjs
import { readFileSync } from "node:fs";
import test from "node:test";
import assert from "node:assert/strict";

const source = readFileSync(new URL("../settings/displayLayout.js", import.meta.url), "utf8")
    .replace(/^\.pragma library\s*$/m, "");
const L = new Function(`${source}\nreturn { logicalSize, overlaps, touches, snap, nudge, normalize };`)();

const A = { x: 0, y: 0, w: 1920, h: 1080 };
const B = { x: 1920, y: 0, w: 2560, h: 1440 };

test("logical size divides by scale and swaps for odd transforms", () => {
    assert.deepEqual(L.logicalSize({ width: 2560, height: 1440, scale: 1.25, transform: 0 }), { w: 2048, h: 1152 });
    assert.deepEqual(L.logicalSize({ width: 1920, height: 1080, scale: 1, transform: 1 }), { w: 1080, h: 1920 });
    assert.deepEqual(L.logicalSize({ width: 1920, height: 1080, scale: 1, transform: 2 }), { w: 1920, h: 1080 });
});

test("snaps to the right edge and aligns the top within the threshold", () => {
    const p = L.snap({ w: 2560, h: 1440 }, [A], { x: 1950, y: 20 }, 60);
    assert.deepEqual(p, { x: 1920, y: 0 });
});

test("snaps below and aligns left edge", () => {
    const p = L.snap({ w: 2560, h: 1440 }, [A], { x: -30, y: 1100 }, 60);
    assert.deepEqual(p, { x: 0, y: 1080 });
});

test("keeps a free offset when no alignment is near", () => {
    const p = L.snap({ w: 2560, h: 1440 }, [A], { x: 1925, y: 400 }, 60);
    assert.deepEqual(p, { x: 1920, y: 400 });
});

test("never overlaps and never leaves a gap, even dropped inside or far away", () => {
    for (const want of [{ x: 500, y: 300 }, { x: 9000, y: 9000 }, { x: -5000, y: 10 }, { x: 1000, y: 1070 }]) {
        const size = { w: 2560, h: 1440 };
        const p = L.snap(size, [A], want, 60);
        const r = { ...p, ...size };
        assert.ok(!L.overlaps(r, A), JSON.stringify(want));
        assert.ok(L.touches(r, A), JSON.stringify(want));
    }
});

test("with two others it avoids the occupied one", () => {
    const p = L.snap({ w: 1000, h: 800 }, [A, B], { x: 2000, y: 100 }, 60);
    const r = { ...p, w: 1000, h: 800 };
    assert.ok(!L.overlaps(r, A) && !L.overlaps(r, B));
    assert.ok(L.touches(r, A) || L.touches(r, B));
});

test("corner-only contact is not accepted", () => {
    assert.ok(!L.touches({ x: 1920, y: 1080, w: 100, h: 100 }, A));
});

test("arrow keys jump to the next edge", () => {
    const size = { w: 2560, h: 1440 };
    const right = L.nudge(size, [A], { x: 1920, y: 0 }, "down", 60);
    assert.ok(right.y > 0);
    const left = L.nudge({ w: 1920, h: 1080 }, [B], { x: 0, y: 0 }, "right", 60);
    assert.ok(left.x > 0);
    const r = { ...left, w: 1920, h: 1080 };
    assert.ok(!L.overlaps(r, B) && L.touches(r, B));
});

test("normalize puts the top-left-most monitor at 0x0", () => {
    assert.deepEqual(L.normalize({ a: { x: -1920, y: 100 }, b: { x: 0, y: 40 } }),
        { a: { x: 0, y: 60 }, b: { x: 1920, y: 0 } });
});
