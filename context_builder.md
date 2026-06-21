# 🧠 CONTEXT BUILDER ENGINE (v2.0)

This system governs how code context is identified, pruned, and presented to the agents.

---

## 1. CORE OBJECTIVES
- Minimize token counts injected into prompts.
- Ensure context contains exactly what is needed to make a safe code change.
- **Diff Safety**: Ensure target editing files are presented in their raw, unaltered state to prevent diff conflicts.

---

## 2. DOMAIN PATH MAPS
Use `file_index.md` to map requests to the correct paths:
- **UI Bug / Styling Changes** → `lib/screens/`, `lib/widgets/`
- **State management changes** → `lib/core/providers/`
- **Business logic / Integrations** → `lib/core/services/`
- **Data objects / Calculations** → `lib/core/models/`, `lib/core/data/`

---

## 3. CONTEXT DIVISION RULE (CRITICAL FOR DIFF SAFETY)
To balance token reduction and diff-application safety, context is split into two categories:

### 3.1 TARGET FILES (Files being modified)
- **Rule**: MUST provide the raw, unstripped content of the target function or file.
- **Reason**: Any modification of comments, formatting, or imports during context loading will cause unified diffs/patches to fail on disk.

### 3.2 REFERENCE FILES (Unmodified dependency files)
- **Rule**: Trim files to save tokens.
  - Remove all function bodies (provide signatures only).
  - Strip comments and annotations.
  - Remove unused imports.

---

## 4. DEPENDENCY RESOLUTION
- **Depth**: Transitive dependencies can be fetched up to **3 levels deep** (e.g. Widget depends on Provider, which depends on Service, which depends on Model).
- **Trimming**: All dependencies at level 2 and 3 must be represented by signatures or interface definitions only.

---

## 5. OUTPUT FORMAT
Context must be structured as:
```json
{
  "target_files": [
    {
      "path": "lib/screens/home_screen.dart",
      "raw_content": "...unaltered code block..."
    }
  ],
  "reference_files": [
    {
      "path": "lib/core/services/auth_service.dart",
      "signatures_only": "...stripped interface..."
    }
  ]
}
```