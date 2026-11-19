import { createClient } from "@supabase/supabase-js";

const { FOOD_API_KEY, SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY } = process.env;
if (!FOOD_API_KEY || !SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  console.error("FOOD_API_KEY, SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY 환경변수가 필요합니다.");
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
const PAGE = 1000;

async function fetchPage(start, end) {
  const url = `http://openapi.foodsafetykorea.go.kr/api/${FOOD_API_KEY}/COOKRCP01/json/${start}/${end}`;
  const res = await fetch(url);
  if (!res.ok) throw new Error(`HTTP ${res.status} (${start}-${end})`);
  const data = await res.json();
  const body = data.COOKRCP01;
  if (!body) throw new Error(`예상치 못한 응답: ${JSON.stringify(data).slice(0, 300)}`);
  const code = body.RESULT?.CODE;
  if (code && code !== "INFO-000") {
    if (code === "INFO-200") return { total: Number(body.total_count ?? 0), rows: [] };
    throw new Error(`API 오류 ${code}: ${body.RESULT?.MSG}`);
  }
  return { total: Number(body.total_count), rows: body.row ?? [] };
}

const num = (v) => {
  const n = parseFloat(String(v ?? "").replace(/,/g, ""));
  return Number.isFinite(n) ? n : null;
};
const str = (v) => {
  const s = String(v ?? "").trim();
  return s === "" ? null : s;
};

function toRecord(r) {
  const steps = [];
  for (let i = 1; i <= 20; i++) {
    const k = String(i).padStart(2, "0");
    const text = str(r[`MANUAL${k}`]);
    if (!text) continue;
    const clean = text.replace(/^\d+\.\s*/, "").replace(/[a-z]$/, "").trim();
    steps.push({ step: steps.length + 1, text: clean, img: str(r[`MANUAL_IMG${k}`]) });
  }
  return {
    id: Number(r.RCP_SEQ),
    name: str(r.RCP_NM),
    cook_method: str(r.RCP_WAY2),
    category: str(r.RCP_PAT2),
    hash_tag: str(r.HASH_TAG),
    weight: num(r.INFO_WGT),
    calories: num(r.INFO_ENG),
    carbs: num(r.INFO_CAR),
    protein: num(r.INFO_PRO),
    fat: num(r.INFO_FAT),
    sodium: num(r.INFO_NA),
    ingredients: str(r.RCP_PARTS_DTLS),
    img_main: str(r.ATT_FILE_NO_MAIN),
    img_large: str(r.ATT_FILE_NO_MK),
    steps,
    tip: str(r.RCP_NA_TIP),
  };
}

const first = await fetchPage(1, PAGE);
const total = first.total;
let all = first.rows;
console.log(`전체 ${total}건`);
for (let start = PAGE + 1; start <= total; start += PAGE) {
  const { rows } = await fetchPage(start, Math.min(start + PAGE - 1, total));
  all = all.concat(rows);
}
console.log(`받은 데이터 ${all.length}건`);

const records = all.map(toRecord).filter((r) => r.id && r.name);
for (let i = 0; i < records.length; i += 500) {
  const chunk = records.slice(i, i + 500);
  const { error } = await supabase.from("recipes").upsert(chunk, { onConflict: "id" });
  if (error) throw error;
  console.log(`업로드 ${Math.min(i + 500, records.length)}/${records.length}`);
}
console.log("완료");