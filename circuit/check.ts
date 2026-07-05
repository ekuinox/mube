// 導通・ショート ERC の CLI エントリ。`bun check.ts` で本番配線を描画して ERC を回し、
// 違反があれば stderr に出して exit 1、無ければ exit 0。
// 描画・ロジックは netlist.tsx / erc.ts 側にあり、ここは実行と終了コードだけを担う。
// （bun 直接実行の判定を含む実行部を netlist.tsx から分離し、tsci dev のブラウザ eval が
//  netlist.tsx を評価しても落ちないようにするための切り出し。）
import { ercRealBoard } from "./netlist"

const errors = await ercRealBoard()
if (errors.length) {
  for (const e of errors) console.error(`ERC: ${e}`)
  process.exit(1)
}
console.log("ERC passed: 導通 OK / ショート無し")
