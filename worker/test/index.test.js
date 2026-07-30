import assert from "node:assert/strict";
import test from "node:test";

import worker from "../src/index.js";

const configuredEnvironment = {
  FIREBASE_PROJECT_ID: "stst-27641",
  GEMINI_API_KEY: "test-gemini-key",
  PINECONE_API_KEY: "test-pinecone-key",
};

test("health endpoint is public and contains no secrets", async () => {
  const response = await worker.fetch(
    new Request("https://worker.test/health"),
    {},
  );
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), {
    ok: true,
    service: "study-guide-api",
  });
});

test("solve endpoint requires Firebase authentication", async () => {
  const response = await worker.fetch(
    new Request("https://worker.test/solve", { method: "POST" }),
    configuredEnvironment,
  );
  assert.equal(response.status, 401);
  assert.equal((await response.json()).ok, false);
});

test("unknown paths return 404", async () => {
  const response = await worker.fetch(
    new Request("https://worker.test/unknown"),
    configuredEnvironment,
  );
  assert.equal(response.status, 404);
});

test("authenticated Firebase user receives a combined solution", async () => {
  const fixture = await firebaseTokenFixture({
    email: "student@example.com",
    uid: "student-1",
  });
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (input) => {
    const url = String(input);
    if (url.includes("/service_accounts/v1/jwk/")) {
      return Response.json(
        { keys: [fixture.publicJwk] },
        { headers: { "Cache-Control": "public, max-age=3600" } },
      );
    }
    if (url.includes("generativelanguage.googleapis.com")) {
      return Response.json({
        candidates: [
          {
            content: {
              parts: [
                {
                  text: JSON.stringify(geminiFixture()),
                },
              ],
            },
          },
        ],
      });
    }
    if (url === "https://api.pinecone.io/indexes") {
      return Response.json({
        indexes: [
          {
            host: "study-guide.test.pinecone.io",
            status: { ready: true },
          },
        ],
      });
    }
    if (url.includes("study-guide.test.pinecone.io/records/")) {
      return Response.json({
        result: {
          hits: [
            {
              fields: {
                question: "유사 문제 1",
                answer: "1",
                explanation: "풀이 1",
                type: "similar",
              },
            },
            {
              fields: {
                question: "예상 문제 1",
                answer: "2",
                explanation: "풀이 2",
                type: "expected",
              },
            },
          ],
        },
      });
    }
    throw new Error(`Unexpected fetch: ${url}`);
  };

  try {
    const response = await worker.fetch(
      new Request("https://worker.test/solve", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${fixture.token}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          imageBase64: "aGVsbG8=",
          mimeType: "image/jpeg",
          schoolLevel: "middle",
          schoolLevelLabel: "중학교",
          grade: 2,
          subject: "수학",
        }),
      }),
      {
        ...configuredEnvironment,
        GEMINI_MODEL: "gemini-3.6-flash",
      },
    );
    assert.equal(response.status, 200);
    const body = await response.json();
    assert.equal(body.result.finalAnswer, "4");
    assert.equal(body.result.similarQuestions.length, 2);
    assert.equal(body.result.expectedQuestions.length, 2);

    const invalidSubjectResponse = await worker.fetch(
      new Request("https://worker.test/solve", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${fixture.token}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          imageBase64: "aGVsbG8=",
          mimeType: "image/jpeg",
          schoolLevel: "middle",
          schoolLevelLabel: "중학교",
          grade: 2,
          subject: "임의 과목",
        }),
      }),
      configuredEnvironment,
    );
    assert.equal(invalidSubjectResponse.status, 400);

  } finally {
    globalThis.fetch = originalFetch;
  }
});

function geminiFixture() {
  return {
    problemText: "2 + 2는?",
    finalAnswer: "4",
    summary: "덧셈 문제",
    steps: ["2와 2를 더한다.", "4를 얻는다."],
    keyConcepts: ["덧셈"],
    searchQuery: "중학교 수학 덧셈",
    similarFallback: [
      {
        question: "유사 문제 2",
        answer: "3",
        explanation: "1 + 2",
      },
      {
        question: "유사 문제 3",
        answer: "5",
        explanation: "2 + 3",
      },
    ],
    expectedFallback: [
      {
        question: "예상 문제 2",
        answer: "6",
        explanation: "3 + 3",
      },
      {
        question: "예상 문제 3",
        answer: "8",
        explanation: "4 + 4",
      },
    ],
  };
}

function solveRequest(token) {
  return new Request("https://worker.test/solve", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      imageBase64: "aGVsbG8=",
      mimeType: "image/jpeg",
      schoolLevel: "middle",
      schoolLevelLabel: "중학교",
      grade: 2,
      subject: "수학",
    }),
  });
}

async function firebaseTokenFixture({ email, uid }) {
  const keyPair = await crypto.subtle.generateKey(
    {
      name: "RSASSA-PKCS1-v1_5",
      modulusLength: 2048,
      publicExponent: new Uint8Array([1, 0, 1]),
      hash: "SHA-256",
    },
    true,
    ["sign", "verify"],
  );
  const publicJwk = await crypto.subtle.exportKey("jwk", keyPair.publicKey);
  Object.assign(publicJwk, {
    kid: "test-key",
    alg: "RS256",
    use: "sig",
  });
  const now = Math.floor(Date.now() / 1000);
  const header = base64UrlJson({ alg: "RS256", kid: "test-key", typ: "JWT" });
  const payload = base64UrlJson({
    aud: "stst-27641",
    iss: "https://securetoken.google.com/stst-27641",
    sub: uid,
    email,
    iat: now,
    auth_time: now,
    exp: now + 3600,
  });
  const unsigned = `${header}.${payload}`;
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    keyPair.privateKey,
    new TextEncoder().encode(unsigned),
  );
  return {
    publicJwk,
    token: `${unsigned}.${base64UrlBytes(new Uint8Array(signature))}`,
  };
}

function base64UrlJson(value) {
  return base64UrlBytes(new TextEncoder().encode(JSON.stringify(value)));
}

function base64UrlBytes(value) {
  return Buffer.from(value)
    .toString("base64")
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
}
