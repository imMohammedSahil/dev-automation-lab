# 🚀 Pair Extraordinaire Achievement Automation Sandbox

This sandbox repository provides an automated workflow to safely unlock and level up the **Pair Extraordinaire** achievement badge on your GitHub profile.

---

## 🎖️ Badge Tier Reference

| Tier | Required Merged Co-Authored PRs |
| :--- | :---: |
| 🥉 **Bronze (x1)** | **1 PR** |
| 🥈 **Silver (x2)** | **10 PRs** |
| 🥇 **Gold (x3 / Max)** | **24 PRs** |

---

## ⚙️ How It Works

1. **Compliant Git Trailers**: Every commit includes the exact Git trailer format required by GitHub's badge verification engine:
   ```git
   Co-authored-by: github-actions[bot] <41898282+github-actions[bot]@users.noreply.github.com>
   ```
2. **Branch & PR Lifecycle**: The runner creates a feature branch, commits an entry, opens a PR against `main`, and uses `gh pr merge --merge` to preserve commit history and trailers intact.
3. **Paced Execution**: Employs rate-limit protection delays between each cycle.

---

## 🛠️ Usage Instructions

### Step 1: Log in to GitHub CLI (One-time)
```powershell
gh auth login
```
*(Select `GitHub.com` -> `HTTPS` -> `Paste an authentication token` or `Login with a web browser`)*

### Step 2: Run the Automation
To unlock the **Gold Tier** (24 PRs):
```powershell
.\run-pair-extraordinaire.ps1 -Tier Gold
```

Or target a specific tier:
```powershell
# Bronze (1 PR)
.\run-pair-extraordinaire.ps1 -Tier Bronze

# Silver (10 PRs)
.\run-pair-extraordinaire.ps1 -Tier Silver
```

---

## 🔍 Verification & Post-Run Steps

1. **Verify Badges on GitHub Profile**:
   - Go to `https://github.com/<your-username>`
   - Check the **Achievements** section on the left sidebar.
   - Note: GitHub achievements usually update within 5–15 minutes after the PRs are merged.
2. **Archive or Retain**:
   - Keep the repository active for at least 24–48 hours until GitHub calculates your badge status.
   - You can leave it as a public archive or delete it afterwards once the badge is permanently displayed on your profile.
