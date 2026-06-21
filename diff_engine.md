# 🧠 DIFF ENGINE (v2.0)

This system governs the syntax, structure, and constraints of code generation to guarantee precise and merge-safe modifications.

---

## 1. OUTPUT STANDARDS

All changes must be output in one of the following formats:

### 1.1 UNIFIED DIFF (PREFERRED)
```diff
--- lib/screens/home_screen.dart
+++ lib/screens/home_screen.dart
@@ -24,4 +24,4 @@
-    Color tempColor = Colors.red;
+    Color tempColor = themeProvider.primaryColor;
```

### 1.2 PATCH BLOCK
```text
file: lib/screens/home_screen.dart
change:
- Color tempColor = Colors.red;
+ Color tempColor = themeProvider.primaryColor;
```

---

## 2. MODIFICATION RULES

- **Plan Alignment**: Every code edit MUST map directly to a step in the approved plan (`planner_agent.md`).
- **Raw Context Target**: Apply modifications strictly onto the raw, unstripped target file structures provided by `context_builder.md`. Never generate code based on trimmed reference signatures.
- **Minimality Constraint**: Edit the smallest code range possible. Unrelated lines, extra imports, and helper refactorings are prohibited.
- **Surrounding Integrity**: Retain indentation, brackets, formatting style, and adjacent logic exactly as found in the raw context.