export default {
  async fetch(request, env, ctx) {
    if (request.method === 'OPTIONS') {
      return new Response(null, {
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'POST, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type',
        },
      });
    }

    if (request.method !== 'POST') {
      return new Response('Method Not Allowed', { status: 405 });
    }

    try {
      const { imageBase64, textPrompt } = await request.json();
      const apiKey = env.GEMINI_API_KEY;

      if (!apiKey) {
        return new Response(JSON.stringify({ error: 'GEMINI_API_KEY가 설정되지 않았습니다.' }), {
          status: 500,
          headers: { 'Content-Type': 'application/json' },
        });
      }

      const parts = [
        { text: "다음 문제 사진 또는 질문을 분석하여, 정답과 상세한 풀이 과정을 친절한 한국어로 설명해 주세요." }
      ];

      if (textPrompt) {
        parts.push({ text: `질문/문제: ${textPrompt}` });
      }

      if (imageBase64) {
        parts.push({
          inlineData: {
            mimeType: "image/jpeg",
            data: imageBase64.replace(/^data:image\/\w+;base64,/, '')
          }
        });
      }

      const apiUrl = `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${apiKey}`;

      const aiResponse = await fetch(apiUrl, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ contents: [{ parts }] }),
      });

      const data = await aiResponse.json();
      const solutionText = data.candidates?.[0]?.content?.parts?.[0]?.text || "해설을 생성하지 못했습니다.";

      return new Response(JSON.stringify({ result: solutionText }), {
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      });
    } catch (error) {
      return new Response(JSON.stringify({ error: error.message }), {
        status: 500,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      });
    }
  },
};
