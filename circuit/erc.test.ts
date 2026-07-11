import { expect, test } from "bun:test"
import { runErc } from "./erc"

// テスト用に circuit JSON 断片を組む小さなヘルパ
const comp = (id: string, name: string) => ({
  type: "source_component", source_component_id: id, name,
})
const port = (id: string, comp: string, name: string, key: string) => ({
  type: "source_port", source_port_id: id, source_component_id: comp, name,
  subcircuit_connectivity_map_key: key,
})
// 接続キーを持たない（未接続）ポート
const unconnectedPort = (id: string, comp: string, name: string) => ({
  type: "source_port", source_port_id: id, source_component_id: comp, name,
})
const net = (id: string, name: string, key: string) => ({
  type: "source_net", source_net_id: id, name, subcircuit_connectivity_map_key: key,
})

// 必須ネット 3 本・各 2 端点・ショート無しの最小健全回路
const good = () => [
  comp("c0", "U1"), comp("c1", "M1"), comp("c2", "Q1"),
  net("n0", "V5", "k0"), port("p0", "c0", "VBUS", "k0"), port("p1", "c1", "VPLUS", "k0"),
  net("n1", "GND", "k1"), port("p2", "c0", "GND", "k1"), port("p3", "c2", "S", "k1"),
  net("n2", "SERVO_RTN", "k2"), port("p4", "c1", "GND", "k2"), port("p5", "c2", "D", "k2"),
]

test("健全な回路はエラー 0", () => {
  expect(runErc(good())).toEqual([])
})

test("浮きピン（未接続ポート）を検出", () => {
  const cj = [...good(), unconnectedPort("p6", "c2", "G")]
  const errs = runErc(cj)
  // 意図したルールだけが発火する（他の誤検出が混ざらない）ことも保証する
  expect(errs).toHaveLength(1)
  expect(errs[0]).toContain("Q1.G is not connected")
})

test("allowUnconnected の未接続ピンは許容", () => {
  const cj = [...good(), unconnectedPort("p6", "c2", "G")]
  expect(runErc(cj, { allowUnconnected: ["Q1.G"] })).toEqual([])
})

test("孤立ネット（端点 1 つ）を検出", () => {
  const cj = [...good(), net("n3", "BTN", "k3"), port("p6", "c0", "GP3", "k3")]
  const errs = runErc(cj)
  expect(errs).toHaveLength(1)
  expect(errs[0]).toContain("net BTN has fewer than 2 endpoints")
})

test("ショート（1 グループに 2 ネット）を検出", () => {
  // GND を V5 と同じ接続キー k0 に同居させる
  const cj = good().map((e) =>
    e.type === "source_net" && e.name === "GND"
      ? { ...e, subcircuit_connectivity_map_key: "k0" }
      : e,
  )
  const errs = runErc(cj)
  expect(errs).toHaveLength(1)
  expect(errs[0]).toContain("short")
  expect(errs[0]).toContain("V5")
  expect(errs[0]).toContain("GND")
})

test("必須ネット欠落を検出", () => {
  // SERVO_RTN ネットだけ削除。ポート p4/p5 は接続キー k2 を持ったまま残るが、
  // 孤立ネット判定は nets を対象にするため追加エラーは出ず、エラーは必須ネット欠落の 1 件のみ。
  const cj = good().filter((e) => !(e.type === "source_net" && e.name === "SERVO_RTN"))
  const errs = runErc(cj)
  expect(errs).toHaveLength(1)
  expect(errs[0]).toContain("required net SERVO_RTN is missing")
})
