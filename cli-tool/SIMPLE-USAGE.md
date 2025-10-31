# ⚡ Simple Usage Guide - Just Type `balli-x`!

## ✅ Setup Complete!

You can now use `balli-x` from **anywhere** on your system!

---

## 🚀 Quick Commands

### Start a Research Session
```bash
balli-x
```

That's it! Just type `balli-x` and hit enter. The tool will:
1. Show the beautiful purple "balli" logo
2. Ask you to enter a research query
3. Run the research and show you everything

---

## 🎯 Common Usage Patterns

### Interactive Mode (Recommended)
```bash
balli-x
```
Then enter your query when prompted.

### Direct Query (Skip the Prompt)
```bash
balli-x --query "Metformin yan etkileri araştır"
```

### Verbose Mode (See All Details)
```bash
balli-x --verbose
```

### Replay a Saved Session
```bash
balli-x replay ./research-logs/research_2025-01-31_14-23-45.json
```

---

## 📝 Example Queries

### Quick Answer (Tier 1 - ~2 seconds)
```bash
balli-x --query "A1C nedir?"
```

### Web Research (Tier 2 - ~5 seconds)
```bash
balli-x --query "Metformin yan etkileri araştır"
```

### Deep Research (Tier 3 - ~30-60 seconds)
```bash
balli-x --query "Metformin kardiyovasküler etkileri derinlemesine araştır"
```

---

## ⚠️ Important: Firebase Emulator Must Be Running!

**Before running `balli-x`, start the Firebase emulator in another terminal:**

```bash
cd /Users/serhat/SW/balli/functions
npm run serve
```

Wait for this message:
```
✔  functions: Emulator started at http://127.0.0.1:5001
```

Then in any other terminal, just type:
```bash
balli-x
```

---

## 🎨 What You'll See

When you run `balli-x`, you'll see:

```
█████               ████  ████   ███
░░███               ░░███ ░░███  ░░░
 ░███████   ██████   ░███  ░███  ████
 ░███░░███ ░░░░░███  ░███  ░███ ░░███
 ░███ ░███  ███████  ░███  ░███  ░███
 ░███ ░███ ███░░███  ░░███  ░███  ░███
 ████████ ░░████████ █████ █████ █████
░░░░░░░░   ░░░░░░░░ ░░░░░ ░░░░░ ░░░░░

╔════════════════════════════════════════════╗
║   🔬 Deep Research Observatory             ║
║   Balli Research Pipeline X-Ray Tool       ║
╚════════════════════════════════════════════╝

📝 Enter your research query (Turkish): _
```

---

## 🔧 If Something Goes Wrong

### "Command not found: balli-x"
```bash
cd /Users/serhat/SW/balli/cli-tool
npm link
```

### "Connection refused"
Start the Firebase emulator:
```bash
cd /Users/serhat/SW/balli/functions
npm run serve
```

### Code Changes
If you modify the code, rebuild:
```bash
cd /Users/serhat/SW/balli/cli-tool
npm run build
```

---

## 🎉 That's It!

No need to think about npm, build steps, or directories.

Just type:
```bash
balli-x
```

And start researching! ✨

---

**Pro Tip:** Add this to your shell profile for even faster access:
```bash
alias bx='balli-x'
```

Then you can just type `bx` instead of `balli-x`! 🚀
