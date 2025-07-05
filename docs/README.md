# Documentation Index

Welcome to the ABL TouchOSC documentation. This guide will help you find the information you need.

## 📚 User Documentation

### Getting Started
- **[README.md](../README.md)** - Project overview, features, and quick start guide
- **[User Guide](../README.md#-user-guide)** - How to use the controls
- **[Troubleshooting](../README.md#-troubleshooting)** - Common issues and solutions

## 🔧 Technical Documentation

### System Architecture
- **[Technical Documentation](TECHNICAL.md)** - Detailed technical information
- **[Script Reference](TECHNICAL.md#core-components)** - Individual script documentation
- **[OSC Reference](TECHNICAL.md#osc-reference)** - OSC message formats

### Development
- **[Contributing Guidelines](CONTRIBUTING.md)** - How to contribute to the project
- **[TouchOSC Lua Rules](../rules/touchosc-lua-rules.md)** - Critical TouchOSC knowledge
- **[AbletonOSC Meter Calibration](../rules/abletonosc-meter-calibration.md)** - Meter calibration reference

## 📋 Additional Resources

### Technical Analysis
- **[Notify Usage Analysis](notify-usage-analysis.md)** - Inter-script communication patterns
- **[Performance Optimization](performance-optimization-phases.md)** - Performance improvement strategies
- **[Performance Issues Reference](performance-issues-quick-reference.md)** - Quick troubleshooting guide

### Implementation Details
- **[Return Track Issue Documentation](abletonosc-return-track-issue.md)** - AbletonOSC return track support

## 🗂️ Documentation Structure

```
docs/
├── README.md                             # This index file
├── TECHNICAL.md                          # Technical documentation
├── CONTRIBUTING.md                       # Contributing guidelines
├── notify-usage-analysis.md              # Script communication analysis
├── performance-optimization-phases.md    # Performance strategies
├── performance-issues-quick-reference.md # Quick fixes
├── abletonosc-return-track-issue.md     # Return track details
└── archive/                              # Historical development docs
    ├── README.md                         # Archive index
    ├── moved-files.md                    # File relocation log
    └── [various phase docs]              # Development history
```

## 🔍 Quick Links

### For Users
1. Start with the [README](../README.md)
2. Follow the [Quick Start](../README.md#-quick-start)
3. Check [Troubleshooting](../README.md#-troubleshooting) if needed

### For Developers
1. Read [Contributing Guidelines](CONTRIBUTING.md)
2. Study the [Technical Documentation](TECHNICAL.md)
3. Understand [TouchOSC Rules](../rules/touchosc-lua-rules.md)
4. Review [Script Communication](notify-usage-analysis.md)

### For Production Setup
1. Complete testing with DEBUG = 0 in all scripts
2. Verify all features working as expected
3. Use the release version from the main branch

---

**Current Version:** v1.3.0 with group registration system  
**Latest Update:** Fixed refresh button track renumbering issue  
**Need help?** Open an issue on GitHub with your question!