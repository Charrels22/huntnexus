// Topic 5 browser QA uses only synthetic credentials and intercepted Auth calls.
import assert from "node:assert/strict";
import { chromium } from "playwright";
import { mkdir } from "node:fs/promises";
import { resolve } from "node:path";

const baseUrl = process.env.HUNTNEXUS_BASE_URL || "http://127.0.0.1:4173";
const screenshotDir = resolve("topic05-browser-qa");
await mkdir(screenshotDir, { recursive: true });
const browser = await chromium.launch({ headless: true });
const syntheticUserId = "11111111-1111-4111-8111-111111111111";
const syntheticSessionId = "22222222-2222-4222-8222-222222222222";
const syntheticClientId = "33333333-3333-4333-8333-333333333333";
const syntheticFactor = {
  id: "44444444-4444-4444-8444-444444444444",
  factor_type: "totp",
  status: "verified",
  friendly_name: "SYNTHETIC authenticator",
  created_at: new Date(0).toISOString(),
  updated_at: new Date(0).toISOString(),
};
const encodeJwtPart = (value) => Buffer.from(JSON.stringify(value)).toString("base64url");
const syntheticAccessToken = `${encodeJwtPart({ alg: "HS256", typ: "JWT" })}.${encodeJwtPart({
  sub: syntheticUserId,
  role: "authenticated",
  aud: "authenticated",
  exp: Math.floor(Date.now() / 1000) + 3600,
  iat: Math.floor(Date.now() / 1000),
  aal: "aal2",
  session_id: syntheticSessionId,
  amr: [{ method: "password", timestamp: Math.floor(Date.now() / 1000) }, { method: "totp", timestamp: Math.floor(Date.now() / 1000) }],
})}.synthetic-signature`;
const syntheticUser = {
  id: syntheticUserId,
  aud: "authenticated",
  role: "authenticated",
  email: "synthetic@example.invalid",
  email_confirmed_at: new Date(0).toISOString(),
  phone: "",
  confirmed_at: new Date(0).toISOString(),
  last_sign_in_at: new Date(0).toISOString(),
  app_metadata: { provider: "email", providers: ["email"] },
  user_metadata: {},
  identities: [],
  factors: [syntheticFactor],
  created_at: new Date(0).toISOString(),
  updated_at: new Date(0).toISOString(),
  is_anonymous: false,
};
let authenticatedApiRequests = 0;

async function configureSyntheticAuthenticatedContext(context) {
  await context.addInitScript(({ accessToken, user, clientId }) => {
    localStorage.setItem("sb-urbncbjapasnjqjqicjv-auth-token", JSON.stringify({
      access_token: accessToken,
      token_type: "bearer",
      expires_in: 3600,
      expires_at: Math.floor(Date.now() / 1000) + 3600,
      refresh_token: "SYNTHETIC-refresh-token",
      user,
    }));
    localStorage.setItem("huntnexus.client-id.v1", clientId);
  }, { accessToken: syntheticAccessToken, user: syntheticUser, clientId: syntheticClientId });
}

async function interceptSyntheticAuthenticatedCalls(page) {
  await page.route("**/auth/v1/user", async (route) => {
    if (route.request().method() === "PUT") {
      await route.fulfill({ status: 400, headers: { "Content-Type": "application/json", "X-Supabase-Api-Version": "2024-01-01" }, body: JSON.stringify({ code: "reauthentication_needed", error_code: "reauthentication_needed", message: "SYNTHETIC reauthentication required", msg: "SYNTHETIC reauthentication required" }) });
    } else {
      await route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify(syntheticUser) });
    }
  });
  await page.route("**/auth/v1/reauthenticate", (route) => route.fulfill({ status: 200, contentType: "application/json", body: "{}" }));
  await page.route("**/api/huntnexus", async (route) => {
    const request = route.request();
    const headers = await request.allHeaders();
    const requestBody = request.postDataJSON();
    assert.equal(headers.authorization, `Bearer ${syntheticAccessToken}`, "Authenticated API requests must use a Bearer header");
    assert.equal(Object.hasOwn(requestBody, "access_token"), false, "Authenticated API requests must omit the JWT from JSON");
    authenticatedApiRequests += 1;
    await route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify({ data: { resolved: true, created: false, canonical_client_id: syntheticClientId, client_id_changed: false } }),
    });
  });
}

try {
  const desktop = await browser.newContext({ viewport: { width: 1365, height: 900 } });
  const page = await desktop.newPage();
  const pageErrors = [];
  page.on("pageerror", (error) => pageErrors.push(error.message));
  await page.route("**/api/huntnexus", (route) => route.fulfill({
    status: 200,
    contentType: "application/json",
    body: JSON.stringify({ data: { sessions: [] } }),
  }));
  await page.route("**/auth/v1/token?grant_type=password", async (route) => {
    await new Promise((resolveDelay) => setTimeout(resolveDelay, 650));
    await route.fulfill({ status: 400, contentType: "application/json", body: JSON.stringify({ message: "SYNTHETIC invalid credentials" }) });
  });
  const response = await page.goto(baseUrl + "/account", { waitUntil: "domcontentloaded", timeout: 30000 });
  assert.ok(response?.ok());
  await page.getByRole("button", { name: "Entrar", exact: true }).waitFor();
  await page.screenshot({ path: resolve(screenshotDir, "topic05-desktop-empty.png"), fullPage: true });
  await page.getByPlaceholder("seu@email.com").fill("synthetic@example.invalid");
  await page.getByText(/minúscula, maiúscula, número e símbolo/).waitFor();
  await page.getByPlaceholder(/Senha \(12\+ caracteres\)/).fill("synthetic-passphrase1!");
  assert.equal(await page.getByRole("button", { name: "Entrar", exact: true }).isDisabled(), true, "Missing uppercase must keep sign-in disabled");
  await page.getByPlaceholder(/Senha \(12\+ caracteres\)/).fill("SYNTHETIC-passphrase1!");
  await page.getByRole("button", { name: "Entrar", exact: true }).click();
  await page.screenshot({ path: resolve(screenshotDir, "topic05-desktop-loading.png"), fullPage: true });
  await page.getByText(/SYNTHETIC invalid credentials/).waitFor();
  await page.screenshot({ path: resolve(screenshotDir, "topic05-desktop-error.png"), fullPage: true });
  assert.deepEqual(pageErrors, []);
  await desktop.close();

  const mobile = await browser.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 1 });
  const mobilePage = await mobile.newPage();
  await mobilePage.route("**/api/huntnexus", (route) => route.fulfill({
    status: 200,
    contentType: "application/json",
    body: JSON.stringify({ data: { sessions: [] } }),
  }));
  await mobilePage.goto(baseUrl + "/account", { waitUntil: "domcontentloaded", timeout: 30000 });
  await mobilePage.getByRole("button", { name: "Entrar", exact: true }).waitFor();
  await mobilePage.waitForTimeout(800);
  const geometry = await mobilePage.evaluate(() => {
    const header = document.querySelector("header")?.getBoundingClientRect();
    const hero = document.querySelector("main section")?.getBoundingClientRect();
    return { headerBottom: header?.bottom ?? -1, heroTop: hero?.top ?? -1 };
  });
  assert.ok(geometry.heroTop >= geometry.headerBottom, "Mobile header must not cover the account hero at viewport top");
  await mobilePage.getByRole("button", { name: "Esqueci a senha" }).click();
  await mobilePage.getByRole("button", { name: "Enviar recuperação" }).waitFor();
  const overflow = await mobilePage.evaluate(() => document.documentElement.scrollWidth > document.documentElement.clientWidth);
  assert.equal(overflow, false, "Mobile auth page must not overflow horizontally");
  await mobilePage.screenshot({ path: resolve(screenshotDir, "topic05-mobile-recovery.png"), fullPage: false });
  await mobile.close();

  const authenticatedDesktop = await browser.newContext({ viewport: { width: 1365, height: 1000 } });
  await configureSyntheticAuthenticatedContext(authenticatedDesktop);
  const authenticatedPage = await authenticatedDesktop.newPage();
  await interceptSyntheticAuthenticatedCalls(authenticatedPage);
  await authenticatedPage.goto(baseUrl + "/account", { waitUntil: "domcontentloaded", timeout: 30000 });
  await authenticatedPage.getByRole("heading", { name: "Alterar senha", exact: true }).waitFor({ timeout: 15000 });
  await authenticatedPage.getByLabel("Senha atual").fill("SYNTHETIC-current1!");
  await authenticatedPage.getByLabel(/Nova senha \(12\+ caracteres\)/).fill("SYNTHETIC-next-passphrase1!");
  await authenticatedPage.getByLabel("Confirmar nova senha").fill("SYNTHETIC-next-passphrase1!");
  await authenticatedPage.getByRole("button", { name: "Alterar senha", exact: true }).click();
  await authenticatedPage.getByText(/precisa de um código de reautenticação/).waitFor();
  await authenticatedPage.getByLabel("Código de reautenticação").waitFor();
  await authenticatedPage.getByRole("button", { name: "Enviar novo código" }).click();
  await authenticatedPage.getByText(/Código de reautenticação enviado/).waitFor();
  await authenticatedPage.screenshot({ path: resolve(screenshotDir, "topic05-desktop-password-reauthentication.png"), fullPage: true });
  await authenticatedDesktop.close();

  const authenticatedMobile = await browser.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 1 });
  await configureSyntheticAuthenticatedContext(authenticatedMobile);
  const authenticatedMobilePage = await authenticatedMobile.newPage();
  await interceptSyntheticAuthenticatedCalls(authenticatedMobilePage);
  await authenticatedMobilePage.goto(baseUrl + "/account", { waitUntil: "domcontentloaded", timeout: 30000 });
  await authenticatedMobilePage.getByRole("heading", { name: "Alterar senha", exact: true }).waitFor({ timeout: 15000 });
  const authenticatedOverflow = await authenticatedMobilePage.evaluate(() => document.documentElement.scrollWidth > document.documentElement.clientWidth);
  assert.equal(authenticatedOverflow, false, "Authenticated mobile password controls must not overflow horizontally");
  await authenticatedMobilePage.getByRole("heading", { name: "Alterar senha", exact: true }).scrollIntoViewIfNeeded();
  await authenticatedMobilePage.screenshot({ path: resolve(screenshotDir, "topic05-mobile-password-change.png"), fullPage: false });
  await authenticatedMobile.close();
  assert.ok(authenticatedApiRequests >= 2, "Desktop and mobile authenticated flows must reach the API using Bearer transport");

  console.log(JSON.stringify({
    status: "ok",
    stage: "topic05_auth_preview",
    fixture: "SYNTHETIC",
    desktop_states: ["empty", "loading", "error", "authenticated_password_reauthentication"],
    mobile_states: ["recovery", "authenticated_password_change"],
    bearer_transport_requests_observed: authenticatedApiRequests,
    jwt_in_json_body_observed: false,
    real_auth_attempted: false,
    real_email_sent: false,
  }, null, 2));
} finally {
  await browser.close();
}
