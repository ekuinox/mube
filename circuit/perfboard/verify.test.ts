// circuit/perfboard/verify.test.ts
import { expect, test } from "bun:test"
import { verifyLayout, type Layout } from "./verify"

// 最小の作り物。実データ（layout.ts）は Task 7 で検証する。
// GND は Pico の内部結線に頼るので、SW1.pin2 は 8 番ピンの穴へ落とす。
function minimal(): Layout {
  return {
    legs: { "SW1.pin1": "N7", "SW1.pin2": "N8" },
    wires: [
      { from: "N7", to: "L7", net: "BTN", side: "solder" },
      { from: "N8", to: "L8", net: "GND", side: "solder" },
    ],
  }
}

// 目的: 正しく繋がった配置が、BTN について問題を出さないこと。
test("繋がっている配置は BTN の指摘を出さない", () => {
  const problems = verifyLayout(minimal())
  expect(problems.filter((p) => p.includes("BTN"))).toEqual([])
})

// 目的: ワイヤを 1 本落とすと未接続として検出されること。
test("未接続を検出する", () => {
  const layout = minimal()
  layout.wires = layout.wires.filter((w) => w.net !== "BTN")
  expect(verifyLayout(layout).some((p) => p.includes("BTN") && p.includes("未接続"))).toBe(true)
})

// 目的: 異なるネットが同じ穴に集まったらショートとして検出されること。
test("ショートを検出する", () => {
  const layout = minimal()
  layout.wires.push({ from: "L7", to: "L8", net: "BTN", side: "solder" })
  expect(verifyLayout(layout).some((p) => p.includes("ショート"))).toBe(true)
})

// 目的: 同じ穴に 2 本の足を挿す配置を弾くこと。物理的に入らない。
test("穴の重複を検出する", () => {
  const layout = minimal()
  layout.legs["D1.K"] = "N7"
  expect(verifyLayout(layout).some((p) => p.includes("重複"))).toBe(true)
})

// 目的: ネットの端点に穴を割り当て忘れたら取りこぼしとして検出されること。
test("穴の割り当て漏れを検出する", () => {
  const problems = verifyLayout(minimal())
  expect(problems.some((p) => p.includes("穴が無い") && p.includes("M1.SIG"))).toBe(true)
})

// 目的: 両端以外の使用済みの穴に近づきすぎるワイヤを検出すること。45 度直線に限らない。
test("近接を検出する", () => {
  const layout = minimal()
  // N7 から N9 まで真横に伸ばすと、途中の N8（SW1.pin2 の穴）の中心を通ってしまう。
  layout.wires.push({ from: "N7", to: "N9", net: "BTN", side: "solder" })
  expect(layout.wires.some((w) => w.net === "BTN" && w.to === "N9")).toBe(true)
  expect(verifyLayout(layout).some((p) => p.includes("近接"))).toBe(true)
})

// 目的: 被覆線（insulated）は他の穴に近づいても短絡しないので、近接の対象外にすること。
test("被覆線は近接の対象外", () => {
  const layout = minimal()
  layout.wires.push({ from: "N7", to: "N9", net: "BTN", side: "solder", insulated: true })
  expect(verifyLayout(layout).some((p) => p.includes("近接"))).toBe(false)
})

// 目的: 同じ電気ノードのランドは近接の対象外にすること。裸線が触れても短絡しないので、
// 実測後に配置を詰めたときの誤検出を防ぐ。
test("同じネットのランドは近接扱いしない", () => {
  const layout = minimal()
  // O8 のランドを BTN の島へ繋いだうえで、その真上を BTN の裸線 O7→O9 が通る。
  layout.legs["TP1.pin1"] = "O8"
  layout.wires.push({ from: "O7", to: "N7", net: "BTN", side: "solder" })
  layout.wires.push({ from: "O8", to: "O7", net: "BTN", side: "solder" })
  layout.wires.push({ from: "O7", to: "O9", net: "BTN", side: "solder" })
  expect(verifyLayout(layout).some((p) => p.includes("近接"))).toBe(false)
})

// 目的: 十分離れた斜めのワイヤは咎めないこと。
test("穴から十分離れた斜めのワイヤは近接扱いしない", () => {
  const layout = minimal()
  // 列が 1、行が 2 動く斜め線は、途中のどの使用済み穴からも 0.5 グリッド単位以上離れる。
  layout.wires.push({ from: "N7", to: "L8", net: "BTN", side: "solder" })
  expect(verifyLayout(layout).some((p) => p.includes("近接"))).toBe(false)
})

// 目的: 裏面で異なるネットの裸線同士が端点を共有せずに交差したら検出すること。
test("交差を検出する", () => {
  const layout = minimal()
  // BTN（N7→L8）と GND（N8→L7）は端点を共有せずに X 字に交差する。
  layout.wires.push({ from: "N7", to: "L8", net: "BTN", side: "solder" })
  layout.wires.push({ from: "N8", to: "L7", net: "GND", side: "solder" })
  expect(verifyLayout(layout).some((p) => p.includes("交差"))).toBe(true)
})

// 目的: 片方でも被覆線なら交差を咎めないこと。
test("被覆線は交差の対象外", () => {
  const layout = minimal()
  layout.wires.push({ from: "N7", to: "L8", net: "BTN", side: "solder", insulated: true })
  layout.wires.push({ from: "N8", to: "L7", net: "GND", side: "solder" })
  expect(verifyLayout(layout).some((p) => p.includes("交差"))).toBe(false)
})

// 目的: 端点を共有する 2 本（同じ穴で継ぐだけの配線）は交差扱いしないこと。
test("端点を共有する線は交差扱いしない", () => {
  const layout = minimal()
  layout.wires.push({ from: "N7", to: "L8", net: "BTN", side: "solder" })
  layout.wires.push({ from: "L8", to: "N9", net: "GND", side: "solder" })
  expect(verifyLayout(layout).some((p) => p.includes("交差"))).toBe(false)
})

// 目的: グリッドの外を指す穴 ID を検出すること。実測でグリッドが小さかった場合の保険。
test("範囲外の穴を検出する", () => {
  const layout = minimal()
  layout.legs["D1.R"] = "Z1" // 行 Z（26）は ROWS を大きく超える
  expect(verifyLayout(layout).some((p) => p.includes("範囲外") && p.includes("Z1"))).toBe(true)
})
