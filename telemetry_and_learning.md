# 📊 TELEMETRY & LEARNING SYSTEM (v2.0)

This system captures execution performance, maps heuristics, and enables adaptive improvements across tasks.

---

## 1. PERSISTENCE LAYER (CACHE)
Rather than rewriting static instructions at runtime, performance metrics and optimization variables are logged and read from a local state cache file:
- **Location**: `.agent/telemetry_cache.json`
- **Behavior**: Loaded at the beginning of each run to dynamically adjust context-builder search depths and task-router classification bounds.

---

## 2. METRIC COLLECTION SCHEMA
The cache tracking includes:
- **Task Analytics**: `task_type`, `lines_modified`, `execution_time_ms`, and `status` (success/failure).
- **Context Metrics**: `average_token_size`, `irrelevant_files_loaded` (count), and `missing_files_post_execution` (list).
- **Quality Metrics**: `reviewer_rejected_count` (indicates plan or implementer misalignment) and `diff_failed_apply` (indicates context stripping conflicts).

---

## 3. HEURISTIC LEARNING LOOPS

### 3.1 CONTEXT OPTIMIZATION
- If the cache shows specific dependencies are repeatedly loaded but unused, the context builder deprioritizes them.
- If specific files are repeatedly missing (causing compile errors or validator failure), they are permanently added to the target domain's core context.

### 3.2 ROUTING TUNING
- If a specific domain has high validator failures due to multi-layer edits, the task router automatically flags similar incoming tasks as `HIGH RISK`, forcing step-by-step division.