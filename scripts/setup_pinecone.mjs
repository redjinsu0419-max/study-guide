import { readFile } from "node:fs/promises";

const apiKey = process.env.PINECONE_API_KEY;
const indexName = process.env.PINECONE_INDEX_NAME ?? "study-guide-questions";
const namespace = process.env.PINECONE_NAMESPACE ?? "__default__";
const apiVersion = "2025-10";

if (!apiKey) {
  throw new Error(
    "PINECONE_API_KEY 환경 변수를 먼저 설정하세요. 키를 파일에 적지 마세요.",
  );
}

const headers = {
  "Api-Key": apiKey,
  "Content-Type": "application/json",
  "X-Pinecone-Api-Version": apiVersion,
};

async function request(url, options = {}) {
  const response = await fetch(url, {
    ...options,
    headers: { ...headers, ...(options.headers ?? {}) },
  });
  const text = await response.text();
  let body = {};
  if (text) {
    try {
      body = JSON.parse(text);
    } catch {
      body = { raw: text };
    }
  }
  if (!response.ok) {
    const detail =
      body.message ??
      body.error?.message ??
      body.error ??
      body.raw ??
      JSON.stringify(body);
    throw new Error(
      `Pinecone ${response.status}: ${detail || "요청 실패"}`,
    );
  }
  return body;
}

async function findOrCreateIndex() {
  const listed = await request("https://api.pinecone.io/indexes");
  let index = (listed.indexes ?? []).find((item) => item.name === indexName);
  if (!index) {
    console.log(`통합 임베딩 인덱스 생성: ${indexName}`);
    await request("https://api.pinecone.io/indexes/create-for-model", {
      method: "POST",
      body: JSON.stringify({
        name: indexName,
        cloud: "aws",
        region: "us-east-1",
        embed: {
          model: "multilingual-e5-large",
          field_map: { text: "chunk_text" },
        },
      }),
    });
  }

  for (let attempt = 0; attempt < 40; attempt += 1) {
    index = await request(
      `https://api.pinecone.io/indexes/${encodeURIComponent(indexName)}`,
    );
    if (index.status?.ready && index.host) return index;
    await new Promise((resolve) => setTimeout(resolve, 3000));
  }
  throw new Error("인덱스 준비 시간이 초과되었습니다. Pinecone 콘솔을 확인하세요.");
}

const index = await findOrCreateIndex();
const raw = await readFile(
  new URL("../data/questions.sample.json", import.meta.url),
  "utf8",
);
const records = JSON.parse(raw);

if (!Array.isArray(records) || records.length === 0) {
  throw new Error("data/questions.sample.json에 레코드가 없습니다.");
}

const endpoint =
  `https://${index.host}/records/namespaces/` +
  `${encodeURIComponent(namespace)}/upsert`;

for (let start = 0; start < records.length; start += 96) {
  const batch = records.slice(start, start + 96);
  await request(endpoint, {
    method: "POST",
    headers: { "Content-Type": "application/x-ndjson" },
    body: batch.map((record) => JSON.stringify(record)).join("\n"),
  });
  console.log(`${Math.min(start + batch.length, records.length)}건 등록 완료`);
}

console.log("Pinecone 준비 완료");
console.log(`인덱스 호스트: ${index.host}`);
console.log(
  "이 호스트를 Cloudflare Worker의 PINECONE_INDEX_HOST 변수에 입력하면 자동 탐색 단계를 생략할 수 있습니다.",
);
