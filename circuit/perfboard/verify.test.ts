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

// 目的: 両端以外の使用済みの穴をまたぐワイヤを検出すること。
test("またぎを検出する", () => {
  const layout = minimal()
  // N7 から N9 まで真横に伸ばすと、途中の N8（SW1.pin2 の穴）を通ってしまう。
  layout.wires.push({ from: "N7", to: "N9", net: "BTN", side: "solder" })
  expect(layout.wires.some((w) => w.net === "BTN" && w.to === "N9")).toBe(true)
  expect(verifyLayout(layout).some((p) => p.includes("またぎ"))).toBe(true)
})

// 目的: 穴の中心を通らない斜めのワイヤは咎めないこと。
test("45度でない斜めのワイヤはまたぎ扱いしない", () => {
  const layout = minimal()
  // 列が 1、行が 2 動く斜め線は、行・列・45 度のどれでもないので穴の中心を通らない。
  layout.wires.push({ from: "N7", to: "L8", net: "BTN", side: "solder" })
  expect(verifyLayout(layout).some((p) => p.includes("またぎ"))).toBe(false)
})
