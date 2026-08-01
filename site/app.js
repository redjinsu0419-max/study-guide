const API_URL = "https://study-guide-api.redjinsu0419.workers.dev/solve";
const school = document.body.dataset.school || "student";
const schoolLabel = document.body.dataset.schoolLabel || "학생";
const nameStorageKey = `study_guide_name_${school}`;

const imageState = {
  data: "",
  mimeType: "",
  processing: null,
};
let progressTimer = null;

function startProgress() {
  const stage = document.getElementById("loading-stage");
  const time = document.getElementById("loading-time");
  const startedAt = Date.now();

  const update = () => {
    const elapsed = Math.floor((Date.now() - startedAt) / 1000);
    if (elapsed < 5) stage.textContent = "사진을 선명하게 읽고 있어요…";
    else if (elapsed < 14) stage.textContent = "AI가 문제와 조건을 분석하고 있어요…";
    else if (elapsed < 24) stage.textContent = "단계별 풀이를 만들고 있어요…";
    else stage.textContent = "복습 문제까지 마무리하고 있어요…";

    const remaining = Math.max(0, 30 - elapsed);
    time.textContent = remaining > 0
      ? `${elapsed}초 경과 · 약 ${remaining}초 안에 완료될 예정이에요.`
      : `${elapsed}초 경과 · 조금 더 걸리고 있지만 계속 진행 중이에요.`;
  };

  update();
  progressTimer = setInterval(update, 1000);
}

function stopProgress() {
  if (progressTimer) clearInterval(progressTimer);
  progressTimer = null;
}

window.addEventListener("load", () => {
  const savedName = localStorage.getItem(nameStorageKey);
  if (savedName) showMainScreen(savedName);
});

function startApp() {
  const nameInput = document.getElementById("user-name").value.trim();
  if (!nameInput) {
    alert("이름을 입력해 주세요.");
    return;
  }
  localStorage.setItem(nameStorageKey, nameInput);
  showMainScreen(nameInput);
}

function showMainScreen(name) {
  document.getElementById("screen-login").classList.add("hidden");
  document.getElementById("screen-main").classList.remove("hidden");
  document.getElementById("user-welcome").innerText = `${name} 학생 환영합니다!`;
}

function logout() {
  localStorage.removeItem(nameStorageKey);
  document.getElementById("screen-main").classList.add("hidden");
  document.getElementById("screen-login").classList.remove("hidden");
}

function setImageStatus(message, isError = false) {
  const status = document.getElementById("image-status");
  status.textContent = message;
  status.style.color = isError ? "#dc2626" : "#64748b";
}

function cleanAiResult(text) {
  return String(text)
    .replace(/\\(?:left|right)/g, "")
    .replace(/\\rightarrow/g, "→")
    .replace(/\\times/g, "×")
    .replace(/\\div/g, "÷")
    .replace(/\\cdot/g, "·")
    .replace(/\\(?:\(|\)|\[|\])/g, "")
    .replace(/\${1,2}/g, "")
    .replace(/\*\*(.*?)\*\*/g, "$1")
    .replace(/__(.*?)__/g, "$1")
    .replace(/^#{1,6}\s*/gm, "")
    .replace(/^>\s?/gm, "")
    .replace(/^\s*[-*]\s+/gm, "• ")
    .replace(/^---+\s*$/gm, "")
    .replace(/`/g, "")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

function fileToDataUrl(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(String(reader.result));
    reader.onerror = () => reject(new Error("사진 파일을 읽지 못했습니다."));
    reader.readAsDataURL(file);
  });
}

function loadImage(dataUrl) {
  return new Promise((resolve, reject) => {
    const image = new Image();
    image.onload = () => resolve(image);
    image.onerror = () => reject(new Error("이 사진 형식은 브라우저에서 열 수 없습니다."));
    image.src = dataUrl;
  });
}

async function prepareImage(file) {
  if (!file.type.startsWith("image/")) {
    throw new Error("사진 파일만 선택해 주세요.");
  }
  if (file.size > 20 * 1024 * 1024) {
    throw new Error("사진 용량이 너무 큽니다. 20MB 이하 사진을 선택해 주세요.");
  }

  const originalDataUrl = await fileToDataUrl(file);
  const image = await loadImage(originalDataUrl);
  const width = image.naturalWidth;
  const height = image.naturalHeight;
  if (!width || !height) throw new Error("사진 크기를 확인하지 못했습니다.");

  // 작은 PNG/JPEG/WebP는 재압축하지 않아 가는 글자와 도형 선을 보존한다.
  const safeOriginalType = ["image/png", "image/jpeg", "image/webp"].includes(file.type);
  if (safeOriginalType && file.size <= 2.5 * 1024 * 1024 && Math.max(width, height) <= 1800) {
    return { dataUrl: originalDataUrl, width, height, mimeType: file.type };
  }

  const maxDimension = 1800;
  const scale = Math.min(1, maxDimension / Math.max(width, height));
  const canvas = document.createElement("canvas");
  canvas.width = Math.max(1, Math.round(width * scale));
  canvas.height = Math.max(1, Math.round(height * scale));
  const context = canvas.getContext("2d", { alpha: false });
  context.fillStyle = "white";
  context.fillRect(0, 0, canvas.width, canvas.height);
  context.imageSmoothingEnabled = true;
  context.imageSmoothingQuality = "high";
  context.drawImage(image, 0, 0, canvas.width, canvas.height);
  return {
    dataUrl: canvas.toDataURL("image/jpeg", 0.92),
    width: canvas.width,
    height: canvas.height,
    mimeType: "image/jpeg",
  };
}

function previewImage(event) {
  const file = event.target.files?.[0];
  if (!file) return;

  const otherInputId = event.target.id === "camera-image" ? "problem-image" : "camera-image";
  const otherInput = document.getElementById(otherInputId);
  if (otherInput) otherInput.value = "";

  imageState.data = "";
  imageState.mimeType = "";
  setImageStatus("사진을 준비하고 있습니다…");
  const solveButton = document.getElementById("solve-button");
  solveButton.disabled = true;

  imageState.processing = prepareImage(file)
    .then(({ dataUrl, width, height, mimeType }) => {
      const commaIndex = dataUrl.indexOf(",");
      if (commaIndex < 0) throw new Error("사진 데이터가 올바르지 않습니다.");
      imageState.data = dataUrl.slice(commaIndex + 1);
      imageState.mimeType = mimeType;
      const preview = document.getElementById("image-preview");
      preview.src = dataUrl;
      preview.style.display = "block";
      setImageStatus(`사진 준비 완료 (${width}×${height})`);
    })
    .catch((error) => {
      event.target.value = "";
      setImageStatus(error.message, true);
      throw error;
    })
    .finally(() => {
      solveButton.disabled = false;
    });
}

async function solveProblem() {
  const grade = document.getElementById("grade").value;
  const subject = document.getElementById("subject").value;
  const problemText = document.getElementById("problem-text").value.trim();
  const selectedFile = document.getElementById("problem-image").files?.[0]
    || document.getElementById("camera-image").files?.[0];

  if (imageState.processing) {
    try {
      await imageState.processing;
    } catch {
      alert("사진을 처리하지 못했습니다. 다른 사진을 선택해 주세요.");
      return;
    }
  }
  if (selectedFile && !imageState.data) {
    alert("사진 준비가 끝나지 않았습니다. 잠시 후 다시 눌러주세요.");
    return;
  }
  if (!imageState.data && !problemText) {
    alert("문제 사진을 첨부하거나 문제 내용을 입력해 주세요.");
    return;
  }

  const loading = document.getElementById("loading");
  const resultBox = document.getElementById("result-box");
  const solveButton = document.getElementById("solve-button");
  loading.classList.remove("hidden");
  resultBox.classList.add("hidden");
  solveButton.disabled = true;
  startProgress();

  try {
    const response = await fetch(API_URL, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        school,
        schoolLabel,
        grade,
        subject,
        problemText,
        image: imageState.data
          ? { mimeType: imageState.mimeType, data: imageState.data }
          : null,
      }),
    });
    const payload = await response.json().catch(() => ({}));
    if (!response.ok) {
      throw new Error(payload.error || `서버 오류 (${response.status})`);
    }
    if (!payload.result) throw new Error("AI가 빈 답변을 보냈습니다.");
    document.getElementById("result-text").innerText = cleanAiResult(payload.result);
    resultBox.classList.remove("hidden");
    resultBox.scrollIntoView({ behavior: "smooth", block: "start" });
  } catch (error) {
    alert(`AI 풀이를 받지 못했습니다.\n${error.message}\n\n잠시 후 다시 시도해 주세요.`);
  } finally {
    stopProgress();
    loading.classList.add("hidden");
    solveButton.disabled = false;
  }
}
