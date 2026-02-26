# Comprehensive Analysis: Memory and Sensitive Files in Version Control

**Research Date:** 2026-02-04  
**Context:** OpenClaw workspace memory management and Git security  
**Objective:** Determine best practices for handling memory files (MEMORY.md, memory/YYYY-MM-DD.md) and sensitive data in Git repositories

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Git Security Best Practices](#git-security-best-practices)
3. [Encryption Solutions Comparison](#encryption-solutions-comparison)
4. [Exclusion Strategies (.gitignore)](#exclusion-strategies-gitignore)
5. [Pre-commit Hooks & Secret Detection](#pre-commit-hooks--secret-detection)
6. [History Rewriting Tools](#history-rewriting-tools)
7. [GDPR & Privacy Considerations](#gdpr--privacy-considerations)
8. [Real-World Configuration Examples](#real-world-configuration-examples)
9. [Recommended Strategy for Memory Files](#recommended-strategy-for-memory-files)
10. [Implementation Checklist](#implementation-checklist)

---

## Executive Summary

### Key Findings

**The Core Problem:**
- Memory files contain personal conversations, diary entries, and technical logs
- MEMORY.md contains curated long-term memories (personal context, not for strangers)
- memory/YYYY-MM-DD.md daily logs may include sensitive personal information
- Technical memory files (opencode-*.md) may be safe to version control
- **Risk:** Accidentally committing sensitive data exposes it permanently in Git history

### Recommended Multi-Layered Approach

1. **.gitignore** - Primary defense: Exclude personal memory files entirely
2. **Pre-commit hooks** - Secondary defense: Scan for accidental inclusions
3. **Encryption (optional)** - Tertiary defense: Encrypt if partial versioning needed
4. **Retention policies** - GDPR compliance: Define what stays, what gets purged
5. **Emergency procedures** - git-filter-repo ready if secrets leak

**Critical Insight:** Once data enters Git history, consider it compromised. Prevention > remediation.

---

## Git Security Best Practices

### Core Principles from GitHub Documentation

1. **Never commit secrets to repositories** - Even private repos are not secure storage
2. **Use GitHub Secret Scanning** - Detects exposed tokens automatically (public repos + Enterprise)
3. **Implement Push Protection** - Blocks commits containing known secret patterns
4. **Rotate compromised credentials immediately** - Any leaked secret must be revoked
5. **Coordinate with collaborators** - History rewrites require team coordination

### Best Practices for Preventing Data Leaks

**From GitHub's "Best Practices for Preventing Data Leaks" (2025):**

- **Use .gitignore proactively** - Before first commit, identify sensitive file patterns
- **Implement pre-commit hooks** - Automated scanning before commits reach the server
- **Review staging area** - Always check `git diff --staged` before committing
- **Separate repositories** - Keep sensitive configs in separate, private repos with strict access
- **Audit regularly** - Periodic scans of entire repository history

### GitHub Secret Protection Features

**Secret Scanning Coverage:**
- Public repositories: FREE automatic scanning
- Private repositories: Requires GitHub Team/Enterprise with Secret Protection enabled
- Detects 200+ token types from major providers (AWS, Azure, GCP, GitHub, etc.)
- Partner programs auto-revoke detected credentials

**Push Protection:**
- Blocks pushes containing detected secrets
- Developer receives immediate feedback at push time
- Can bypass with justification (audit trail maintained)

---

## Encryption Solutions Comparison

### Overview of Tools

Four major open-source solutions for encrypting files in Git:

1. **git-crypt** - Transparent encryption via Git filters (C++ with OpenSSL)
2. **transcrypt** - Transparent encryption with better performance (bash + OpenSSL)
3. **git-secret** - Manual encryption workflow (asymmetric GPG keys)
4. **SOPS** - Structured data encryption (YAML/JSON values only, not keys)

### Detailed Comparison

#### 1. git-crypt

**How it works:**
- Uses `.gitattributes` filters: files automatically encrypt on commit, decrypt on checkout
- Encryption: AES-256 (symmetric) or GPG (asymmetric)
- Transparent: once configured, encryption is invisible to workflow

**Pros:**
- ✅ Transparent workflow (automatic encrypt/decrypt)
- ✅ Per-user access control via GPG keys
- ✅ Selective file encryption (via .gitattributes patterns)
- ✅ Mature project (10+ years, 9.4k GitHub stars)
- ✅ No plaintext in Git history

**Cons:**
- ❌ **Easy to accidentally commit unencrypted** - Pattern mistakes in .gitattributes bypass encryption
- ❌ Cannot encrypt entire repo (needs .gitattributes unencrypted)
- ❌ Rebase/merge conflicts can leave files in inconsistent state
- ❌ No negation patterns - can't "encrypt everything except X"
- ❌ C++ implementation - potential for security bugs

**Best for:** Teams needing shared access to encrypted config files (API keys, certificates)

**Example .gitattributes:**
```gitattributes
# Encrypt all files in secrets directory
secrets/** filter=git-crypt diff=git-crypt

# Encrypt specific config files
.env.production filter=git-crypt diff=git-crypt
credentials.json filter=git-crypt diff=git-crypt
```

**Setup:**
```bash
# Initialize git-crypt
git-crypt init

# Add GPG users
git-crypt add-gpg-user USER_GPG_KEY_ID

# Unlock repository (after clone)
git-crypt unlock
```

---

#### 2. transcrypt

**How it works:**
- Similar to git-crypt but implemented in bash
- Uses OpenSSL directly with AES-256-CBC
- Transparent encryption via Git filters

**Pros:**
- ✅ Faster than git-crypt (simpler implementation)
- ✅ Transparent workflow
- ✅ Pure bash - easier to audit
- ✅ Can re-key repository (change encryption password)
- ✅ Better performance on large files

**Cons:**
- ❌ Single symmetric key (no per-user access control)
- ❌ Same .gitattributes pitfalls as git-crypt
- ❌ Password must be shared out-of-band
- ❌ Less mature than git-crypt

**Best for:** Solo developers or small teams with shared symmetric key

---

#### 3. git-secret

**How it works:**
- **Manual** encryption workflow (NOT transparent)
- Files stored encrypted, must run `git secret reveal` to decrypt
- Uses GPG for asymmetric encryption

**Pros:**
- ✅ Explicit workflow prevents accidental plaintext commits
- ✅ Per-user GPG keys (granular access control)
- ✅ Can revoke user access
- ✅ Works with standard GPG tooling

**Cons:**
- ❌ Manual process (must remember to encrypt before commit)
- ❌ Plaintext files in working directory (can still be committed by mistake)
- ❌ Requires GPG key management infrastructure
- ❌ Workflow friction (developers must run commands manually)

**Best for:** High-security environments where explicit encrypt/decrypt is preferred

**Workflow:**
```bash
# Initialize
git secret init

# Add user
git secret tell user@example.com

# Add file to be encrypted
git secret add secrets/api_keys.env

# Encrypt all registered files
git secret hide

# Decrypt (after clone)
git secret reveal
```

---

#### 4. SOPS (Secrets OPerationS) - **RECOMMENDED**

**How it works:**
- Encrypts **values** in structured files (YAML, JSON, ENV, INI)
- Keys remain plaintext for easy diff/merge
- Supports multiple key management backends (AWS KMS, GCP KMS, Azure Key Vault, age, GPG)

**Pros:**
- ✅ **Most flexible** - Multiple KMS backends (cloud or local)
- ✅ **Best diff experience** - Only values encrypted, keys visible
- ✅ **Granular encryption** - Can specify which fields to encrypt
- ✅ **Mature ecosystem** - Used by Kubernetes (FluxCD), Ansible, Terraform
- ✅ **Audit trail** - Integrates with cloud KMS logging
- ✅ **Rotation-friendly** - Re-encrypt with new keys without changing files
- ✅ **20.6k GitHub stars** - Most popular solution

**Cons:**
- ❌ Only for structured data (not binary files or arbitrary text)
- ❌ Requires external KMS setup (age, GPG, or cloud provider)
- ❌ **Manual workflow** - Not transparent like git-crypt
- ❌ Learning curve for KMS concepts

**Best for:** Modern DevOps workflows with structured config files

**Example YAML (encrypted with SOPS):**
```yaml
# .sops.yaml config
creation_rules:
  - path_regex: \.secrets\.yaml$
    age: age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p

# secrets.yaml (after SOPS encryption)
database:
  host: localhost  # Plaintext key
  password: ENC[AES256_GCM,data:abc123...,iv:def456...,tag:ghi789...]  # Encrypted value
api_keys:
  stripe: ENC[AES256_GCM,data:xyz...]
```

**Workflow:**
```bash
# Edit encrypted file (automatically decrypts, re-encrypts on save)
sops secrets.yaml

# Encrypt new file
sops -e secrets.plaintext.yaml > secrets.yaml

# Decrypt to stdout
sops -d secrets.yaml
```

**Comparison with Alternatives (from research):**

**SOPS vs git-crypt/transcrypt:**
- SOPS: Explicit workflow, better for structured data, cloud-native
- git-crypt: Transparent but risky (.gitattributes mistakes), better for binary files

**SOPS vs git-secret:**
- Both manual workflows
- SOPS: Better diff/merge experience (keys visible)
- git-secret: All-or-nothing encryption

**SOPS Key Management Options:**

1. **age** (recommended for local/small teams)
   - Lightweight, modern encryption (replacement for GPG)
   - Simple key format: `age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p`
   
2. **GPG** (traditional)
   - Works with existing GPG infrastructure
   - Per-user keys
   
3. **AWS KMS / GCP KMS / Azure Key Vault** (enterprise)
   - Centralized key management
   - Audit logs
   - IAM-based access control

---

### Encryption Recommendation Matrix

| Use Case | Recommended Tool | Why |
|----------|-----------------|-----|
| **Structured config files** (YAML, JSON, ENV) | **SOPS** | Best diff experience, flexible KMS, cloud-native |
| **Binary secrets** (certificates, keystores) | **git-crypt** | Transparent workflow, handles binary |
| **Solo developer, simple setup** | **transcrypt** | Fast, simple, single symmetric key |
| **High-security compliance** | **SOPS + AWS KMS** | Audit trail, centralized access control |
| **Legacy GPG infrastructure** | **git-secret** | Explicit workflow, uses existing GPG keys |

**For Memory Files Specifically:**
- **Not recommended** - Memory files are unstructured Markdown with personal diary content
- Encryption adds complexity without solving the core problem (personal vs technical separation)
- Better approach: **Complete exclusion via .gitignore** for personal memories

---

## Exclusion Strategies (.gitignore)

### How .gitignore Works

**Three levels of ignore patterns:**

1. **Repository-level:** `.gitignore` (committed to repo, shared with team)
2. **Global-level:** `~/.gitignore_global` (user-specific, all repos)
3. **Local-level:** `.git/info/exclude` (repo-specific, not committed)

### Pattern Syntax

```gitignore
# Comments start with #

# Ignore specific file
MEMORY.md

# Ignore all files with extension
*.log

# Ignore directory and all contents
memory/

# Ignore files in any subdirectory
**/*.tmp

# Negate pattern (exception)
!important.log

# Ignore files only in root
/config.local

# Exclude everything except specific directory
/*
!/technical-memory
/technical-memory/*
!/technical-memory/opencode-*.md
```

### Selective Exclusion for Memory Files

**Strategy 1: Exclude all memory files**
```gitignore
# Exclude all memory files (personal and technical)
MEMORY.md
memory/
```

**Strategy 2: Exclude personal, include technical**
```gitignore
# Exclude personal long-term memory
MEMORY.md

# Exclude daily logs (personal diary)
memory/

# EXCEPT: Include technical memory files
!memory/opencode-*.md
!memory/technical-*.md
```

**Strategy 3: Separate directories**
```gitignore
# Personal memories (NEVER commit)
personal-memory/

# Technical memories (OK to commit) - not in .gitignore
# technical-memory/
```

### Handling Already-Tracked Files

**Problem:** `.gitignore` only affects untracked files. If a file is already committed, adding it to `.gitignore` does nothing.

**Solution:** Remove from Git tracking (but keep local file):

```bash
# Remove from Git but keep local file
git rm --cached MEMORY.md
git rm --cached -r memory/

# Commit the removal
git commit -m "Remove memory files from version control"

# Add to .gitignore
echo "MEMORY.md" >> .gitignore
echo "memory/" >> .gitignore

# Commit .gitignore
git commit -m "Add memory files to .gitignore"
```

### Advanced Pattern: Exclude Directory Except Specific Files

**Use case:** Exclude all memory/*.md except opencode-*.md

```gitignore
# Exclude entire memory directory
memory/*

# Re-include specific technical files
!memory/opencode-*.md
!memory/.gitkeep
```

**Warning:** This only works at the same directory level. If `memory/` is excluded, you cannot re-include `memory/subfolder/file.md`.

**Workaround:** Use nested .gitignore files:

```bash
# Root .gitignore
# (empty or exclude other things)

# memory/.gitignore
*
!opencode-*.md
!.gitignore
```

---

## Pre-commit Hooks & Secret Detection

### Why Pre-commit Hooks?

**Defense-in-depth principle:**
- .gitignore can fail (typos, pattern mistakes, `git add -f`)
- Humans make mistakes (forgetting to check staged files)
- Pre-commit hooks provide **automated enforcement**

### Tool Comparison: Gitleaks vs detect-secrets

#### 1. Gitleaks (Recommended for Most Use Cases)

**What it does:**
- Scans commits for hardcoded secrets (API keys, passwords, tokens, private keys)
- Uses regex patterns + entropy analysis
- Detects 200+ secret types

**Pros:**
- ✅ **Fast** - Written in Go, scans entire repos in seconds
- ✅ **Pre-configured** - Works out-of-the-box with sensible defaults
- ✅ **CI/CD friendly** - Designed for automated pipelines
- ✅ **Low false positive rate** - Entropy detection reduces noise
- ✅ **24.8k GitHub stars** - Most popular secret scanner

**Cons:**
- ❌ No baseline file (rescanning always checks entire commit)
- ❌ Less customizable than detect-secrets

**Installation:**
```bash
# macOS
brew install gitleaks

# Linux
wget https://github.com/gitleaks/gitleaks/releases/download/v8.18.0/gitleaks_8.18.0_linux_x64.tar.gz
tar -xzf gitleaks_8.18.0_linux_x64.tar.gz
sudo mv gitleaks /usr/local/bin/
```

**Usage:**
```bash
# Scan staged changes (pre-commit)
gitleaks protect --staged

# Scan entire repository history
gitleaks detect

# Scan with custom config
gitleaks protect --config .gitleaks.toml --staged
```

**Custom config (.gitleaks.toml):**
```toml
# Exclude specific paths
[allowlist]
paths = [
  ".*test.*",
  ".*README.md"
]

# Custom rule for memory files
[[rules]]
id = "memory-file-personal-info"
description = "Detect personal information in memory files"
regex = '''(password|api[_-]?key|secret|token)[\s:=]+["']?[A-Za-z0-9]{16,}["']?'''
path = '''memory/.*\.md'''
```

---

#### 2. detect-secrets (Yelp)

**What it does:**
- Scans for secrets using plugin-based architecture
- Uses **baseline file** concept - tracks known secrets to ignore

**Pros:**
- ✅ **Baseline file** - Can ignore known secrets, scan only for new ones
- ✅ **Plugin architecture** - Custom secret detectors via Python API
- ✅ **Enterprise-friendly** - Designed for gradual adoption in existing codebases
- ✅ **Low false positives** - Audited baseline reduces noise
- ✅ **Doesn't scan Git history** - Fast on large repos

**Cons:**
- ❌ Requires initial baseline scan (setup friction)
- ❌ Python dependency (slower than Gitleaks)
- ❌ Less actively maintained than Gitleaks

**Installation:**
```bash
pip install detect-secrets
```

**Setup:**
```bash
# Create baseline (scan current state)
detect-secrets scan > .secrets.baseline

# Scan for new secrets
detect-secrets scan --baseline .secrets.baseline

# Audit baseline (mark false positives)
detect-secrets audit .secrets.baseline
```

**Pre-commit hook (.pre-commit-config.yaml):**
```yaml
repos:
  - repo: https://github.com/Yelp/detect-secrets
    rev: v1.4.0
    hooks:
      - id: detect-secrets
        args: ['--baseline', '.secrets.baseline']
```

---

### Pre-commit Framework Setup

**Best practice:** Use [pre-commit.com](https://pre-commit.com) framework to manage hooks.

**Installation:**
```bash
# macOS/Linux
pip install pre-commit

# Initialize in repo
pre-commit install
```

**Configuration (.pre-commit-config.yaml):**
```yaml
repos:
  # Gitleaks - Secret scanning
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.18.0
    hooks:
      - id: gitleaks
        name: Detect secrets with gitleaks
        description: Scan for hardcoded secrets (passwords, API keys, tokens)
        args: ["--config", ".gitleaks.toml"]

  # Standard checks
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.5.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-added-large-files
        args: ['--maxkb=1000']
      - id: check-merge-conflict
      
  # Custom hook - Block personal memory files
  - repo: local
    hooks:
      - id: block-memory-files
        name: Block personal memory files
        entry: bash -c 'if git diff --cached --name-only | grep -E "^MEMORY\.md$|^memory/[0-9]{4}-[0-9]{2}-[0-9]{2}\.md$"; then echo "ERROR: Personal memory files cannot be committed. Use .gitignore."; exit 1; fi'
        language: system
        pass_filenames: false
```

**Run hooks manually:**
```bash
# Run on staged files
pre-commit run

# Run on all files
pre-commit run --all-files

# Bypass hooks (emergency use only)
git commit --no-verify
```

---

### Recommended Hook Strategy for Memory Files

**Multi-layer defense:**

1. **Gitleaks** - Detect secrets in all files
2. **Custom path blocker** - Explicitly block MEMORY.md and memory/*.md
3. **Large file checker** - Prevent accidental commits of large logs
4. **Merge conflict checker** - Prevent committing conflict markers

**.pre-commit-config.yaml (Complete Example):**
```yaml
repos:
  # Secret detection
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.18.0
    hooks:
      - id: gitleaks
        args: ["--staged", "--redact"]

  # Custom memory file blocker
  - repo: local
    hooks:
      - id: block-personal-memory
        name: Block personal memory files
        entry: |
          bash -c '
          FILES=$(git diff --cached --name-only)
          if echo "$FILES" | grep -qE "^MEMORY\.md$|^memory/[0-9]{4}-[0-9]{2}-[0-9]{2}\.md$"; then
            echo "❌ ERROR: Personal memory files detected:"
            echo "$FILES" | grep -E "^MEMORY\.md$|^memory/[0-9]{4}-[0-9]{2}-[0-9]{2}\.md$"
            echo ""
            echo "These files contain personal information and should not be committed."
            echo "Add them to .gitignore or use git reset to unstage."
            exit 1
          fi
          '
        language: system
        pass_filenames: false
        
  # General safety checks
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.5.0
    hooks:
      - id: check-added-large-files
        args: ['--maxkb=500']
      - id: check-merge-conflict
      - id: trailing-whitespace
        exclude: '\.md$'  # Allow trailing spaces in Markdown
```

---

## History Rewriting Tools

### Why You Need These

**The problem:**
- Developer accidentally commits `MEMORY.md` with personal conversations
- File is pushed to GitHub
- `git rm` removes it from latest commit, but **history still contains it**
- Anyone can checkout old commits or browse history on GitHub

**The solution:** Rewrite Git history to purge the file from all commits.

### Tool Comparison: git-filter-repo vs BFG Repo-Cleaner

#### 1. git-filter-repo (Recommended)

**What it does:**
- Official Git recommendation for history rewriting (replaces `git filter-branch`)
- Removes files, rewrites content, changes paths, filters commits

**Pros:**
- ✅ **Official Git tool** - Recommended in Git documentation
- ✅ **Fast** - 10x-100x faster than filter-branch
- ✅ **Powerful** - Python callbacks for complex rewrites
- ✅ **Safe** - Creates backup refs before rewriting
- ✅ **Flexible** - Path filtering, content replacement, commit filtering

**Cons:**
- ❌ Requires Python
- ❌ More complex than BFG for simple cases

**Installation:**
```bash
# macOS
brew install git-filter-repo

# Linux (via pip)
pip install git-filter-repo
```

**Common Use Cases:**

**Remove a file from entire history:**
```bash
# Remove MEMORY.md from all commits
git filter-repo --path MEMORY.md --invert-paths

# Remove entire directory
git filter-repo --path memory/ --invert-paths
```

**Replace sensitive strings:**
```bash
# Replace passwords/API keys
git filter-repo --replace-text <(echo 'PASSWORD123==>***REMOVED***')

# Replace multiple patterns (from file)
cat replacements.txt
api_key_123456==>***REDACTED***
secret_password==>***REDACTED***

git filter-repo --replace-text replacements.txt
```

**Extract specific files (keep only certain paths):**
```bash
# Keep only technical-memory/ directory
git filter-repo --path technical-memory/ --path README.md
```

**Important: Force push required after history rewrite:**
```bash
# ⚠️ WARNING: This rewrites history for all collaborators
git push --force origin main

# Better: Use lease to prevent overwriting others' work
git push --force-with-lease origin main
```

---

#### 2. BFG Repo-Cleaner

**What it does:**
- Simplified tool specifically for removing sensitive data
- User-friendly alternative to git-filter-repo

**Pros:**
- ✅ **Simple** - Easier syntax than git-filter-repo
- ✅ **Fast** - Optimized for large repos
- ✅ **Clear output** - Shows exactly what was removed
- ✅ **Safer** - Protects HEAD by default (only rewrites history)

**Cons:**
- ❌ Less flexible than git-filter-repo
- ❌ Requires Java runtime
- ❌ Not actively maintained (last update 2019)

**Installation:**
```bash
# macOS
brew install bfg

# Or download JAR
wget https://repo1.maven.org/maven2/com/madgag/bfg/1.14.0/bfg-1.14.0.jar
alias bfg='java -jar bfg-1.14.0.jar'
```

**Usage:**
```bash
# Clone repo with full history
git clone --mirror https://github.com/user/repo.git

# Remove file from history
bfg --delete-files MEMORY.md repo.git

# Replace text
bfg --replace-text passwords.txt repo.git

# Remove files larger than 100MB
bfg --strip-blobs-bigger-than 100M repo.git

# Clean up and push
cd repo.git
git reflog expire --expire=now --all
git gc --prune=now --aggressive
git push
```

---

### Emergency Response Procedure

**If a memory file with sensitive data is accidentally committed and pushed:**

#### Step 1: Assess the Damage

```bash
# Check if file was pushed
git log --all --full-history -- MEMORY.md

# See file contents in history
git show <commit-hash>:MEMORY.md
```

#### Step 2: Rotate Compromised Secrets

**CRITICAL: Assume any secrets in the committed file are compromised.**

- Change passwords
- Revoke API keys
- Regenerate tokens
- Notify affected parties (if personal data exposed)

#### Step 3: Rewrite History

**Using git-filter-repo:**
```bash
# Make a backup first
git clone --mirror https://github.com/user/repo.git repo-backup.git

# Remove the file
cd original-repo
git filter-repo --path MEMORY.md --invert-paths --force

# Verify removal
git log --all --full-history -- MEMORY.md  # Should show nothing

# Force push (requires admin access)
git push --force origin main
```

#### Step 4: Notify Collaborators

**Anyone with a local clone still has the sensitive data.**

Send notification:
```
⚠️ URGENT: Git history has been rewritten to remove sensitive data.

ACTION REQUIRED:
1. Delete your local clone
2. Re-clone from GitHub: git clone <url>
3. Do NOT push from old clones (history is incompatible)

Affected file: MEMORY.md (removed from history)
Reason: Contained sensitive personal information
```

#### Step 5: Cleanup

**GitHub doesn't immediately delete rewritten history (refs are cached).**

- Contact GitHub Support to purge cached refs
- Check Forks - History still exists in any forks
- Check CI/CD systems - May have cached checkouts

---

### Prevention > Remediation

**Key takeaway:** History rewriting is:
- Disruptive to collaborators
- Doesn't guarantee complete removal (forks, clones, caches)
- Should be a last resort

**Better approach:**
- Prevent commits with .gitignore
- Catch mistakes with pre-commit hooks
- Never commit sensitive data in the first place

---

## GDPR & Privacy Considerations

### Does GDPR Apply to Personal Memory Files?

**Short answer: Yes, if memory files contain personal data about EU residents.**

### What Constitutes Personal Data?

**GDPR Article 4(1) - Personal data includes:**
- Names, email addresses, IP addresses
- Identifiers (user IDs, session tokens)
- Location data
- **Any information relating to an identified or identifiable natural person**

**Examples in memory files:**
- "Had a conversation with John Doe about his medical condition"
- "User complained about issue, here's their email: user@example.com"
- "Meeting notes from call with Jane (Marketing Director at ACME Corp)"

**Even technical logs may contain personal data:**
- Git commit metadata (author name, email)
- Timestamps linked to individuals
- User behavior patterns

---

### Key GDPR Principles for Git Repositories

#### 1. Data Minimization (Article 5(1)(c))

**Principle:** Collect only what is necessary for the purpose.

**Application to memory files:**
- ❌ Don't commit: Personal diary entries about individuals
- ✅ Do commit: Anonymized technical notes ("User reported bug, steps: ...")
- ❌ Don't commit: "John's API key is abc123"
- ✅ Do commit: "API key format validation implemented"

**Recommendation:**
- Separate personal reflections from technical documentation
- Redact names before committing technical memory files
- Use pseudonyms or roles instead of real names

---

#### 2. Storage Limitation (Article 5(1)(e))

**Principle:** Keep personal data only as long as necessary.

**Application to Git history:**
- **Problem:** Git permanently stores all history
- **Issue:** Even deleted files remain in history
- **GDPR conflict:** Retention periods require eventual deletion

**Retention Policy Recommendations:**

| Data Type | Recommended Retention | Justification |
|-----------|---------------------|---------------|
| **Personal diary entries** | Local only, never commit | No business purpose, high privacy risk |
| **Technical memory (anonymized)** | Indefinite | Useful documentation, no personal data |
| **Daily logs with names** | 90 days (local), then purge | Short-term context, then anonymize |
| **Meeting notes with attendees** | 1 year, then redact names | Business need expires after project completion |

**Implementation:**
```bash
# Automated purge script (memory-retention.sh)
#!/bin/bash

# Delete daily logs older than 90 days
find memory/ -name "20*.md" -mtime +90 -delete

# Anonymize old technical logs (replace names with roles)
find technical-memory/ -name "*.md" -mtime +365 -exec sed -i \
  -e 's/John Doe/Developer A/g' \
  -e 's/jane@example\.com/user@redacted/g' \
  {} +

# Commit changes
git add -A
git commit -m "Automated: Anonymize and purge old memory files per GDPR retention policy"
```

---

#### 3. Right to Erasure (Article 17 - "Right to be Forgotten")

**Principle:** Individuals can request deletion of their personal data.

**Problem with Git:**
- Git history is immutable by design
- Removing data requires history rewriting (disruptive)
- Forks and clones still contain data

**GDPR Compliance Strategy:**

1. **Prevent collection** - Don't commit personal data to begin with (.gitignore)
2. **Document policy** - Privacy notice explains data handling
3. **Provide erasure process** - Document how to request removal
4. **Use git-filter-repo** - If removal requested, rewrite history and force push

**Sample Privacy Notice (for memory files):**
```markdown
# Privacy Notice: Memory Files

**Data Controller:** [Your Name/Organization]
**Purpose:** Personal memory files store reflections and notes for productivity purposes.

**What we collect:**
- MEMORY.md: Long-term curated memories (personal context, preferences)
- memory/YYYY-MM-DD.md: Daily logs (conversations, events, reflections)

**Storage:**
- Files stored LOCALLY ONLY (not committed to Git)
- Automatic deletion after 90 days (daily logs)
- Anonymization after 1 year (technical notes)

**Your rights:**
- Right to access: Request copy of your data
- Right to erasure: Request deletion of your information
- Right to rectification: Request corrections

**Contact:** privacy@example.com
```

---

#### 4. Privacy by Design (Article 25)

**Principle:** Build privacy protections into systems from the start.

**Application to memory files:**

**Design Decision Matrix:**

| Decision Point | Privacy-First Approach | Justification |
|----------------|----------------------|---------------|
| **Default behavior** | Memory files in .gitignore from day 1 | Prevents accidental exposure |
| **File structure** | Separate personal/ and technical/ directories | Clear segregation |
| **Pre-commit hooks** | Block personal memory files automatically | Technical enforcement |
| **Retention** | Auto-delete daily logs after 90 days | Storage limitation |
| **Access control** | MEMORY.md readable only by owner (chmod 600) | Minimize exposure risk |

**Implementation:**
```bash
# Set restrictive permissions on personal memory files
chmod 600 MEMORY.md
chmod 700 memory/

# Add to .gitignore
cat >> .gitignore << EOF
# Personal memory files (GDPR-sensitive, never commit)
MEMORY.md
memory/

# Technical memory (anonymized, safe to commit)
# technical-memory/ - NOT ignored
EOF

# Pre-commit hook installed by default
pre-commit install
```

---

### GDPR Compliance for Self-Hosted Git

**If running private Git server (GitLab, Gitea, Forgejo):**

#### Required Controls

1. **Access logs** - Track who accesses repositories with personal data
2. **Audit trail** - Log all commits containing personal data patterns
3. **Backup retention** - Backups must also follow retention periods
4. **Encryption at rest** - Disk encryption for Git storage
5. **Data breach procedures** - Plan for accidental exposure

**Example: GitLab GDPR Configuration**

```yaml
# gitlab.rb configuration
gitlab_rails['audit_events_enabled'] = true
gitlab_rails['backup_keep_time'] = 7776000  # 90 days

# Log personal data access
git_data_dirs({
  "default" => {
    "path" => "/var/opt/gitlab/git-data"
  }
})

# Enable GDPR-compliant logging
gitlab_rails['log_retention_days'] = 90
```

---

### Git Commits as Personal Data

**Issue:** Commit metadata contains personal data (author name, email).

**Example:**
```
commit abc123
Author: Jane Doe <jane.doe@example.com>
Date:   2026-02-04 10:30:00 +0000

    Fix memory retention bug
```

**GDPR Implications:**

- **Author email** - Personal data (directly identifiable)
- **Author name** - Personal data if real name
- **Timestamp** - Can reveal working hours (sensitive for some individuals)

**Mitigation Strategies:**

#### Option 1: Anonymize Commits (for public repos)
```bash
# Use pseudonym and no-reply email
git config user.name "OpenClaw Contributor"
git config user.email "12345+contributor@users.noreply.github.com"
```

#### Option 2: Redact History (for GDPR erasure requests)
```bash
# Replace author information in history
git filter-repo --name-callback 'return b"Redacted User"' \
                --email-callback 'return b"redacted@example.com"'
```

#### Option 3: Signed Commits Exception
- GDPR allows personal data if required for legal obligations
- Signed commits (GPG) prove authorship (non-repudiation)
- Document as "legitimate interest" under GDPR Article 6(1)(f)

---

### Checklist: GDPR-Compliant Memory Files

- [ ] Personal memory files excluded via .gitignore
- [ ] Pre-commit hooks block accidental commits
- [ ] Retention policy documented (90 days for daily logs)
- [ ] Automated purge script scheduled (cron job)
- [ ] Privacy notice created and accessible
- [ ] Anonymization process defined for technical logs
- [ ] Erasure procedure documented (git-filter-repo)
- [ ] Access controls on local memory files (chmod 600)
- [ ] Backup strategy includes retention limits
- [ ] Data breach response plan includes Git history cleanup

---

## Real-World Configuration Examples

### Example 1: Pre-commit Hook with Gitleaks

**From: Stirling-Tools/Stirling-PDF (GitHub)**

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.30.0
    hooks:
      - id: gitleaks
        name: Detect secrets with Gitleaks
        description: Scan for hardcoded secrets before commit
```

**Why it's effective:**
- ✅ Simple setup (one repo, one hook)
- ✅ Uses latest version (auto-updates)
- ✅ Clear naming (developers know what it does)

---

### Example 2: Custom Pre-commit Hook for Sensitive Files

**From: Agenta-AI/agenta (GitHub)**

```yaml
# .pre-commit-config.yaml
repos:
  - repo: local
    hooks:
      - id: gitleaks-pre-commit
        name: Gitleaks (staged files only)
        entry: bash -c 'gitleaks --config .gitleaks.toml --exit-code 1 --verbose git --staged'
        language: system
        pass_filenames: false
        
      - id: gitleaks-pre-push
        name: Gitleaks (pre-push, full diff)
        entry: bash -c 'gitleaks --config .gitleaks.toml --exit-code 1 --verbose git --log-opts "$(git merge-base HEAD origin/main)..HEAD"'
        language: system
        stages: [pre-push]
```

**Why it's effective:**
- ✅ Two-stage protection (pre-commit + pre-push)
- ✅ Pre-commit: Fast scan of staged changes
- ✅ Pre-push: Full diff scan before pushing to remote
- ✅ Custom config file (.gitleaks.toml) for project-specific rules

---

### Example 3: .gitignore for Sensitive Config Files

**From: Multiple GitHub projects (common pattern)**

```gitignore
# Secrets and credentials
.env
.env.local
.env.*.local
credentials.json
secrets.yaml

# Personal notes and memory files
MEMORY.md
memory/
notes/personal/

# Technical memory (ALLOWED to commit)
# technical-memory/ - explicitly NOT ignored

# IDE-specific (may contain sensitive workspace settings)
.vscode/settings.json
.idea/workspace.xml

# OS-specific (may contain local paths)
.DS_Store
Thumbs.db

# Logs (may contain personal data)
*.log
logs/
```

---

### Example 4: Git-crypt .gitattributes

**From: Real-world DevOps repositories**

```gitattributes
# .gitattributes - Encrypt sensitive files with git-crypt

# Encrypt all files in secrets/ directory
secrets/** filter=git-crypt diff=git-crypt

# Encrypt specific config files
.env.production filter=git-crypt diff=git-crypt
config/database.yml filter=git-crypt diff=git-crypt
config/credentials.yml.enc filter=git-crypt diff=git-crypt

# Encrypt SSL certificates
*.key filter=git-crypt diff=git-crypt
*.pem filter=git-crypt diff=git-crypt

# Do NOT encrypt (explicit exceptions)
secrets/README.md -filter -diff

# Binary files (handle specially)
*.pfx binary filter=git-crypt diff=git-crypt
```

**Setup commands:**
```bash
# Initialize git-crypt
git-crypt init

# Add GPG user
git-crypt add-gpg-user john.doe@example.com

# Lock (encrypt) repository
git-crypt lock

# Unlock (decrypt) repository
git-crypt unlock
```

---

### Example 5: SOPS Configuration

**From: Kubernetes GitOps repositories (FluxCD)**

```yaml
# .sops.yaml - SOPS configuration
creation_rules:
  # Encrypt all files matching pattern with age key
  - path_regex: \.secrets\.ya?ml$
    encrypted_regex: ^(data|stringData|password|apiKey|secret)$
    age: age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p
    
  # Production secrets with AWS KMS
  - path_regex: production/.*\.yaml$
    kms: 'arn:aws:kms:us-east-1:123456789012:key/abcd-1234'
    
  # Personal notes (different key)
  - path_regex: memory/technical-.*\.yaml$
    age: age1different_key_here
```

**Example encrypted file:**
```yaml
# memory/technical-2026-02-04.secrets.yaml
apiVersion: v1
kind: Secret
metadata:
  name: database-credentials
type: Opaque
data:
  username: YWRtaW4=  # Plaintext base64 (visible)
  password: ENC[AES256_GCM,data:Tr7o1...,iv:1234...,tag:5678...]  # Encrypted
sops:
  kms: []
  gcp_kms: []
  azure_kv: []
  age:
    - recipient: age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p
      enc: |
        -----BEGIN AGE ENCRYPTED FILE-----
        YWdlLWVuY3J5cHRpb24ub3JnL3YxCi0+IFgyNTUxOSB...
        -----END AGE ENCRYPTED FILE-----
  lastmodified: "2026-02-04T10:30:00Z"
```

---

### Example 6: Automated Retention Script

**Custom cron job for GDPR compliance:**

```bash
#!/bin/bash
# memory-retention.sh - Automated GDPR-compliant retention

REPO_DIR="/home/user/openclaw-workspace"
RETENTION_DAYS=90

cd "$REPO_DIR" || exit 1

# Log actions
LOG_FILE="$REPO_DIR/logs/memory-retention.log"
echo "[$(date -u +"%Y-%m-%d %H:%M:%S UTC")] Starting retention cleanup" >> "$LOG_FILE"

# Delete daily logs older than retention period
echo "Deleting daily logs older than $RETENTION_DAYS days..." >> "$LOG_FILE"
find memory/ -name "20*.md" -type f -mtime +$RETENTION_DAYS -print -delete >> "$LOG_FILE" 2>&1

# Anonymize technical logs older than 1 year
echo "Anonymizing technical logs older than 365 days..." >> "$LOG_FILE"
find technical-memory/ -name "*.md" -type f -mtime +365 | while read -r file; do
  echo "  Anonymizing: $file" >> "$LOG_FILE"
  
  # Replace common personal data patterns
  sed -i.bak \
    -e 's/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}/user@redacted.com/g' \
    -e 's/\b[A-Z][a-z]+ [A-Z][a-z]+\b/Redacted User/g' \
    "$file"
  
  rm "${file}.bak"
done

# Commit changes (if any)
if [[ -n $(git status --porcelain memory/ technical-memory/) ]]; then
  echo "Committing retention changes..." >> "$LOG_FILE"
  git add memory/ technical-memory/
  git commit -m "Automated: GDPR retention cleanup and anonymization

- Deleted daily logs older than $RETENTION_DAYS days
- Anonymized technical logs older than 1 year" >> "$LOG_FILE" 2>&1
fi

echo "[$(date -u +"%Y-%m-%d %H:%M:%S UTC")] Retention cleanup complete" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"
```

**Cron schedule:**
```cron
# Run retention cleanup every Sunday at 2 AM
0 2 * * 0 /home/user/openclaw-workspace/scripts/memory-retention.sh
```

---

## Recommended Strategy for Memory Files

### Situation Analysis

**Current state (OpenClaw workspace):**
- `MEMORY.md` - Long-term curated memories (personal context, not for strangers)
- `memory/YYYY-MM-DD.md` - Daily logs (may include personal conversations)
- Technical memory files (`opencode-*.md`) - May be safe to version control
- Some memory files contain sensitive personal information

**Requirements:**
- ✅ Exclude personal diary entries from GitHub
- ✅ Possibly include technical memories (sanitized)
- ✅ Protect any sensitive data in memory files
- ✅ Provide secure way to manage what gets version controlled
- ✅ GDPR compliance (retention, erasure, privacy by design)

---

### Recommended Multi-Layered Strategy

#### Layer 1: File Organization (Separation of Concerns)

**Create clear boundaries:**

```
openclaw-workspace/
├── MEMORY.md                    # ❌ NEVER commit (personal)
├── memory/                      # ❌ NEVER commit (personal daily logs)
│   ├── 2026-02-01.md
│   ├── 2026-02-02.md
│   └── ...
├── technical-memory/            # ✅ OK to commit (sanitized technical notes)
│   ├── opencode-2026-02.md
│   ├── project-architecture.md
│   └── debugging-notes.md
└── .gitignore                   # Configured to exclude personal files
```

**Why this works:**
- Clear separation: personal vs technical
- Easy to .gitignore (exclude entire directories)
- Intuitive for collaborators

---

#### Layer 2: .gitignore Configuration

**Add to `.gitignore`:**
```gitignore
###############################################################################
# Personal Memory Files (NEVER COMMIT - Contains personal information)
###############################################################################

# Long-term curated memories (personal context)
MEMORY.md

# Daily personal logs (conversations, reflections, diary)
memory/

# Local memory state files
memory/heartbeat-state.json

###############################################################################
# Technical Memory Files (OK to commit after sanitization)
###############################################################################

# Technical memory is in separate directory and NOT ignored:
# technical-memory/

# Temporary technical files (local only)
technical-memory/*.tmp
technical-memory/*.draft

###############################################################################
# Logs and Runtime Files (May contain personal data)
###############################################################################

# Log files
*.log
logs/

# Environment files (may contain secrets)
.env
.env.local
.env.*.local

# OS-specific files
.DS_Store
Thumbs.db
desktop.ini
```

**Commit this .gitignore immediately:**
```bash
git add .gitignore
git commit -m "Configure .gitignore to exclude personal memory files"
git push origin main
```

---

#### Layer 3: Pre-commit Hooks (Automated Enforcement)

**Install pre-commit framework:**
```bash
pip install pre-commit
```

**Create `.pre-commit-config.yaml`:**
```yaml
repos:
  # Secret detection with Gitleaks
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.18.0
    hooks:
      - id: gitleaks
        name: Detect secrets
        description: Scan for hardcoded secrets (API keys, passwords, tokens)
        args: ["--staged", "--redact", "--verbose"]

  # Custom hook: Block personal memory files
  - repo: local
    hooks:
      - id: block-personal-memory
        name: Block personal memory files
        entry: |
          bash -c '
          set -e
          BLOCKED_PATTERNS="^MEMORY\.md$|^memory/.*\.md$|^memory/heartbeat-state\.json$"
          
          STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACM)
          BLOCKED_FILES=$(echo "$STAGED_FILES" | grep -E "$BLOCKED_PATTERNS" || true)
          
          if [ -n "$BLOCKED_FILES" ]; then
            echo "❌ ERROR: Personal memory files detected in commit:"
            echo ""
            echo "$BLOCKED_FILES" | sed "s/^/  - /"
            echo ""
            echo "These files contain personal information and MUST NOT be committed."
            echo ""
            echo "To fix:"
            echo "  1. Unstage files: git reset HEAD MEMORY.md memory/"
            echo "  2. Verify .gitignore includes these patterns"
            echo "  3. If needed, add to .gitignore: echo \"MEMORY.md\" >> .gitignore"
            echo ""
            exit 1
          fi
          '
        language: system
        pass_filenames: false
        stages: [commit]

  # Custom hook: Sanitization check for technical memory
  - repo: local
    hooks:
      - id: check-technical-memory-sanitization
        name: Check technical memory sanitization
        entry: |
          bash -c '
          set -e
          TECH_MEMORY_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep "^technical-memory/.*\.md$" || true)
          
          if [ -n "$TECH_MEMORY_FILES" ]; then
            echo "⚠️  WARNING: Technical memory files detected:"
            echo ""
            echo "$TECH_MEMORY_FILES" | sed "s/^/  - /"
            echo ""
            echo "Please verify these files are sanitized:"
            echo "  ✓ No real names (use roles: \"Developer A\", \"User B\")"
            echo "  ✓ No email addresses"
            echo "  ✓ No API keys or secrets"
            echo "  ✓ No personal conversations"
            echo ""
            read -p "Files are sanitized? (y/n): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
              echo "❌ Commit aborted. Please sanitize files and try again."
              exit 1
            fi
          fi
          '
        language: system
        pass_filenames: false
        stages: [commit]

  # Standard checks
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.5.0
    hooks:
      - id: check-added-large-files
        args: ['--maxkb=1000']
      - id: check-merge-conflict
      - id: trailing-whitespace
        exclude: '\.md$'
      - id: end-of-file-fixer
        exclude: '\.md$'
```

**Install hooks:**
```bash
pre-commit install
pre-commit install --hook-type pre-push
```

**Test hooks:**
```bash
# Test on all files
pre-commit run --all-files

# Test on specific file
git add MEMORY.md
git commit -m "Test"  # Should be BLOCKED by hook
```

---

#### Layer 4: GDPR-Compliant Retention Policy

**Create automated retention script:**

**File: `scripts/memory-retention.sh`**
```bash
#!/bin/bash
# Automated GDPR-compliant retention for memory files

set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RETENTION_DAYS=90
LOG_FILE="$REPO_DIR/logs/memory-retention.log"

mkdir -p "$(dirname "$LOG_FILE")"

log() {
  echo "[$(date -u +"%Y-%m-%d %H:%M:%S UTC")] $*" | tee -a "$LOG_FILE"
}

log "=== Memory Retention Cleanup Started ==="

cd "$REPO_DIR" || exit 1

# Delete daily logs older than retention period
log "Deleting daily logs older than $RETENTION_DAYS days..."
DELETED_COUNT=$(find memory/ -name "20*.md" -type f -mtime +$RETENTION_DAYS -print -delete 2>&1 | tee -a "$LOG_FILE" | wc -l)
log "Deleted $DELETED_COUNT files"

# Anonymize old technical logs (1 year+)
log "Anonymizing technical logs older than 365 days..."
find technical-memory/ -name "*.md" -type f -mtime +365 | while read -r file; do
  log "  Anonymizing: $file"
  
  # Anonymization patterns
  sed -i.bak \
    -e 's/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}/user@redacted.com/g' \
    -e 's/\b([A-Z][a-z]+ ){1,2}[A-Z][a-z]+\b/Redacted User/g' \
    -e 's/password[=: ]\+[^ ]\+/password=***REDACTED***/gi' \
    -e 's/api[_-]key[=: ]\+[^ ]\+/api_key=***REDACTED***/gi' \
    "$file"
  
  rm -f "${file}.bak"
done

# Commit changes
if [[ -n $(git status --porcelain memory/ technical-memory/ 2>/dev/null) ]]; then
  log "Committing retention changes..."
  git add memory/ technical-memory/ 2>/dev/null || true
  git commit -m "Automated: GDPR retention cleanup

- Deleted daily logs older than $RETENTION_DAYS days
- Anonymized technical logs older than 1 year
- Compliance: GDPR Article 5(1)(e) - Storage Limitation" >> "$LOG_FILE" 2>&1 || true
fi

log "=== Memory Retention Cleanup Complete ==="
log ""
```

**Make executable:**
```bash
chmod +x scripts/memory-retention.sh
```

**Schedule with cron:**
```bash
crontab -e

# Add line:
0 2 * * 0 /home/user/openclaw-workspace/scripts/memory-retention.sh
```

---

#### Layer 5: Privacy Documentation

**Create `PRIVACY.md`:**
```markdown
# Privacy Policy: Memory Files

**Last Updated:** 2026-02-04

## Overview

This repository uses memory files to store notes and reflections. This policy explains how personal data is handled.

## Data Categories

### Personal Memory Files (Never Committed)

- **MEMORY.md**: Long-term curated memories (personal preferences, context)
- **memory/YYYY-MM-DD.md**: Daily logs (conversations, events, reflections)

**Storage:** LOCAL ONLY (excluded via .gitignore)
**Retention:** 90 days (daily logs), indefinite (MEMORY.md, user-managed)
**Access:** File owner only (chmod 600)

### Technical Memory Files (May Be Committed)

- **technical-memory/**: Sanitized technical documentation

**Storage:** Git repository (GitHub)
**Retention:** Indefinite (or until no longer needed)
**Sanitization:** Names, emails, and secrets redacted before commit

## Your Rights (GDPR)

### Right to Access
Request copy of your data: Contact repository owner

### Right to Erasure ("Right to be Forgotten")
1. Request deletion via issue or email
2. Data will be removed via git-filter-repo
3. History rewrite will be force-pushed within 30 days

### Right to Rectification
Request corrections via pull request or issue

## Data Protection Measures

1. **.gitignore**: Prevents accidental commits
2. **Pre-commit hooks**: Automated enforcement
3. **Encryption at rest**: Disk encryption enabled
4. **Access control**: File permissions (chmod 600)
5. **Retention automation**: Scheduled cleanup script

## Data Breach Response

If personal data is accidentally committed:

1. Immediate notification (within 24 hours)
2. History rewrite via git-filter-repo
3. Force push to remove data
4. GitHub support contacted to purge caches
5. Affected individuals notified

## Contact

**Data Controller:** [Your Name]  
**Email:** privacy@example.com  
**Response Time:** Within 30 days
```

---

#### Layer 6: Emergency Response Procedure

**Document in `EMERGENCY_RESPONSE.md`:**
```markdown
# Emergency Response: Accidental Commit of Personal Data

## Severity Levels

### 🔴 CRITICAL: Secrets or API keys exposed
- Immediate action required
- Rotate credentials within 1 hour

### 🟠 HIGH: Personal data (names, emails) of others
- Action required within 24 hours
- GDPR breach notification may be required

### 🟡 MEDIUM: Own personal data only
- Action required within 7 days
- No regulatory notification needed

## Response Steps

### Step 1: Assess Impact (5 minutes)

```bash
# Check what was committed
git show <commit-hash>

# Check if pushed to remote
git log --remotes

# Search for sensitive patterns
git log -S "password" --all
git log -S "api_key" --all
```

### Step 2: Immediate Mitigation

**If secrets exposed:**
```bash
# Rotate credentials IMMEDIATELY
# - Change passwords
# - Revoke API keys
# - Regenerate tokens
```

**If only committed locally (not pushed):**
```bash
# Soft reset (keeps changes in working directory)
git reset --soft HEAD~1

# Or hard reset (discards changes)
git reset --hard HEAD~1

# Add to .gitignore
echo "MEMORY.md" >> .gitignore
```

**If pushed to GitHub:**
Proceed to Step 3 (History Rewrite)

### Step 3: History Rewrite (DESTRUCTIVE)

**⚠️ WARNING: This will rewrite history for all collaborators**

```bash
# Create backup
git clone --mirror https://github.com/user/repo.git repo-backup.git

# Remove file from history
cd original-repo
git filter-repo --path MEMORY.md --invert-paths --force

# Verify removal
git log --all --full-history -- MEMORY.md  # Should be empty

# Force push (requires admin access)
git push --force-with-lease origin main
```

### Step 4: Notify Stakeholders

**Template email:**
```
Subject: URGENT: Git History Rewritten - Action Required

Git history has been rewritten to remove accidentally committed sensitive data.

AFFECTED FILE: MEMORY.md
REASON: Contained personal information (GDPR violation)

ACTION REQUIRED:
1. Delete your local clone: rm -rf openclaw-workspace
2. Re-clone from GitHub: git clone <url>
3. DO NOT push from old clones (incompatible history)

DEADLINE: Within 24 hours

Questions: Contact repository admin
```

### Step 5: GitHub Cleanup

```bash
# Contact GitHub Support to purge cached refs
# Via: https://support.github.com/contact

# Check forks (history still exists there)
# Notify fork owners or request deletion
```

### Step 6: Post-Incident Review

- [ ] Identify root cause (why did .gitignore fail?)
- [ ] Update .gitignore patterns
- [ ] Test pre-commit hooks
- [ ] Document lessons learned
- [ ] Update PRIVACY.md if needed

## Prevention Checklist

- [ ] .gitignore includes MEMORY.md and memory/
- [ ] Pre-commit hooks installed and tested
- [ ] Developers trained on memory file handling
- [ ] Regular audits scheduled (monthly)
```

---

### Implementation Checklist

**Immediate actions (today):**

- [ ] Create `.gitignore` with personal memory exclusions
- [ ] Commit `.gitignore` to repository
- [ ] Install pre-commit framework: `pip install pre-commit`
- [ ] Create `.pre-commit-config.yaml` with hooks
- [ ] Install hooks: `pre-commit install`
- [ ] Test hooks: `pre-commit run --all-files`

**This week:**

- [ ] Reorganize files (move technical memory to `technical-memory/`)
- [ ] Create `PRIVACY.md` documentation
- [ ] Create `EMERGENCY_RESPONSE.md` procedure
- [ ] Set restrictive permissions: `chmod 600 MEMORY.md; chmod 700 memory/`
- [ ] Create retention script: `scripts/memory-retention.sh`

**This month:**

- [ ] Schedule cron job for retention script
- [ ] Test emergency response procedure (simulate accidental commit)
- [ ] Review and sanitize existing technical memory files
- [ ] Train collaborators (if any) on memory file policy
- [ ] Audit git history for any existing personal data

**Quarterly:**

- [ ] Review retention policy effectiveness
- [ ] Update anonymization patterns in retention script
- [ ] Audit `.gitignore` patterns (any files slipping through?)
- [ ] Test pre-commit hooks with real scenarios
- [ ] Review PRIVACY.md for accuracy

---

## Implementation Checklist

### Phase 1: Immediate Protection (Day 1)

**Priority: Prevent future commits**

- [ ] **Create/update .gitignore**
  ```bash
  cat >> .gitignore << 'EOF'
  # Personal memory files (GDPR-sensitive)
  MEMORY.md
  memory/
  EOF
  ```

- [ ] **Remove already-tracked files** (if applicable)
  ```bash
  git rm --cached MEMORY.md
  git rm --cached -r memory/
  git commit -m "Remove personal memory files from tracking"
  ```

- [ ] **Set restrictive file permissions**
  ```bash
  chmod 600 MEMORY.md
  chmod 700 memory/
  ```

- [ ] **Verify .gitignore works**
  ```bash
  git status  # MEMORY.md and memory/ should not appear
  ```

---

### Phase 2: Automated Enforcement (Day 2-3)

**Priority: Prevent human error**

- [ ] **Install pre-commit framework**
  ```bash
  pip install pre-commit
  ```

- [ ] **Create .pre-commit-config.yaml** (see [recommended config](#layer-3-pre-commit-hooks-automated-enforcement))

- [ ] **Install hooks**
  ```bash
  pre-commit install
  pre-commit install --hook-type pre-push
  ```

- [ ] **Test hooks**
  ```bash
  # Should pass (no memory files)
  pre-commit run --all-files
  
  # Test blocking (should fail)
  git add MEMORY.md
  git commit -m "Test"  # Should be blocked
  git reset HEAD MEMORY.md
  ```

- [ ] **Install Gitleaks** (if not already installed)
  ```bash
  # macOS
  brew install gitleaks
  
  # Linux
  wget https://github.com/gitleaks/gitleaks/releases/download/v8.18.0/gitleaks_8.18.0_linux_x64.tar.gz
  tar -xzf gitleaks_8.18.0_linux_x64.tar.gz
  sudo mv gitleaks /usr/local/bin/
  ```

---

### Phase 3: GDPR Compliance (Week 1)

**Priority: Meet legal obligations**

- [ ] **Document retention policy**
  - Create `PRIVACY.md` (see template above)
  - Define retention periods (recommendation: 90 days for daily logs)
  - Document erasure procedure

- [ ] **Create retention automation script**
  - Create `scripts/memory-retention.sh` (see template above)
  - Make executable: `chmod +x scripts/memory-retention.sh`
  - Test manually: `./scripts/memory-retention.sh`

- [ ] **Schedule automated cleanup**
  ```bash
  crontab -e
  # Add: 0 2 * * 0 /home/user/openclaw-workspace/scripts/memory-retention.sh
  ```

- [ ] **Create emergency response procedure**
  - Create `EMERGENCY_RESPONSE.md` (see template above)
  - Document history rewrite steps
  - Prepare stakeholder notification template

---

### Phase 4: History Audit (Week 2)

**Priority: Clean up past mistakes**

- [ ] **Check if personal data exists in history**
  ```bash
  # Search for MEMORY.md in history
  git log --all --full-history -- MEMORY.md
  
  # Search for memory/ directory
  git log --all --full-history -- memory/
  
  # Search for sensitive patterns
  git log -S "password" --all
  git log -S "api_key" --all
  git log -S "@" --all | grep -i email
  ```

- [ ] **If found: Rewrite history** (ONLY if necessary)
  ```bash
  # BACKUP FIRST
  git clone --mirror . ../repo-backup.git
  
  # Remove files from history
  git filter-repo --path MEMORY.md --invert-paths --force
  git filter-repo --path memory/ --invert-paths --force
  
  # Force push (coordinate with team first)
  git push --force-with-lease origin main
  ```

- [ ] **Notify GitHub Support** (to purge cached refs)

- [ ] **Check forks** (if public repo)

---

### Phase 5: Ongoing Maintenance (Monthly)

**Priority: Continuous compliance**

- [ ] **Review retention logs**
  ```bash
  tail -n 100 logs/memory-retention.log
  ```

- [ ] **Audit .gitignore effectiveness**
  ```bash
  # Check for untracked memory files
  git status --ignored
  ```

- [ ] **Test pre-commit hooks**
  ```bash
  pre-commit run --all-files
  ```

- [ ] **Review technical memory sanitization**
  ```bash
  # Check for email addresses
  grep -r "[a-zA-Z0-9._%+-]\+@[a-zA-Z0-9.-]\+\.[a-zA-Z]\{2,\}" technical-memory/
  
  # Check for potential names (may have false positives)
  grep -rE "\b[A-Z][a-z]+ [A-Z][a-z]+\b" technical-memory/
  ```

- [ ] **Update PRIVACY.md** (if policies change)

---

### Phase 6: Team Training (If Collaborators Exist)

**Priority: Shared understanding**

- [ ] **Document memory file policy** in README.md
  ```markdown
  ## Memory Files Policy
  
  - `MEMORY.md` and `memory/` are excluded from Git (personal data)
  - `technical-memory/` is safe to commit (after sanitization)
  - Pre-commit hooks enforce this policy automatically
  - See PRIVACY.md for full details
  ```

- [ ] **Onboarding checklist for new collaborators**
  - Install pre-commit: `pip install pre-commit`
  - Install hooks: `pre-commit install`
  - Read PRIVACY.md
  - Test hooks: `pre-commit run --all-files`

- [ ] **Conduct training session** (if team size > 5)
  - Demonstrate accidental commit scenario
  - Show how pre-commit hooks block it
  - Walk through emergency response procedure

---

### Verification Checklist

**Before considering implementation complete:**

- [ ] `.gitignore` contains personal memory patterns
- [ ] Personal memory files not in `git status` output
- [ ] Pre-commit hooks installed and tested
- [ ] Gitleaks scanning works (test with fake API key)
- [ ] Custom memory blocker hook works (test with MEMORY.md)
- [ ] `PRIVACY.md` created and accurate
- [ ] `EMERGENCY_RESPONSE.md` created and tested (dry run)
- [ ] Retention script created and scheduled
- [ ] No personal data found in Git history (audit complete)
- [ ] File permissions set (chmod 600 MEMORY.md)
- [ ] Team trained (if applicable)

---

## Conclusion

### Summary of Findings

**The Challenge:**
Managing memory files that contain both valuable technical documentation and sensitive personal information in a Git repository requires a multi-layered security approach.

**The Solution:**
1. **Prevention** - .gitignore + file organization
2. **Enforcement** - Pre-commit hooks (Gitleaks + custom blockers)
3. **Compliance** - GDPR retention policies + automated cleanup
4. **Recovery** - git-filter-repo for emergency history rewrites
5. **Documentation** - Clear privacy policies and emergency procedures

**Key Insight:**
**Encryption is NOT the answer for memory files.** The complexity and risk of transparent encryption (git-crypt, transcrypt) outweigh the benefits. Complete exclusion via .gitignore is simpler, safer, and more GDPR-compliant.

**Encryption IS the answer for:**
- Structured config files (SOPS recommended)
- Shared team secrets (git-crypt with GPG)
- Binary certificates/keystores (git-crypt)

### Recommended Tools by Use Case

| Scenario | Tool | Why |
|----------|------|-----|
| **Personal memory files** | **.gitignore** | Simple, effective, no learning curve |
| **Structured secrets** (YAML, JSON) | **SOPS** | Best diff experience, flexible KMS |
| **Team shared configs** | **git-crypt** | Transparent, GPG access control |
| **Pre-commit scanning** | **Gitleaks** | Fast, accurate, low false positives |
| **GDPR compliance** | **Custom retention script** | Automated deletion and anonymization |
| **History cleanup** | **git-filter-repo** | Official Git recommendation, powerful |

### Final Recommendations for OpenClaw Workspace

**DO:**
- ✅ Add `MEMORY.md` and `memory/` to .gitignore immediately
- ✅ Install Gitleaks pre-commit hook
- ✅ Create separate `technical-memory/` directory for sanitized notes
- ✅ Implement automated retention script (90-day deletion)
- ✅ Document privacy policy in PRIVACY.md
- ✅ Set chmod 600 on personal memory files

**DON'T:**
- ❌ Don't use encryption for memory files (complexity not worth it)
- ❌ Don't commit personal diary entries "just this once"
- ❌ Don't rely solely on .gitignore (add pre-commit hooks)
- ❌ Don't store real names/emails in technical memory (anonymize)
- ❌ Don't skip the history audit (check for past leaks)

### Resources

**Official Documentation:**
- GitHub Secret Scanning: https://docs.github.com/en/code-security/secret-scanning
- Git Documentation (.gitignore): https://git-scm.com/docs/gitignore
- GDPR Official Text: https://gdpr-info.eu/

**Tools:**
- Gitleaks: https://github.com/gitleaks/gitleaks
- SOPS: https://github.com/getsops/sops
- git-filter-repo: https://github.com/newren/git-filter-repo
- pre-commit: https://pre-commit.com/

**Guides:**
- SOPS Comprehensive Guide: https://blog.gitguardian.com/a-comprehensive-guide-to-sops/
- git-filter-repo Tutorial: https://graphite.dev/guides/git-filter-repo
- GDPR Compliance in Git: https://hoop.dev/blog/gdpr-compliance-in-git-how-to-handle-personal-data-in-commit-history/

---

**End of Report**

**Generated:** 2026-02-04  
**Research Duration:** ~2 hours  
**Sources:** 50+ web resources, GitHub examples, official documentation  
**Confidence Level:** High (cross-verified across multiple authoritative sources)
