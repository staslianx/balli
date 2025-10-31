# Deep Research Observatory (`research-xray` / `balli-x`)

```
█████               ████  ████   ███
░░███               ░░███ ░░███  ░░░
 ░███████   ██████   ░███  ░███  ████
 ░███░░███ ░░░░░███  ░███  ░███ ░░███
 ░███ ░███  ███████  ░███  ░███  ░███
 ░███ ░███ ███░░███  ░███  ░███  ░███
 ████████ ░░████████ █████ █████ █████
░░░░░░░░   ░░░░░░░░ ░░░░░ ░░░░░ ░░░░░
```

**X-ray visibility into Balli's deep research pipeline**

A comprehensive CLI tool that provides complete observability into every stage of the Balli research flow, from query routing to final synthesis, with beautiful visualizations, detailed metrics, and debugging capabilities.

## Features

- 🔬 **Complete Pipeline Visibility**: See every stage, decision, and API call
- 📊 **Real-time Progress**: Live updates as research progresses
- 💰 **Cost & Token Tracking**: Detailed breakdown of costs and token usage
- 🎯 **Bottleneck Identification**: Automatically identifies performance bottlenecks
- 📝 **Multiple Export Formats**: JSON, Markdown, and HTML reports
- 🔄 **Replay Mode**: Replay and analyze past research sessions
- 🎨 **Beautiful CLI**: Color-coded, well-organized terminal output
- ⚡ **Interactive Commands**: Explore sources, citations, and metrics post-research

## Installation

```bash
cd cli-tool
npm install
npm run build
```

## Quick Start

### 1. Start Firebase Emulator

First, ensure your Firebase Functions emulator is running:

```bash
cd ../functions
npm run serve
```

### 2. Run Research Observatory

```bash
# Interactive mode (default)
npm run dev

# Or use the alias (after npm link)
balli-x

# With specific query
npm run dev -- --query "Metformin yan etkileri derinlemesine araştır"
balli-x --query "Metformin yan etkileri derinlemesine araştır"

# Verbose mode
npm run dev -- --verbose
balli-x --verbose

# Replay saved session
npm run dev -- replay ./research-logs/research_2025-01-31_14-23-45.json
balli-x replay ./research-logs/research_2025-01-31_14-23-45.json
```

**Note:** To use `balli-x` globally, run `npm link` in the cli-tool directory first.

## Usage

### Interactive Mode

The default mode guides you through entering a query and displays real-time progress:

```bash
$ npm run dev

┌────────────────────────────────────────────────────┐
│                                                    │
│   🔬 Deep Research Observatory                     │
│   Balli Research Pipeline X-Ray Tool               │
│                                                    │
└────────────────────────────────────────────────────┘

📝 Enter your research query (Turkish): Metformin yan etkileri derinlemesine araştır

🎯 Starting research journey...

✓ Tier 3 selected (confidence: 0.98)
✓ Planning complete
✓ Round 1 complete: 25 sources
✓ Round 2 complete: 15 sources
✓ Research complete!
```

### Command-Line Options

```bash
# Specify query directly
npm run dev -- --query "Your research question"

# Use custom config file
npm run dev -- --config ./my-config.json

# Verbose output (shows all source details)
npm run dev -- --verbose

# Specify user ID
npm run dev -- --user-id custom-user-123
```

### Replay Mode

Replay and analyze past research sessions:

```bash
npm run dev -- replay ./research-logs/research_2025-01-31_14-23-45.json
```

## Configuration

Create a `research-xray.config.json` file in your current directory or home directory:

```json
{
  "firebaseFunctions": {
    "emulator": true,
    "emulatorUrl": "http://127.0.0.1:5001/balli-health/us-central1/diabetesAssistantStream",
    "projectId": "balli-health",
    "region": "us-central1"
  },
  "display": {
    "colorScheme": "default",
    "verbosity": "normal",
    "showTimestamps": true,
    "showCosts": true,
    "showTokens": true
  },
  "export": {
    "autoSave": true,
    "outputDir": "./research-logs",
    "formats": ["json", "markdown"]
  }
}
```

See `research-xray.config.example.json` for a complete example.

## Interactive Commands

After research completes, use these commands to explore results:

- **`v`** - View full response
- **`s`** - Show all sources with details
- **`t`** - Token/cost breakdown by stage
- **`r`** - Run another query
- **`e`** - Export to different format
- **`q`** - Quit

## Output Stages

The tool displays these stages in order:

### 1. Query Input & Analysis
- Original query
- Language detection
- Timestamp and metadata

### 2. Router Decision
- Tier selection (0-3)
- Reasoning and confidence
- Token usage and cost

### 3. Research Planning (T3 only)
- Strategy and focus areas
- Estimated rounds
- Planning reasoning

### 4. Research Rounds
- API calls (PubMed, medRxiv, ClinicalTrials, Exa)
- Source retrieval progress
- Real-time status updates

### 5. Gap Analysis (T3 only)
- Coverage analysis
- Gap identification
- Decision to continue or stop

### 6. Response Synthesis
- Model and parameters
- Token streaming
- Final response generation

### 7. Summary
- Total time and cost
- Token usage breakdown
- Bottleneck identification
- Recommendations

## Export Formats

### JSON Export
Complete raw data for programmatic analysis:
```json
{
  "query": { ... },
  "routing": { ... },
  "rounds": [ ... ],
  "synthesis": { ... },
  "summary": { ... }
}
```

### Markdown Export
Human-readable report with:
- Executive summary
- Stage-by-stage details
- Performance metrics tables
- Recommendations

## Example Output

```
┌─ 🎯 ROUTER DECISION ─────────────────────────────────────┐
│ Model: gemini-2.0-flash-lite                              │
│                                                            │
│ Tier Analysis:                                            │
│   Tier 0 (Recall): ❌                                     │
│   Tier 1 (Model): ❌                                      │
│   Tier 2 (Hybrid): ❌                                     │
│   Tier 3 (Deep): ✅ SELECTED                             │
│                                                            │
│ Reasoning:                                                │
│   "Kullanıcı 'derinlemesine araştır' dedi, bu Pro        │
│    model + 25 kaynak gerektiriyor."                      │
│                                                            │
│ 📊 Tokens: 45 input | 120 output                         │
│ 💰 Cost: $0.000008                                        │
│ ⏱️  Latency: 340ms                                        │
└────────────────────────────────────────────────────────────┘

🚀 Routing to Tier 3: 🔬 Deep Research
```

## Debugging Features

The tool helps answer these questions:

1. ✅ Why did router choose this tier?
2. ✅ How many rounds were executed and why?
3. ✅ Why was source X excluded/included?
4. ✅ Where are the bottlenecks?
5. ✅ How can I reduce costs?
6. ✅ Which APIs are underperforming?
7. ✅ Are gaps being detected correctly?
8. ✅ Is synthesis using the best sources?

## Architecture

```
cli-tool/
├── src/
│   ├── index.ts                 # Main CLI entry point
│   ├── collectors/
│   │   └── research-interceptor.ts  # SSE event capture
│   ├── visualizers/
│   │   └── stage-visualizer.ts      # Terminal rendering
│   ├── exporters/
│   │   ├── json-exporter.ts         # JSON export
│   │   └── markdown-exporter.ts     # Markdown export
│   ├── types/
│   │   └── research-journey.ts      # TypeScript interfaces
│   ├── config/
│   │   └── config-loader.ts         # Configuration management
│   └── utils/
│       └── colors.ts                # Color utilities
├── research-logs/               # Auto-generated reports
├── package.json
└── tsconfig.json
```

## Integration with Firebase Functions

The tool wires into the production research flow by:

1. **Intercepting SSE Events**: Listens to Server-Sent Events from `diabetesAssistantStream`
2. **Capturing All Data**: Records routing decisions, API calls, sources, and synthesis
3. **Real-time Visualization**: Displays progress as events stream in
4. **Post-processing**: Analyzes bottlenecks and generates recommendations

## Troubleshooting

### Firebase Emulator Not Running
```bash
Error: connect ECONNREFUSED 127.0.0.1:5001

Solution: Start the Firebase emulator first:
cd ../functions && npm run serve
```

### Permission Denied
```bash
Error: EACCES: permission denied

Solution: Ensure research-logs directory is writable:
mkdir -p ./research-logs
chmod 755 ./research-logs
```

### TypeScript Compilation Errors
```bash
Solution: Rebuild the project:
npm run build
```

## Development

### Build and Run

```bash
# Development mode with auto-reload
npm run dev

# Build production version
npm run build

# Run production version
npm start
```

### Testing

```bash
# Run tests
npm test

# Watch mode
npm run test:watch
```

## Roadmap

- [x] Basic SSE interception and visualization
- [x] Multi-round research tracking
- [x] Export to JSON and Markdown
- [x] Interactive command system
- [x] Bottleneck identification
- [ ] Citation verification
- [ ] HTML dashboard export
- [ ] Cost what-if calculator
- [ ] Source comparison tool
- [ ] Ranking sensitivity analyzer
- [ ] API call replay system

## Contributing

This tool is part of the Balli health app ecosystem. For questions or contributions, see the main project repository.

## License

MIT

---

**Built with ❤️ for debugging and optimizing the Balli research pipeline**
