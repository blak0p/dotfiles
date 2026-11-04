// Tests for launcher/calc.js (the launcher's inline calculator).
// Run: node --test tests/calc.test.mjs
import { readFileSync } from "node:fs";
import test from "node:test";
import assert from "node:assert/strict";

// QML javascript libraries are plain JS plus a `.pragma library` first line,
// which is not valid JS. Strip it and evaluate the source as a module body.
const source = readFileSync(new URL("../launcher/calc.js", import.meta.url), "utf8")
    .replace(/^\.pragma library\s*$/m, "");
const Calc = new Function(`${source}\nreturn { result, format, normalize };`)();

function value(input) {
    const r = Calc.result(input);
    return r ? r.text : null;
}

test("arithmetic with precedence", () => {
    assert.equal(value("2+2"), "4");
    assert.equal(value("2+3*4"), "14");
    assert.equal(value("(2+3)*4"), "20");
    assert.equal(value("10/4"), "2.5");
    assert.equal(value("-3+1"), "-2");
    assert.equal(value("2^10"), "1024");
    assert.equal(value("2^3^2"), "512");
    assert.equal(value("7-2-1"), "4");
});

test("percent is a postfix divisor", () => {
    assert.equal(value("200*15%"), "30");
    assert.equal(value("50%"), "0.5");
});

test("functions and constants", () => {
    assert.equal(value("sqrt(16)+2"), "6");
    assert.equal(value("abs(-7)"), "7");
    assert.equal(value("round(2.6)"), "3");
    assert.equal(value("sqrt(6,25)"), "2.5");
    const pi = Calc.result("pi*2");
    assert.ok(pi && Math.abs(pi.value - Math.PI * 2) < 1e-9);
});

test("decimal comma, trailing equals and spaces", () => {
    assert.equal(value("1,5+2"), "3.5");
    assert.equal(value(" 2 + 2 ="), "4");
    assert.equal(value("0.1+0.2"), "0.3");
});

test("non-expressions return null", () => {
    assert.equal(value(""), null);
    assert.equal(value("   "), null);
    assert.equal(value("2"), null);
    assert.equal(value("firefox"), null);
    assert.equal(value("2+"), null);
    assert.equal(value("(2+2"), null);
    assert.equal(value("foo(2)"), null);
    assert.equal(value("12/0"), null);
    assert.equal(value("2 2"), null);
    assert.equal(value("2..3"), null);
});

test("result carries the expression it evaluated", () => {
    const r = Calc.result(" 3*3 ");
    assert.equal(r.expr, "3*3");
    assert.equal(r.value, 9);
});
