# beads-note-append

**Append to a beads (`bd`) issue's notes without ever overwriting them.**
One bash file, no third-party dependencies (needs `bd` and a stock `python3` for JSON parsing).

## Why this exists

`bd update <id> --notes "..."` is a **full replace**, not an append. When AI agents
or automated scripts write progress notes into long-lived task cards, a replace
verb can silently wipe accumulated task history spanning thousands of characters with a single
short update note. The real problem was never the shape of any specific command, it was
that "replace" is the default verb. This tool makes "append" the only verb, and checks the
result.

## 60-second quickstart

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

Output: `proj-42: notes 120 -> 171 chars (appended 50)`.

## What it does

1. Runs `bd show <id> --json` and reads the current `notes`.
2. Writes `old + "\n" + new` with `bd update <id> --notes ...`.
3. Re-reads the card. If the notes are **shorter** than before, exits 5 and says so on stderr —
   an overwrite happened and you should look now, not next week.

It also refuses three argument mistakes that otherwise "succeed" and put garbage in the card:

| Mistake | Symptom without the guard |
|---|---|
| `tool <id> /tmp/note.txt` | the *path string* is appended as the note |
| `tool <id> --file note.txt` | `--file` is appended as the note, the path is dropped |
| `tool <id> "text" extra` | `extra` is silently ignored |

To append a file's contents use stdin: `tool <id> - < note.txt`.

## Relationship to `bd update --append-notes`

Recent `bd` versions ship a native `--append-notes` flag. If your `bd` has it, prefer it for plain appends. This wrapper still
earns its place where you want the argument-shape guards (path / `--option` / extra-arg mistakes that "succeed"), the
post-write shrink check, or `bd` versions without the native flag. It deliberately does not call `--append-notes`
itself, so that behavior is identical across `bd` versions.

## Configuration

| Variable | Default | Meaning |
|---|---|---|
| `BD_BIN` | `bd` | the beads executable (point it at `examples/bd-stub` to test) |
| `BD_WORKDIR` | current dir | directory to run `bd` in (where your `.beads` workspace lives) |

Exit codes: `0` ok · `2` bad usage · `3` `bd show` failed · `4` `bd update` failed · `5` notes shrank.

## Tests

```bash
bash tests/run.sh    # exit 0 = pass; uses examples/bd-stub, touches no real data
```

## Limitations

- **Not concurrency-safe.** It is read-modify-write. Two writers appending to the same card at
  the same instant can lose one of the two notes (the shrink check does not catch this, since
  the result is still longer than the original). Serialize writers if that matters.
- The path/option guards are heuristics: a real note that is a single token such as
  `docs/plan.md` will be refused. Add a second word or use stdin.
- Needs `bd show --json` to return an object or a one-element list with a `notes` field.
- Whole-field write means very large notes are re-sent in full on every append.

## License

MIT — see `LICENSE`.

---

## 中文摘要

`bd update --notes` 是**整份覆寫**，不是追加。這支單檔 bash 把「追加」變成唯一的動詞：先讀舊 notes、
串上新文字再寫回，寫完重讀，若 notes 反而變短就以 exit 5 大聲報錯。另外擋掉三種「看起來成功、
其實寫進垃圾」的參數誤用（傳檔案路徑、傳 `--file`、多餘參數）。要追加檔案內容請用 stdin：
`tool <id> - < note.txt`。限制：讀改寫非併發安全；路徑判斷是啟發式；需要 `bd` 與標準庫 `python3`。
`bash examples/demo.sh` 可用假 `bd` 直接體驗，`bash tests/run.sh` 一鍵測試。
