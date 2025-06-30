# Contributing to ABL TouchOSC

Thank you for your interest in contributing to the ABL TouchOSC project! This guide will help you understand our development process and standards.

## 🚀 Getting Started

### Prerequisites
- TouchOSC Editor
- Ableton Live with AbletonOSC
- Git and GitHub account
- Basic understanding of Lua scripting

### Development Setup
1. Fork the repository
2. Clone your fork
3. Create a feature branch: `git checkout -b feature/your-feature-name`
4. Make your changes
5. Test thoroughly
6. Submit a pull request

## 📋 Development Standards

### Version Management
Every code change requires a version increment:
- **PATCH (x.x.Z)**: Bug fixes, minor improvements
- **MINOR (x.Y.x)**: New features, significant enhancements  
- **MAJOR (X.x.x)**: Breaking changes, architectural updates

Example progression:
- Bug fix: `1.2.3` → `1.2.4`
- New feature: `1.2.4` → `1.3.0`
- Major refactor: `1.9.0` → `2.0.0`

### Script Standards

#### Version Logging
All scripts must log their version on initialization:
```lua
local VERSION = "1.0.0"

function init()
    log("Script v" .. VERSION .. " loaded")
end
```

#### Logging Format
Use centralized logging through root:notify:
```lua
local function log(message)
    local context = "SCRIPT_NAME"
    if self.parent and self.parent.name then
        context = "SCRIPT_NAME(" .. self.parent.name .. ")"
    end
    root:notify("log_message", context .. ": " .. message)
end
```

#### Script Isolation
- Scripts cannot share variables or functions
- Each script must be completely self-contained
- Read configuration directly in each script
- Communication only via notify() system

### Code Style

#### Lua Conventions
- Use local variables whenever possible
- Clear, descriptive variable names
- Comment complex logic
- Consistent indentation (2 spaces)

#### Error Handling
Always validate before accessing properties:
```lua
if self.parent and self.parent.tag then
    -- Safe to access self.parent.tag
end
```

## 🧪 Testing Requirements

### Before Submitting
1. **Test all changes** with actual hardware/software
2. **Provide logs** showing the feature works
3. **Verify version numbers** appear in logs
4. **Check multi-connection** scenarios
5. **Ensure no visual corruption**

### Test Log Requirements
Logs must show:
- Script version on startup
- Feature working correctly
- No errors or warnings
- Expected behavior confirmed

Example:
```
06:16:47 Document Script v2.7.1 loaded
06:16:48 === AUTOMATIC STARTUP REFRESH ===
06:16:48 CONTROL(band_CG #) Mapped to Track 39
```

## 📝 Documentation

### Update Requirements
- Update README.md for user-facing changes
- Update CHANGELOG.md with version details
- Update relevant documentation in /docs
- Keep examples current

### Documentation Style
- Clear, concise language
- Include code examples
- Explain the "why" not just "what"
- Use proper markdown formatting

## 🌿 Git Workflow

### Branch Naming
- `feature/description` - New features
- `fix/issue-description` - Bug fixes
- `docs/update-description` - Documentation only
- `refactor/component-name` - Code refactoring

### Commit Messages
- Use present tense: "Add feature" not "Added feature"
- Be specific: "Fix fader double-tap at -inf" not "Fix bug"
- Reference issues: "Fix #123: Meter color threshold"

### Pull Request Process
1. Create PR as soon as you start work
2. Update PR description as you progress
3. Request review when ready
4. Address feedback promptly
5. Ensure all tests pass

## 🐛 Reporting Issues

### Good Issue Reports Include
- TouchOSC version
- Ableton Live version
- Clear description of the problem
- Steps to reproduce
- Expected vs actual behavior
- Relevant log output

### Issue Template
```markdown
**Environment:**
- TouchOSC: [version]
- Ableton Live: [version]
- OS: [Windows/Mac/Linux]

**Description:**
[Clear description of the issue]

**Steps to Reproduce:**
1. [First step]
2. [Second step]
3. [etc...]

**Expected Behavior:**
[What should happen]

**Actual Behavior:**
[What actually happens]

**Logs:**
```
[Relevant log output]
```
```

## 🎯 Development Priorities

Current focus areas:
1. **Stability**: Ensure all features work reliably
2. **Performance**: Optimize for smooth operation
3. **Usability**: Improve user experience
4. **Documentation**: Keep docs current and helpful

## 📚 Resources

### Key Documentation
- [TouchOSC Scripting Guide](https://hexler.net/touchosc/manual/script)
- [AbletonOSC Documentation](https://github.com/ideoforms/AbletonOSC)
- [Project Technical Rules](rules/touchosc-lua-rules.md)

### Development Tools
- TouchOSC Editor for layout changes
- Console logging for debugging
- Git for version control

## 🤝 Code of Conduct

- Be respectful and constructive
- Welcome newcomers
- Focus on what's best for users
- Assume good intentions
- Ask questions when unsure

## 📄 License

By contributing, you agree that your contributions will be licensed under the same license as the project (MIT).

---

**Questions?** Feel free to open an issue for clarification or join the discussion!

Thank you for helping make ABL TouchOSC better! 🎉