# beads-note-append

[English](README.md) ｜ 繁體中文

**在不覆寫既有內容的前提下，把文字附加進 beads（`bd`）issue 的 notes 欄位。**
單一 bash 檔案，沒有第三方依賴（只需要 `bd` 與標準的 `python3` 來解析 JSON）。

## 為什麼會有這個工具

`bd update <id> --notes "..."` 是**整份覆寫**，不是附加。當 AI agent 或自動化腳本把進度筆記寫進長期存在的任務卡時，一個「覆寫」動詞可能只靠一則簡短的更新，就悄悄抹掉累積長達數千字元的任務歷史。真正的問題從來不是某個特定指令長什麼樣子，而是「覆寫」本身就是預設動詞。這個工具把「附加」變成唯一的動詞，而且寫完還會檢查結果。

## 60 秒快速上手

```bash
# 1. get the script (single file: copy it anywhere on your PATH)
git clone https://github.com/walkpod1007/beads-note-append.git && cd beads-note-append
chmod +x bd-note-append.sh

# 2. try it with no real beads at all (uses a fake `bd`)
bash examples/demo.sh

# 3. use it for real (requires beads installed; or test without install via BD_BIN=examples/bd-stub)
./bd-note-append.sh proj-42 "tried approach B, failed on the auth step"
echo "multi-line
note" | ./bd-note-append.sh proj-42 -
./bd-note-append.sh proj-42 - < progress.txt
```

輸出：`proj-42: notes 120 -> 171 chars (appended 50)`。

## 這個工具做了什麼

1. 執行 `bd show <id> --json`，讀出目前的 `notes`。
2. 用 `bd update <id> --notes ...` 寫入「舊內容 + `"\n"` + 新內容」。
3. 重新讀一次卡片。如果 notes **變短了**，就以 exit 5 結束並在 stderr 說明——代表發生了覆寫，你現在就該去看，不要拖到下週。

它還會擋下三種原本會「成功」、卻把垃圾寫進卡片裡的參數誤用：

| 誤用方式 | 沒有這道防呆時的症狀 |
|---|---|
| `tool <id> /tmp/note.txt` | *路徑字串本身*被當成 note 附加進去 |
| `tool <id> --file note.txt` | `--file` 被當成 note 附加進去，真正的路徑反而被丟掉 |
| `tool <id> "text" extra` | `extra` 會被悄悄忽略 |

要附加檔案內容請用 stdin：`tool <id> - < note.txt`。

## 與 `bd update --append-notes` 的關係

近期版本的 `bd` 內建了原生的 `--append-notes` 旗標。如果你的 `bd` 有這個旗標，單純的附加動作應該優先用它。這支包裝腳本仍然有它的價值：當你需要參數形狀的防呆檢查（路徑／`--option`／多餘參數這類「看起來會成功」的誤用）、寫入後的變短檢查，或是你的 `bd` 版本沒有原生旗標時。它刻意不去呼叫 `--append-notes` 本身，這樣它的行為在各個 `bd` 版本之間才會保持一致。

## 設定

| 變數 | 預設值 | 說明 |
|---|---|---|
| `BD_BIN` | `bd` | beads 執行檔（測試時可指向 `examples/bd-stub`） |
| `BD_WORKDIR` | 目前目錄 | 執行 `bd` 的工作目錄（你的 `.beads` workspace 所在位置） |

結束碼：`0` 正常 · `2` 用法錯誤 · `3` `bd show` 失敗 · `4` `bd update` 失敗 · `5` notes 變短了。

## 測試

```bash
bash tests/run.sh    # exit 0 = pass; uses examples/bd-stub, touches no real data
```

## 限制

- **不是併發安全的。** 這是讀取－修改－寫回的模式。兩個寫入者在同一瞬間對同一張卡附加內容，可能會遺失其中一則筆記（變短檢查抓不到這種情況，因為結果依然比原本長）。如果這對你很重要，請把寫入者序列化。
- 路徑／選項的防呆是啟發式規則：如果真正的筆記內容剛好是單一個 token，例如 `docs/plan.md`，會被拒絕。這時請多加一個詞，或改用 stdin。
- 需要 `bd show --json` 回傳一個物件、或是一個只有一個元素且帶有 `notes` 欄位的清單。
- 因為是整欄位寫入，非常大的 notes 每次附加都會整份重新送出一次。

## 授權條款

MIT — 詳見 `LICENSE`。
