.pragma library

// Pure layout math for the Displays page (logical pixels). A rect is
// { x, y, w, h }. Result positions always touch another monitor along a shared
// edge (positive length) and never overlap one.

function logicalSize(m) {
    let w = m.width / m.scale, h = m.height / m.scale;
    if ((m.transform | 0) % 2 === 1) { const t = w; w = h; h = t; }
    return { w: Math.round(w), h: Math.round(h) };
}

function overlaps(a, b) {
    return a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h;
}

// Share a stretch of edge (not only a corner).
function touches(a, b) {
    const xOverlap = a.x < b.x + b.w && b.x < a.x + a.w;
    const yOverlap = a.y < b.y + b.h && b.y < a.y + a.h;
    return (yOverlap && (a.x + a.w === b.x || b.x + b.w === a.x))
        || (xOverlap && (a.y + a.h === b.y || b.y + b.h === a.y));
}

function candidates(size, others, want) {
    const out = [];
    for (const o of others) {
        for (const y of [want.y, o.y, o.y + o.h - size.h]) {
            out.push({ x: o.x + o.w, y: y, aligned: y !== want.y });
            out.push({ x: o.x - size.w, y: y, aligned: y !== want.y });
        }
        for (const x of [want.x, o.x, o.x + o.w - size.w]) {
            out.push({ x: x, y: o.y + o.h, aligned: x !== want.x });
            out.push({ x: x, y: o.y - size.h, aligned: x !== want.x });
        }
    }
    return out;
}

// Best valid position for a monitor of SIZE wanted at WANT: edges within
// THRESHOLD of an alignment prefer it; always ends touching, never overlapping.
function snap(size, others, want, threshold) {
    if (!others.length) return { x: Math.round(want.x), y: Math.round(want.y) };
    let best = null, bestScore = Infinity;
    for (const c of candidates(size, others, want)) {
        const r = { x: c.x, y: c.y, w: size.w, h: size.h };
        if (others.some(o => overlaps(r, o)) || !others.some(o => touches(r, o))) continue;
        const score = Math.hypot(c.x - want.x, c.y - want.y) - (c.aligned ? threshold : 0);
        if (score < bestScore) { bestScore = score; best = c; }
    }
    return best ? { x: Math.round(best.x), y: Math.round(best.y) } : { x: Math.round(want.x), y: Math.round(want.y) };
}

// Arrow key: the next snapped position in DIR ("left"|"right"|"up"|"down").
function nudge(size, others, cur, dir, threshold) {
    const dx = dir === "left" ? -1 : dir === "right" ? 1 : 0;
    const dy = dir === "up" ? -1 : dir === "down" ? 1 : 0;
    for (let step = 40; step <= 8000; step += 40) {
        const p = snap(size, others, { x: cur.x + dx * step, y: cur.y + dy * step }, threshold);
        if (p.x !== cur.x || p.y !== cur.y) {
            // only accept moves that go in the requested direction
            if ((dx && Math.sign(p.x - cur.x) === dx) || (dy && Math.sign(p.y - cur.y) === dy)) return p;
        }
    }
    return { x: cur.x, y: cur.y };
}

// Shift every position so the top-left-most monitor sits at 0x0.
function normalize(positions) {
    const names = Object.keys(positions);
    if (!names.length) return {};
    const minX = Math.min(...names.map(n => positions[n].x));
    const minY = Math.min(...names.map(n => positions[n].y));
    const out = {};
    for (const n of names) out[n] = { x: positions[n].x - minX, y: positions[n].y - minY };
    return out;
}
