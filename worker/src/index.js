const JSON_HEADERS = {
  "Content-Type": "application/json; charset=utf-8",
  "Cache-Control": "no-store",
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "Authorization, Content-Type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

const SCHOOL_LEVELS = {
  elementary: {
    label: "초등학생",
    maxGrade: 6,
    subjects: ["국어", "수학", "사회", "과학", "영어", "도덕"],
  },
  middle: {
    label: "중학생",
    maxGrade: 3,
    subjects: [
      "국어",
      "수학",
      "영어",
      "사회",
      "역사",
      "과학",
      "도덕",
      "기술·가정",
      "정보",
    ],
  },
  high: {
    label: "고등학생",
    maxGrade: 3,
    subjects: [
      "국어",
      "수학",
      "영어",
      "한국사",
      "통합사회",
      "통합과학",
      "물리학",
      "화학",
      "생명과학",
      "지구과학",
      "사회탐구",
      "정보",
    ],
  },
};

let firebaseJwks = null;
let firebaseJwksExpiresAt = 0;

const QUESTION_SCHEMA = {
  type: "object",
  properties: {
    question: { type: "string" },
    answer: { type: "string" },
    explanation: { type: "string" },
  },
  required: ["question", "answer", "explanation"],
};

const RESPONSE_SCHEMA = {
  type: "object",
  properties: {
    problemText: { type: "string" },
    finalAnswer: { type: "string" },
    summary: { type: "string" },
    steps: { type: "array", items: { type: "string" } },
    keyConcepts: { type: "array", items: { type: "string" } },
    searchQuery: { type: "string" },
    similarFallback: {
      type: "array",
      minItems: 2,
      maxItems: 2,
      items: QUESTION_SCHEMA,
    },
    expectedFallback: {
      type: "array",
      minItems: 2,
      maxItems: 2,
      items: QUESTION_SCHEMA,
    },
  },
  required: [
    "problemText",
    "finalAnswer",
    "summary",
    "steps",
    "keyConcepts",
    "searchQuery",
    "similarFallback",
    "expectedFallback",
  ],
};

class ApiError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

export default {
  async fetch(request, env) {
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: JSON_HEADERS });
    }

    const url = new URL(request.url);
    if (request.method === "GET" && url.pathname === "/health") {
      return jsonResponse(200, {
        ok: true,
        service: "study-guide-api",
      });
    }
    if (request.method !== "POST" || url.pathname !== "/solve") {
      return jsonResponse(404, {
        ok: false,
        message: "요청한 경로를 찾을 수 없습니다.",
      });
    }

    try {
      validateEnvironment(env);
      const idToken = bearerToken(request.headers.get("Authorization"));
      await verifyFirebaseToken(idToken, env);
      const input = await readSolveInput(request);
      const geminiResult = await solveWithGemini(input, env);
      const retrieval = await searchPinecone(
        geminiResult.searchQuery,
        input,
        env,
      ).catch((error) => {
        console.error("pinecone failed", error);
        return {
          similar: [],
          expected: [],
          message: "Pinecone 검색 실패",
        };
      });

      const similar = fillToTwo(
        retrieval.similar,
        geminiResult.similarFallback,
        "Gemini 대체 생성",
      );
      const expected = fillToTwo(
        retrieval.expected,
        geminiResult.expectedFallback,
        "Gemini 대체 생성",
      );
      const usedPinecone =
        retrieval.similar.length > 0 || retrieval.expected.length > 0;

      return jsonResponse(200, {
        ok: true,
        result: {
          schoolLevel: input.schoolLevelLabel,
          grade: input.grade,
          subject: input.subject,
          problemText: cleanText(geminiResult.problemText),
          finalAnswer: cleanText(geminiResult.finalAnswer),
          summary: cleanText(geminiResult.summary),
          steps: stringList(geminiResult.steps),
          keyConcepts: stringList(geminiResult.keyConcepts),
          searchQuery: cleanText(geminiResult.searchQuery),
          similarQuestions: similar,
          expectedQuestions: expected,
          retrievalMessage: usedPinecone
            ? retrieval.message
            : `${retrieval.message} · Gemini 생성 문제로 대체`,
          isWrong: false,
        },
      });
    } catch (error) {
      const status = error instanceof ApiError ? error.status : 500;
      const message =
        error instanceof ApiError
          ? error.message
          : "서버에서 문제를 처리하지 못했습니다. 잠시 후 다시 시도해 주세요.";
      if (status >= 500) console.error("solve failed", error);
      return jsonResponse(status, { ok: false, message });
    }
  },
};

function validateEnvironment(env) {
  const required = [
    "FIREBASE_PROJECT_ID",
    "GEMINI_API_KEY",
    "PINECONE_API_KEY",
  ];
  const missing = required.filter((name) => !cleanText(env[name]));
  if (missing.length > 0) {
    throw new ApiError(503, "서버 환경 설정이 아직 완료되지 않았습니다.");
  }
}

function bearerToken(value) {
  if (!value || !value.startsWith("Bearer ")) {
    throw new ApiError(401, "로그인이 필요합니다.");
  }
  const token = value.slice(7).trim();
  if (!token) throw new ApiError(401, "로그인이 필요합니다.");
  return token;
}

async function verifyFirebaseToken(idToken, env) {
  const parts = idToken.split(".");
  if (parts.length !== 3) {
    throw new ApiError(401, "로그인이 만료되었습니다. 다시 로그인해 주세요.");
  }
  let header;
  let payload;
  try {
    header = decodeJwtPart(parts[0]);
    payload = decodeJwtPart(parts[1]);
  } catch (_) {
    throw new ApiError(401, "로그인이 만료되었습니다. 다시 로그인해 주세요.");
  }
  if (header.alg !== "RS256" || !cleanText(header.kid)) {
    throw new ApiError(401, "로그인 토큰 형식이 올바르지 않습니다.");
  }

  let jwk = await firebaseJwk(header.kid);
  if (!jwk) jwk = await firebaseJwk(header.kid, true);
  if (!jwk) {
    throw new ApiError(401, "로그인 서명을 확인하지 못했습니다.");
  }
  const publicKey = await crypto.subtle.importKey(
    "jwk",
    jwk,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["verify"],
  );
  const verified = await crypto.subtle.verify(
    "RSASSA-PKCS1-v1_5",
    publicKey,
    decodeBase64Url(parts[2]),
    new TextEncoder().encode(`${parts[0]}.${parts[1]}`),
  );
  const now = Math.floor(Date.now() / 1000);
  const projectId = cleanText(env.FIREBASE_PROJECT_ID);
  const expiresAt = Number(payload.exp);
  const issuedAt = Number(payload.iat);
  const authenticatedAt = Number(payload.auth_time);
  if (
    !verified ||
    payload.aud !== projectId ||
    payload.iss !== `https://securetoken.google.com/${projectId}` ||
    !cleanText(payload.sub) ||
    !Number.isFinite(expiresAt) ||
    !Number.isFinite(issuedAt) ||
    !Number.isFinite(authenticatedAt) ||
    expiresAt <= now ||
    issuedAt > now + 60 ||
    authenticatedAt > now + 60
  ) {
    throw new ApiError(401, "로그인이 만료되었습니다. 다시 로그인해 주세요.");
  }
  return {
    uid: cleanText(payload.sub),
    email: cleanText(payload.email).toLowerCase(),
  };
}

async function firebaseJwk(kid, forceRefresh = false) {
  if (
    forceRefresh ||
    !firebaseJwks ||
    Date.now() >= firebaseJwksExpiresAt
  ) {
    const response = await fetch(
      "https://www.googleapis.com/service_accounts/v1/jwk/" +
        "securetoken@system.gserviceaccount.com",
    );
    if (!response.ok) {
      throw new ApiError(503, "Firebase 로그인 서명을 확인하지 못했습니다.");
    }
    const body = await response.json();
    firebaseJwks = Array.isArray(body.keys) ? body.keys : [];
    const cacheControl = response.headers.get("Cache-Control") || "";
    const maxAge = Number(cacheControl.match(/max-age=(\d+)/)?.[1] || "3600");
    firebaseJwksExpiresAt = Date.now() + Math.max(maxAge, 300) * 1000;
  }
  return firebaseJwks.find((key) => key.kid === kid);
}

function decodeJwtPart(value) {
  return JSON.parse(new TextDecoder().decode(decodeBase64Url(value)));
}

function decodeBase64Url(value) {
  const normalized = value.replace(/-/g, "+").replace(/_/g, "/");
  const padded = normalized + "=".repeat((4 - (normalized.length % 4)) % 4);
  const binary = atob(padded);
  return Uint8Array.from(binary, (character) => character.charCodeAt(0));
}

async function readSolveInput(request) {
  const contentLength = Number(request.headers.get("Content-Length") || "0");
  if (contentLength > 18 * 1024 * 1024) {
    throw new ApiError(413, "사진 용량이 너무 큽니다. 다시 촬영해 주세요.");
  }

  let body;
  try {
    body = await request.json();
  } catch (_) {
    throw new ApiError(400, "요청 형식이 올바르지 않습니다.");
  }
  const imageBase64 = cleanText(body.imageBase64);
  const mimeType = cleanText(body.mimeType).toLowerCase();
  const schoolLevel = cleanText(body.schoolLevel);
  const grade = Number(body.grade);
  const subject = cleanText(body.subject);
  const allowedMimeTypes = new Set([
    "image/jpeg",
    "image/png",
    "image/webp",
    "image/heic",
    "image/heif",
  ]);

  if (!imageBase64 || imageBase64.length > 17 * 1024 * 1024) {
    throw new ApiError(413, "사진 용량이 너무 큽니다. 다시 촬영해 주세요.");
  }
  if (!allowedMimeTypes.has(mimeType)) {
    throw new ApiError(400, "지원하지 않는 사진 형식입니다.");
  }
  const levelConfig = SCHOOL_LEVELS[schoolLevel];
  if (!levelConfig) {
    throw new ApiError(400, "학교급을 다시 선택해 주세요.");
  }
  if (
    !Number.isInteger(grade) ||
    grade < 1 ||
    grade > levelConfig.maxGrade
  ) {
    throw new ApiError(400, "학년을 다시 선택해 주세요.");
  }
  if (!levelConfig.subjects.includes(subject)) {
    throw new ApiError(400, "학년과 과목을 다시 선택해 주세요.");
  }

  return {
    imageBase64,
    mimeType,
    schoolLevel,
    schoolLevelLabel: levelConfig.label,
    grade,
    subject,
  };
}

async function solveWithGemini(input, env) {
  const model = encodeURIComponent(env.GEMINI_MODEL || "gemini-3.6-flash");
  const url =
    `https://generativelanguage.googleapis.com/v1beta/models/${model}` +
    ":generateContent";
  const response = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-goog-api-key": env.GEMINI_API_KEY,
    },
    body: JSON.stringify({
      contents: [
        {
          role: "user",
          parts: [
            { text: buildPrompt(input) },
            {
              inlineData: {
                mimeType: input.mimeType,
                data: input.imageBase64,
              },
            },
          ],
        },
      ],
      generationConfig: {
        maxOutputTokens: 8192,
        responseMimeType: "application/json",
        responseJsonSchema: RESPONSE_SCHEMA,
      },
    }),
  });
  if (!response.ok) {
    const detail = await safeApiMessage(response);
    throw new ApiError(502, `Gemini 처리에 실패했습니다. ${detail}`);
  }
  const root = await response.json();
  const parts = root?.candidates?.[0]?.content?.parts;
  const text = Array.isArray(parts)
    ? parts.map((part) => cleanText(part.text)).join("")
    : "";
  if (!text) {
    throw new ApiError(422, "사진 속 문제를 읽지 못했습니다. 다시 찍어 주세요.");
  }

  let result;
  try {
    result = JSON.parse(
      text
        .trim()
        .replace(/^```(?:json)?\s*/i, "")
        .replace(/\s*```$/, ""),
    );
  } catch (_) {
    throw new ApiError(502, "Gemini 답변 형식을 읽지 못했습니다.");
  }
  if (!cleanText(result.problemText) || !cleanText(result.finalAnswer)) {
    throw new ApiError(422, "사진 속 문제를 읽지 못했습니다. 다시 찍어 주세요.");
  }
  return result;
}

function buildPrompt(input) {
  return `
너는 대한민국 ${input.schoolLevelLabel} ${input.grade}학년 학생을 돕는 친절하고 정확한 ${input.subject} 선생님이다.
사진 속 문제를 읽고 학생 수준에 맞게 풀이하라.

규칙:
1. 문제 문장을 빠짐없이 옮기되 개인정보나 학생 이름은 결과에 포함하지 않는다.
2. 정답만 말하지 말고 학생이 따라갈 수 있는 순서로 풀이한다.
3. 계산·논리·단위를 다시 검산한다. 사진이 흐리거나 조건이 잘리면 추측하지 말고 그 사실을 명시한다.
4. 유사 검색용 searchQuery는 학년, 과목, 핵심 개념, 문제 유형을 포함한 한 문장으로 만든다.
5. Pinecone 검색 실패에 대비해 저작권 자료를 베끼지 않은 새로운 유사 문제 2개와 예상 문제 2개도 만든다.
6. 결과는 지정된 JSON 형식만 출력한다. 수식은 일반 텍스트로 읽기 쉽게 적는다.
`.trim();
}

async function searchPinecone(query, input, env) {
  const host = await resolvePineconeHost(env);
  const namespace = encodeURIComponent(env.PINECONE_NAMESPACE || "__default__");
  const textField = env.PINECONE_TEXT_FIELD || "chunk_text";
  const response = await fetch(
    `https://${host}/records/namespaces/${namespace}/search`,
    {
      method: "POST",
      headers: pineconeHeaders(env),
      body: JSON.stringify({
        query: {
          inputs: {
            text:
              `${input.schoolLevelLabel} ${input.grade}학년 ` +
              `${input.subject} ${cleanText(query)}`,
          },
          top_k: 12,
        },
        fields: [
          textField,
          "question",
          "problem",
          "answer",
          "explanation",
          "solution",
          "kind",
          "type",
          "source",
          "schoolLevel",
          "grade",
          "subject",
        ],
      }),
    },
  );
  if (!response.ok) {
    throw new Error(await safeApiMessage(response));
  }
  const root = await response.json();
  const hits = root?.result?.hits || root?.hits || root?.matches || [];
  const ranked = (Array.isArray(hits) ? hits : [])
    .map((hit) => parsePineconeHit(hit, input))
    .filter((hit) => hit.item.question)
    .sort((a, b) => b.score - a.score);

  const similar = [];
  const expected = [];
  const used = new Set();
  for (const hit of ranked) {
    const normalized = hit.item.question.toLowerCase();
    if (used.has(normalized)) continue;
    used.add(normalized);
    if (hit.expected && expected.length < 2) {
      expected.push({ ...hit.item, source: "Pinecone 예상 문제" });
    } else if (similar.length < 2) {
      similar.push({ ...hit.item, source: "Pinecone 유사 기출" });
    }
    if (similar.length === 2 && expected.length === 2) break;
  }

  return {
    similar,
    expected,
    message:
      hits.length === 0
        ? "Pinecone 검색 결과 없음"
        : `Pinecone ${hits.length}건 검색 완료`,
  };
}

async function resolvePineconeHost(env) {
  if (cleanText(env.PINECONE_INDEX_HOST)) {
    return normalizeHost(env.PINECONE_INDEX_HOST);
  }
  const response = await fetch("https://api.pinecone.io/indexes", {
    headers: pineconeHeaders(env),
  });
  if (!response.ok) throw new Error(await safeApiMessage(response));
  const root = await response.json();
  const indexes = Array.isArray(root.indexes) ? root.indexes : [];
  const preferredName =
    cleanText(env.PINECONE_INDEX_NAME) || "study-guide-questions";
  const preferredIndex = indexes.find(
    (item) =>
      cleanText(item.name) === preferredName &&
      cleanText(item.host) &&
      item?.status?.ready !== false,
  );
  const index = preferredIndex || indexes.find(
    (item) => cleanText(item.host) && item?.status?.ready !== false,
  );
  if (!index) throw new Error("사용 가능한 Pinecone 인덱스가 없습니다.");
  return normalizeHost(index.host);
}

function pineconeHeaders(env) {
  return {
    Accept: "application/json",
    "Content-Type": "application/json",
    "Api-Key": env.PINECONE_API_KEY,
    "X-Pinecone-Api-Version": "2025-10",
  };
}

function parsePineconeHit(hit, input) {
  const fields = hit?.fields || hit?.metadata || hit || {};
  const kind = cleanText(fields.kind || fields.type).toLowerCase();
  const schoolLevel = cleanText(fields.schoolLevel);
  const grade = Number(fields.grade);
  const subject = cleanText(fields.subject);
  let score = 0;
  if (
    !schoolLevel ||
    schoolLevel.toLowerCase() === input.schoolLevel ||
    schoolLevel.includes(input.schoolLevelLabel.slice(0, 1))
  ) {
    score += 2;
  }
  if (!Number.isFinite(grade) || grade === input.grade) score += 2;
  if (!subject || subject === input.subject) score += 3;

  return {
    item: questionFromMap(fields, "Pinecone"),
    expected:
      kind.includes("expected") ||
      kind.includes("predicted") ||
      kind.includes("forecast") ||
      kind.includes("예상"),
    score,
  };
}

function questionFromMap(map, defaultSource) {
  return {
    question: firstText(map, [
      "question",
      "problem",
      "chunk_text",
      "text",
      "content",
    ]),
    answer: firstText(map, ["answer", "finalAnswer", "correct_answer"]),
    explanation: firstText(map, [
      "explanation",
      "solution",
      "rationale",
    ]),
    source: firstText(map, ["source", "origin"]) || defaultSource,
  };
}

function fillToTwo(primary, fallback, fallbackSource) {
  const output = [];
  const used = new Set();
  for (const raw of [...(primary || []), ...(fallback || [])]) {
    const item = questionFromMap(raw, raw.source || fallbackSource);
    const normalized = item.question.toLowerCase();
    if (!normalized || used.has(normalized)) continue;
    used.add(normalized);
    output.push(item);
    if (output.length === 2) break;
  }
  return output;
}

function firstText(map, keys) {
  for (const key of keys) {
    const value = cleanText(map?.[key]);
    if (value) return value;
  }
  return "";
}

function stringList(value) {
  if (!Array.isArray(value)) return [];
  return value.map(cleanText).filter(Boolean);
}

function cleanText(value) {
  return value == null ? "" : String(value).trim();
}

function normalizeHost(value) {
  return cleanText(value)
    .replace(/^https?:\/\//i, "")
    .replace(/\/+$/, "");
}

async function safeApiMessage(response) {
  try {
    const body = await response.json();
    return cleanText(body?.error?.message || body?.message) ||
      `(${response.status})`;
  } catch (_) {
    return `(${response.status})`;
  }
}

function jsonResponse(status, body) {
  return new Response(JSON.stringify(body), {
    status,
    headers: JSON_HEADERS,
  });
}
