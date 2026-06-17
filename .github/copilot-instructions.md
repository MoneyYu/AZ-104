# AZ-104 Reference — Copilot 指引

> **語言:** 繁體中文優先（見下方語言慣例）。

## 這個 repo 是什麼

Microsoft **AZ-104（Azure Administrator）講師授課用參考 repo**，由 MTC 講師維護（GitHub: `MoneyYu/AZ-104`，預設分支 `master`）。
**這不是應用程式專案** — 沒有套件管理、build pipeline 或單元測試。產出是「教材」：學員參考頁、上課現場 demo 腳本，以及備課用的 Terraform demo 環境。

## 架構（大局，需跨檔閱讀才看得懂）

**M01–M11 模組結構是整個 repo 的骨幹，並在多個檔案中鏡像**。改任一處的模組結構，務必同步檢查其他鏡像：

| 位置 | 角色 |
|------|------|
| `README.md` | 學員面向、已發佈到 HackMD 的參考頁：YAML front-matter + `:::success/:::info/:::warning` admonition + 每個 `## M01`–`## M11` 模組的精選 Microsoft Learn 連結 + 結尾的 ` ```markmap ` 心智圖（心智圖內再次重複 M01–M11 標題）。 |
| `LAB.md` | 每個模組的 lab 影片表。 |
| `QUICK-LINKS.md` | 上課即時用的極簡每模組連結清單。 |
| `DEMO/ModuleXX/` | 現場 demo 腳本：PowerShell（`.ps1`）、Azure CLI（`.azcli`）、ARM 範本（`.json`）。 |
| `TERRAFORM/MOD0X.tf` | 每個 lab 對應一組 Terraform 資源（檔名對應模組）。 |
| `CUSTOMER/` | 客戶專屬筆記（繁中 Markdown）。 |

**Terraform 是「備課 backup 環境」**：`MAIN.tf`（provider + variable + locals + resource group，全部以 `var.group_postfix` 為 key）＋ 各 `MOD0X.tf`（資源）。目標是一鍵建立完整 lab 環境供現場 demo。

## 驗證與指令

沒有應用程式 build/test。唯一可驗證的是 **Terraform**：

```powershell
cd TERRAFORM
terraform fmt        # 格式化
terraform validate   # 語法/型別檢查
terraform plan       # 預覽變更
```

- ⛔ **絕對不要執行 `terraform apply`**（也避免 `destroy`）。其餘 terraform 指令皆可執行。
- README / 連結變更不需 build/test；但每個外部連結加入前要先確認可用（HTTP 200）。

## Terraform 慣例

- azurerm provider `~> 4.0`，使用 4.x 語法。
- 命名：resource group = `AZ104-${var.group_postfix}`；資源 = `${local.labXX_name}-<type>-${local.random_str}`（`random_str` 目前是 `"cat"`）。`location` 定義在 `locals`。
- 共用標籤用 `local.default_tags`（含 `SecurityControl = "Ignore"`）。
- 每個 `azurerm_public_ip` 都要 `lifecycle { ignore_changes = [ip_tags] }` — 訂閱會自動注入 `FirstPartyUsage` ip_tag，否則 plan 會強制重建。
- VPN gateway 只能用 **AZ SKU**（例 `VpnGw3AZ`）；非 AZ 的 `VpnGw1-5` 已不允許。
- 檔名後綴有語意：`MOD09D-issue.tf`（已知有問題）、`MOD11-deprecated.tf`（已淘汰）保留作參考 — 動它們前先確認意圖。
- 租戶政策：Storage / Cognitive Services / AI Search 一律 **Entra ID（AAD）驗證 + RBAC，不可用 access key**。

## 語言與內容慣例

- **繁體中文優先**；不要新增簡體中文（唯一允許的是頂部「简体中文版本」課程連結 label）。
- `## M01`–`## M11` 模組標題必須**逐字保留**，並在 README / LAB.md / QUICK-LINKS.md / DEMO / TERRAFORM 之間鏡像一致。
- README 心智圖只放 **AZ-104 課程／Skills Measured 範圍內**的內容，不加課程以外的東西。
- README 是學員面向：保持 admonition、front-matter，以及 Date／Course ID／survey／Skillable key 等 metadata 正確。
- `PPT/` 是 IRM/DRM 加密課件，已被 `.gitignore` 排除 — 不要發佈或嘗試解密。

## Commit 慣例

Conventional Commits、**英文撰寫**：`type(scope): description` ＋ body。type 優先從 `feat / fix / refactor / docs / style / test / chore` 選；新功能用 `feat`，對已提交功能的修正用 `fix`（先看 `git log` 判斷）。詳見 `.github/instructions/commit.instructions.md`。

## 其他指引與工具

- 進一步分項指引：`.github/instructions/general.instructions.md`、`terraform.instructions.md`、`commit.instructions.md`。
  - ⚠️ `testing.instructions.md` 與 `code-review.instructions.md` 是別的 TypeScript/Vue 專案留下的範本，**與本 repo 無關**，可忽略。
- 備課（準備課程）請使用 `.github/skills/course-prep` skill。
- `.mcp.json` 已設定 Microsoft Learn、Context7、Playwright、Chrome DevTools MCP server。

## 自我審查流程

完成後請自我審查，確認是否滿意；若不滿意，持續修正直到百分之百滿意為止。