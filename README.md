# LLM Bash Framework

A powerful Bash framework for building agentic workflows with Large Language Models using command line tools. Implements patterns from Anthropic's "[Building Effective Agents](https://www.anthropic.com/engineering/building-effective-agents)" guide, including prompt chaining, orchestration, A/B testing, self-consistency, and more.

## Prerequisites

- Bash 4.0+
- [llm CLI tool](https://llm.datasette.io/) installed and configured
- `jq` for JSON processing

### Installation

**Option 1: Using pipx (recommended)**
```bash
# Install llm CLI
pipx install llm

# Or install from requirements.txt
pipx install -r requirements.txt
```

**Option 2: Using pip**
```bash
# Install from requirements.txt
pip install -r requirements.txt
```

**Install a model plugin:**
```bash
# Example with OpenAI
llm keys set openai
llm -m gpt-5-nano "Hello world"

# Or Claude
llm install llm-anthropic
llm keys set anthropic
llm -m claude-sonnet-4-5 "Hello world"
```

## Quick Start

### Hello World Example

Here's a simple example showing prompt chaining:

```bash
. llm-bash.sh

# Chain multiple prompts - each builds on the previous output
prompt_chain \
    "List 3 programming languages" \
    "Pick the best one from: {{previous}}" \
    "Write a hello world in: {{previous}}"
```

**Output (text format):**
```
=== Prompt Chain Result ===
Steps Completed: 3

print("Hello, World!")
```

**Output (JSON format):**
```bash
LLM_OUTPUT_FORMAT="json" prompt_chain \
    "List 3 programming languages" \
    "Pick the best one from: {{previous}}" \
    "Write a hello world in: {{previous}}"
```

```json
{
  "result_type": "Prompt Chain Result",
  "output": "print(\"Hello, World!\")",
  "metadata": {
    "steps_completed": "3"
  }
}
```

## Pipe Support

**All workflow functions support Unix-style piping with the `{{input}}` placeholder:**

```bash
# Pipe file content directly to functions
cat document.txt | prompt_chain \
    "Summarize: {{input}}" \
    "Extract key points from: {{previous}}"

# Pipe command output
echo "Fix authentication bug" | orchestrator \
    "Task: {{input}}" \
    "Break down: {{task}}" \
    "Handle: {{subtask}}"

# Chain multiple commands
curl https://api.example.com/data | \
    parallel_prompts \
        "Analyze data: {{input}}" \
        "Find anomalies in: {{input}}" \
        "Generate report for: {{input}}"
```

## Output Formats

All workflow functions support configurable output via `LLM_OUTPUT_FORMAT`:

```bash
# Human-readable with labeled metadata (default)
LLM_OUTPUT_FORMAT="text" orchestrator "task" "decompose" "worker"

# Structured JSON for machine parsing
LLM_OUTPUT_FORMAT="json" orchestrator "task" "decompose" "worker"

# Enable verbose mode for additional details
LLM_VERBOSE=1 prompt_chain "step1" "step2"
```

## Available Workflow Functions

### Prompt Chaining

**`prompt_chain "prompt1" "prompt2" "prompt3" ...`**

Chain multiple prompts where each output feeds into the next. Use `{{previous}}` to reference the previous output.

```bash
prompt_chain \
    "Analyze this code: $code" \
    "Based on issues: {{previous}}, suggest fixes" \
    "Rate the code quality: {{previous}}"
```

**Returns:** Final output with metadata (`steps_completed`, `verbose_details`)

---

### Orchestration

**`orchestrator "main_task" "decompose_prompt" "worker_prompt_template"`**

Decompose a complex task into subtasks and delegate to workers.

```bash
orchestrator \
    "Research quantum computing" \
    "Break this into 3-5 specific questions: {{task}}" \
    "Research and answer: {{subtask}}"
```

**Returns:** Synthesized answer with metadata (`subtasks_completed`, `confidence`, `verbose_details`)

---

### A/B Testing

**`ab_test "input" "prompt_a" "prompt_b" "evaluator_prompt" [output_mode]`**

Test two prompt variants and select the better one using schema-based evaluation.

```bash
# Default: returns clean output (just the selected variant)
result=$(ab_test \
    "Topic: AI, Audience: Developers" \
    "Write a formal article about {{input}}" \
    "Write an engaging article about {{input}}" \
    "Which article better suits the audience?")

# With metadata: returns formatted result with confidence, reasoning, etc.
result=$(ab_test \
    "Topic: AI, Audience: Developers" \
    "Write a formal article about {{input}}" \
    "Write an engaging article about {{input}}" \
    "Which article better suits the audience?" \
    "with_metadata")
```

**Output Modes:**
- `"clean"` (default) - Returns only the selected variant output
- `"with_metadata"` - Returns formatted result with metadata (`selected_variant`, `confidence`, `reasoning`, `verbose_details`)

**Returns:** By default, the selected variant output only. Use `"with_metadata"` for debugging/analysis

---

### Smart Routing

**`route_by_classifier "input" "classifier_prompt" "route1:prompt1" "route2:prompt2" ...`**

Classify input and route to specialized prompts.

```bash
route_by_classifier \
    "$user_query" \
    "Classify this as: technical, billing, or general" \
    "technical:Provide technical support for: {{input}}" \
    "billing:Help with billing question: {{input}}" \
    "general:Provide general assistance for: {{input}}"
```

**Returns:** Routed output with metadata (`selected_route`, `confidence`, `reasoning`)

---

### Evaluation & Optimization

**`evaluate_optimize "initial_prompt" "evaluator_prompt" "optimizer_prompt" [max_iterations] [quality_threshold]`**

Iteratively improve output based on quality scores.

```bash
evaluate_optimize \
    "Write documentation for: $code" \
    "Evaluate this documentation: {{output}}" \
    "Improve based on feedback: {{output}} {{evaluation}}" \
    3 \
    8
```

**Returns:** Optimized output with metadata (`iterations`, `final_quality_score`, `exit_reason`, `optimization_history`)

---

### Parallel Prompts

**`parallel_prompts "prompt1" "prompt2" "prompt3" ...`**

Execute multiple prompts in parallel and collect results.

```bash
parallel_prompts \
    "Identify patterns in: $data" \
    "Find anomalies in: $data" \
    "Generate statistics for: $data"
```

**Returns:** Labeled results with metadata (`prompts_executed`, `verbose_details`)

---

### Map-Reduce

**`map_reduce "mapper_prompt" "reducer_prompt" "input1" "input2" ...`**

Parallel map phase followed by reduce phase synthesis.

```bash
map_reduce \
    "Summarize this section: {{input}}" \
    "Combine these summaries: {{results}}" \
    "$section1" "$section2" "$section3"
```

**Returns:** Reduced output with metadata (`inputs_processed`, `map_phase`, `reduce_phase`, `verbose_details`)

---

### Self-Consistency

**`self_consistency "prompt" [num_samples]`**

Generate multiple samples and select consensus answer.

```bash
self_consistency \
    "Is this code secure? $code" \
    5
```

**Returns:** Consensus answer with metadata (`samples_generated`, `consensus_score`, `reasoning`, `verbose_details`)

---

### ReAct Agent

**`react_agent "task" "tool_descriptions" [max_steps]`**

ReAct pattern agent with structured reasoning.

```bash
react_agent \
    "Debug this error: $error" \
    "Available tools:
    - analyze_stack_trace
    - check_dependencies
    - suggest_fix" \
    10
```

**Returns:** Final thought with metadata (`steps_taken`, `exit_reason`, `final_confidence`, `verbose_details`)

---

### Tree of Thoughts

**`tree_of_thoughts "problem" "generate_prompt" "evaluate_prompt" "select_prompt" [depth] [branches]`**

Explore multiple solution paths recursively.

```bash
tree_of_thoughts \
    "$complex_problem" \
    "Generate next step for: {{thought}}" \
    "Evaluate these steps: {{candidates}}" \
    "Select best approach: {{evaluations}}" \
    3 \
    3
```

## Nested/Recursive Function Calls

You can nest function calls using command substitution to create powerful compositions:

```bash
# Execute inner function first, pass its output to outer function
prompt_chain "$(llm_exec 'Generate a topic')" "Write about: {{previous}}"

# Multiple levels of nesting
prompt_chain "$(some_function "$(another_function 'arg')")" "next prompt"

# Mix literal prompts with function calls
result=$(prompt_chain \
    "List 3 ideas" \
    "$(llm_exec 'Pick the best from: {{previous}}')" \
    "Expand on: {{previous}}")
```

**Practical Examples:**

```bash
# Chain where middle step uses a different function
prompt_chain \
    "Generate a story outline" \
    "$(orchestrator 'Develop plot' 'Break into scenes' 'Write scene: {{subtask}}')" \
    "Polish the final story: {{previous}}"

# Recursive evaluation with self-consistency
result=$(evaluate_optimize \
    "$(self_consistency 'Solve this problem: ...' 3)" \
    "Rate this solution: {{output}}" \
    "Improve based on: {{evaluation}}")

# Use parallel_prompts output in a chain
combined=$(prompt_chain \
    "$(parallel_prompts 'aspect1' 'aspect2' 'aspect3')" \
    "Synthesize these parallel analyses: {{previous}}")
```

## Configuration

Set these environment variables before sourcing the framework:

```bash
# Model selection (default: gpt-5-nano)
export LLM_MODEL="claude-3-5-sonnet-20241022"

# Timeout for LLM calls in seconds (default: 60)
export LLM_TIMEOUT=120

# Maximum retry attempts (default: 3)
export LLM_MAX_RETRIES=5

# Output format: "text" or "json" (default: text)
export LLM_OUTPUT_FORMAT="json"

# Enable verbose logging (default: 0)
export LLM_VERBOSE=1

# Enable bash debug mode (default: not set)
export LLM_DEBUG=1
```

## Examples

### Pattern Examples

The `examples_patterns.sh` file contains 13 comprehensive examples demonstrating different patterns:

```bash
# Interactive menu
./examples_patterns.sh

# Command-line usage
./examples_patterns.sh review code.py
./examples_patterns.sh research "quantum computing"
./examples_patterns.sh support "My app crashed"
./examples_patterns.sh format-demo "How do I reset my password?"

# With custom configuration
LLM_OUTPUT_FORMAT="json" ./examples_patterns.sh research "AI safety"
LLM_VERBOSE=1 ./examples_patterns.sh verbose
```

### Complete Workflow Example

The `example_daily_briefing.sh` demonstrates a full end-to-end workflow:
- Fetches live weather and news data
- Synthesizes information with `prompt_chain`
- A/B tests email formats
- Sends HTML email to your inbox

```bash
# Run daily briefing
BRIEFING_EMAIL="you@example.com" \
BRIEFING_LOCATION="New York" \
./example_daily_briefing.sh

# Easy automation with crontab - runs at 7 AM every day
crontab -e
# Add this line:
0 7 * * * BRIEFING_EMAIL="you@example.com" BRIEFING_LOCATION="New York" /path/to/llm-bash/example_daily_briefing.sh
```

### Example: Customer Support Router

```bash
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
. "${SCRIPT_DIR}/llm-bash.sh"

# Route customer queries to specialized handlers
route_by_classifier \
    "$user_query" \
    "Classify this query as: technical, billing, refund, account, or general" \
    "technical:You are a technical support specialist. Help with: {{input}}" \
    "billing:You are a billing specialist. Help with: {{input}}" \
    "refund:You are a refund specialist. Process: {{input}}" \
    "account:You are an account specialist. Help with: {{input}}" \
    "general:You are a customer service representative. Assist with: {{input}}"
```

### Example: Code Review Pipeline

```bash
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
. "${SCRIPT_DIR}/llm-bash.sh"

code=$(cat "$1")

# Multi-stage code review with optimization
evaluate_optimize \
    "Review this code for bugs and issues: $code" \
    "Evaluate the review quality: {{output}}" \
    "Improve the review based on: {{output}} {{evaluation}}" \
    3 \
    8
```

### Example: Pipe-Based Data Processing

```bash
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
. "${SCRIPT_DIR}/llm-bash.sh"

# Pipe file content through analysis chain
cat server-logs.txt | prompt_chain \
    "Identify errors in these logs: {{input}}" \
    "Categorize these errors: {{previous}}" \
    "Suggest fixes for: {{previous}}"

# Pipe API response through parallel analysis
curl -s https://api.example.com/metrics | parallel_prompts \
    "Analyze performance metrics: {{input}}" \
    "Identify bottlenecks in: {{input}}" \
    "Generate optimization recommendations for: {{input}}"

# Process multiple files with map-reduce
find . -name "*.log" -exec cat {} \; | map_reduce \
    "Extract key events from: {{input}}" \
    "Combine these event summaries: {{results}}"
```

## Contributing

Contributions welcome!

## License

MIT License - see LICENSE file for details

## Acknowledgments

- Built on [Simon Willison's llm CLI tool](https://github.com/simonw/llm)
- Inspired by [Anthropic's agent patterns](https://www.anthropic.com/research/building-effective-agents)
