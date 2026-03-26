Closing this PR because the approach is not the right one.

Instead of implementing a custom review workflow, we should use GitHub's **built-in Copilot Code Review** feature, which can be enabled directly via a Repository Ruleset — no Actions workflow or extra tokens needed.

**How to enable it:**
1. Go to **Settings** → **Rules** → **Rulesets** → **New branch ruleset**
2. Set target branches (e.g. default branch)
3. Under **Branch rules**, enable ✅ **Automatically request Copilot code review**
4. Save the ruleset

Once configured, GitHub will automatically add Copilot as a reviewer on every pull request, using the native Copilot Code Review agent — which produces much higher quality reviews than a custom CLI-based solution.

**Issues with this PR's approach:**
- Reimplements review logic manually using Copilot CLI + a Python script
- Requires a `COPILOT_REVIEW_TOKEN` secret (unnecessary with the native approach)
- 242 lines of complex, fragile workflow code with polling and timeout logic
- Review quality is inferior to the native Copilot Code Review agent

Reference: [Configuring automatic code review by GitHub Copilot](https://docs.github.com/en/copilot/how-tos/use-copilot-agents/request-a-code-review/configure-automatic-review)