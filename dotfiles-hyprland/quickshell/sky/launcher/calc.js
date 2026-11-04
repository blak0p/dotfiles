.pragma library

// Inline calculator for the launcher: parses a small arithmetic language
// (no eval) and returns the formatted result, or null when the input is not a
// complete expression. Used by launcher/Launcher.qml.

function normalize(input) {
    var s = String(input === undefined || input === null ? "" : input).trim();
    // A trailing "=" is what people type after an expression; drop it.
    s = s.replace(/=+\s*$/, "").trim();
    // Decimal comma (Spanish keyboard) is the same thing as a decimal point.
    return s.replace(/,/g, ".");
}

function functions() {
    return {
        sqrt: Math.sqrt, cbrt: Math.cbrt, abs: Math.abs, round: Math.round,
        floor: Math.floor, ceil: Math.ceil, sin: Math.sin, cos: Math.cos,
        tan: Math.tan, asin: Math.asin, acos: Math.acos, atan: Math.atan,
        log: function (x) { return Math.log(x) / Math.LN10; },
        ln: Math.log, exp: Math.exp
    };
}

function looksLikeExpression(s) {
    var i;
    for (i = 0; i < s.length; i++)
        if ("+-*/^%()".indexOf(s.charAt(i)) !== -1) return true;
    var m = s.toLowerCase().match(/^[a-z_]+/);
    if (!m) return false;
    return m[0] === "pi" || m[0] === "e" || functions().hasOwnProperty(m[0]);
}

function format(v) {
    if (typeof v !== "number" || !isFinite(v)) return null;
    if (Math.abs(v) < 1e-12) v = 0;
    // Kill floating point noise (0.1 + 0.2).
    var r = Math.round(v * 1e10) / 1e10;
    if (Math.abs(r) >= 1e15) return r.toExponential(6);
    var s = String(r);
    if (s.indexOf("e") !== -1) s = r.toFixed(10).replace(/0+$/, "").replace(/\.$/, "");
    return s;
}

function result(input) {
    var src = normalize(input);
    if (!src || src.length < 2 || src.length > 160) return null;
    if (!looksLikeExpression(src)) return null;

    var i = 0;
    var fns = functions();

    function fail() { throw new Error("calc"); }
    function ws() { while (i < src.length && " \t".indexOf(src.charAt(i)) !== -1) i++; }
    function eat(ch) {
        ws();
        if (src.charAt(i) === ch) { i++; return true; }
        return false;
    }
    function digit() { return /[0-9]/.test(src.charAt(i)); }
    function parseExpr() {
        var v = parseTerm();
        for (;;) {
            if (eat("+")) v += parseTerm();
            else if (eat("-")) v -= parseTerm();
            else return v;
        }
    }
    function parseTerm() {
        var v = parseUnary();
        for (;;) {
            if (eat("*")) v *= parseUnary();
            else if (eat("/")) v /= parseUnary();
            else return v;
        }
    }
    function parseUnary() {
        if (eat("-")) return -parseUnary();
        if (eat("+")) return parseUnary();
        return parsePower();
    }
    function parsePower() {
        var base = parsePostfix();
        if (eat("^")) return Math.pow(base, parseUnary());
        return base;
    }
    function parsePostfix() {
        var v = parsePrimary();
        while (eat("%")) v /= 100;
        return v;
    }
    function parsePrimary() {
        ws();
        if (eat("(")) {
            var inner = parseExpr();
            if (!eat(")")) fail();
            return inner;
        }
        var start = i;
        while (i < src.length && digit()) i++;
        if (src.charAt(i) === ".") {
            i++;
            while (i < src.length && digit()) i++;
        }
        if (i > start) {
            var n = parseFloat(src.substring(start, i));
            if (isNaN(n)) fail();
            return n;
        }
        var s0 = i;
        while (i < src.length && /[a-zA-Z_]/.test(src.charAt(i))) i++;
        if (i === s0) fail();
        var name = src.substring(s0, i).toLowerCase();
        if (name === "pi") return Math.PI;
        if (name === "e") return Math.E;
        if (!fns.hasOwnProperty(name)) fail();
        if (!eat("(")) fail();
        var arg = parseExpr();
        if (!eat(")")) fail();
        return fns[name](arg);
    }

    try {
        var v = parseExpr();
        ws();
        if (i !== src.length) return null;
        var text = format(v);
        if (text === null) return null;
        return { expr: src, value: v, text: text };
    } catch (e) {
        return null;
    }
}
