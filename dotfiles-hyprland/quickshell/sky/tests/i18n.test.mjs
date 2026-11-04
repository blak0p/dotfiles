// Tests for i18n.js (UI string translation for the sky shell).
// Run: node --test tests/i18n.test.mjs
import { readFileSync } from "node:fs";
import test from "node:test";
import assert from "node:assert/strict";

const source = readFileSync(new URL("../i18n.js", import.meta.url), "utf8")
    .replace(/^\.pragma library\s*$/m, "");
const I18n = new Function(`${source}\nreturn { resolve, t, es };`)();

test("auto follows the system locale", () => {
    assert.equal(I18n.resolve("auto", "es_ES.UTF-8"), "es");
    assert.equal(I18n.resolve("auto", "en_US.UTF-8"), "en");
    assert.equal(I18n.resolve("auto", ""), "en");
    assert.equal(I18n.resolve(undefined, undefined), "en");
});

test("an explicit language wins over the locale", () => {
    assert.equal(I18n.resolve("en", "es_ES.UTF-8"), "en");
    assert.equal(I18n.resolve("es", "en_US.UTF-8"), "es");
    assert.equal(I18n.resolve("fr", "es_ES.UTF-8"), "en");
});

test("English keeps the original text", () => {
    assert.equal(I18n.t("en", "No results"), "No results");
    assert.equal(I18n.t("en", "%1 notifs", [3]), "3 notifs");
});

test("Spanish (Spain) translates known strings and fills arguments", () => {
    assert.equal(I18n.t("es", "No results"), "Sin resultados");
    assert.equal(I18n.t("es", "Shut down"), "Apagar");
    assert.equal(I18n.t("es", "%1 notifs", [3]), "3 notificaciones");
    assert.equal(I18n.t("es", "Update (%1)", [5]), "Actualizar (5)");
});

test("unknown strings fall back to English", () => {
    assert.equal(I18n.t("es", "Not in the table"), "Not in the table");
});

test("every Spanish entry keeps the placeholders of its English key", () => {
    for (const [en, es] of Object.entries(I18n.es)) {
        const ph = s => (s.match(/%\d/g) || []).sort().join();
        assert.equal(ph(es), ph(en), en);
    }
});
