#!/bin/bash
# LLM Agent Framework - Bash implementation for agentic workflows
# Based on Anthropic's "Building Effective Agents" patterns

# ============================================================================
# CONFIGURATION
# ============================================================================

# Default model (can be overridden)
: ${LLM_MODEL:="gpt-5-nano"}
: ${LLM_TIMEOUT:=60}
: ${LLM_MAX_RETRIES:=3}

# Enable debug mode with LLM_DEBUG=1
[[ -n "${LLM_DEBUG:-}" ]] && set -x

# Enable verbose mode with LLM_VERBOSE=1 (shows prompts and responses)
: ${LLM_VERBOSE:=0}

# Output format control (text, json)
# - text: Human-readable with labeled sections and metadata (default)
# - json: Structured JSON with all metadata (machine-parseable)
: ${LLM_OUTPUT_FORMAT:="text"}

# ============================================================================
# CORE UTILITIES
# ============================================================================

# Read stdin if available (for pipe support)
read_stdin_if_available() {
    if [ ! -t 0 ]; then
        cat
    else
        echo ""
    fi
}

# Execute LLM with error handling and retries
llm_exec() {
    local prompt="$1"
    local model="${2:-$LLM_MODEL}"
    local system="${3:-}"
    local retries=0
    local result

    # Verbose logging: show prompt
    if [[ "$LLM_VERBOSE" == "1" ]]; then
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
        echo "📤 PROMPT (model: $model):" >&2
        echo "$prompt" | head -c 500 >&2
        [[ ${#prompt} -gt 500 ]] && echo "... (truncated)" >&2
        echo "" >&2
    fi

    while [[ $retries -lt $LLM_MAX_RETRIES ]]; do
        if [[ -n "$system" ]]; then
            result=$(timeout $LLM_TIMEOUT llm -m "$model" -s "$system" "$prompt" 2>&1)
        else
            result=$(timeout $LLM_TIMEOUT llm -m "$model" "$prompt" 2>&1)
        fi

        if [[ $? -eq 0 ]]; then
            # Verbose logging: show response
            if [[ "$LLM_VERBOSE" == "1" ]]; then
                echo "📥 RESPONSE:" >&2
                echo "$result" | head -c 500 >&2
                [[ ${#result} -gt 500 ]] && echo "... (truncated)" >&2
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
                echo "" >&2
            fi
            echo "$result"
            return 0
        fi

        ((retries++))
        [[ $retries -lt $LLM_MAX_RETRIES ]] && sleep 2
    done

    echo "Error: LLM execution failed after $LLM_MAX_RETRIES retries" >&2
    return 1
}

# Parse JSON response (requires jq)
parse_json() {
    local json="$1"
    local path="${2:-.}"
    echo "$json" | jq -r "$path" 2>/dev/null
}

# Log with timestamp
log_info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $*" >&2
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*" >&2
}

# ============================================================================
# OUTPUT FORMATTING UTILITIES
# ============================================================================

# Format result output based on LLM_OUTPUT_FORMAT
# Usage: format_result "title" "output" [key1 value1 key2 value2 ...]
# Example: format_result "A/B Test" "$result" "selected_variant" "A" "evaluation" "$eval"
format_result() {
    local title="$1"
    local output="$2"
    shift 2

    # Collect key-value metadata pairs
    declare -A metadata
    while [[ $# -gt 0 ]]; do
        local key="$1"
        local value="$2"
        metadata["$key"]="$value"
        shift 2
    done

    case "$LLM_OUTPUT_FORMAT" in
        json)
            format_result_json "$title" "$output" metadata
            ;;
        text|*)
            format_result_text "$title" "$output" metadata
            ;;
    esac
}

# Format result as human-readable text with labeled sections
format_result_text() {
    local title="$1"
    local output="$2"
    local -n meta=$3

    echo "=== $title ==="

    # Output metadata first
    for key in "${!meta[@]}"; do
        local display_key=$(echo "$key" | tr '_' ' ' | sed 's/\b\(.\)/\u\1/g')
        echo "$display_key: ${meta[$key]}"
    done

    # Add separator if there's metadata
    if [[ ${#meta[@]} -gt 0 ]]; then
        echo ""
    fi

    # Output the main result
    echo "$output"

    # Verbose mode additions
    if [[ "$LLM_VERBOSE" == "1" ]] && [[ -n "${meta[verbose_details]}" ]]; then
        echo ""
        echo "--- Additional Details ---"
        echo "${meta[verbose_details]}"
    fi
}

# Format result as JSON with metadata
format_result_json() {
    local title="$1"
    local output="$2"
    local -n meta=$3

    # Build JSON manually to avoid jq requirement for basic formatting
    echo "{"
    echo "  \"result_type\": \"$title\","
    echo "  \"output\": $(echo "$output" | jq -R -s '.'),"

    # Add metadata fields
    local first=true
    for key in "${!meta[@]}"; do
        # Skip verbose_details in non-verbose mode
        if [[ "$key" == "verbose_details" ]] && [[ "$LLM_VERBOSE" != "1" ]]; then
            continue
        fi

        if $first; then
            echo "  \"metadata\": {"
            first=false
        else
            echo ","
        fi

        echo -n "    \"$key\": $(echo "${meta[$key]}" | jq -R -s '.')"
    done

    if ! $first; then
        echo ""
        echo "  }"
    fi

    echo "}"
}

# ============================================================================
# SCHEMA UTILITIES
# ============================================================================

# Execute LLM with structured schema output (single object)
# Usage: llm_exec_schema "prompt" "schema" [model] [system]
llm_exec_schema() {
    local prompt="$1"
    local schema="$2"
    local model="${3:-$LLM_MODEL}"
    local system="${4:-}"
    local retries=0
    local result

    # Verbose logging: show prompt and schema
    if [[ "$LLM_VERBOSE" == "1" ]]; then
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
        echo "📤 SCHEMA PROMPT (model: $model):" >&2
        echo "Schema: $schema" >&2
        echo "$prompt" | head -c 500 >&2
        [[ ${#prompt} -gt 500 ]] && echo "... (truncated)" >&2
        echo "" >&2
    fi

    while [[ $retries -lt $LLM_MAX_RETRIES ]]; do
        if [[ -n "$system" ]]; then
            result=$(timeout $LLM_TIMEOUT llm -m "$model" -s "$system" --schema "$schema" "$prompt" 2>&1)
        else
            result=$(timeout $LLM_TIMEOUT llm -m "$model" --schema "$schema" "$prompt" 2>&1)
        fi

        if [[ $? -eq 0 ]] && echo "$result" | jq empty 2>/dev/null; then
            # Verbose logging: show response
            if [[ "$LLM_VERBOSE" == "1" ]]; then
                echo "📥 SCHEMA RESPONSE:" >&2
                # Pretty-print JSON, limit to first 50 lines
                local formatted=$(echo "$result" | jq -C '.' 2>/dev/null)
                local total_lines=$(echo "$formatted" | wc -l)
                echo "$formatted" | head -50 >&2
                if [[ $total_lines -gt 50 ]]; then
                    echo "... (${total_lines} total lines, showing first 50)" >&2
                fi
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
                echo "" >&2
            fi
            echo "$result"
            return 0
        fi

        # Log the error if verbose
        if [[ "$LLM_VERBOSE" == "1" ]]; then
            echo "❌ ERROR: Invalid JSON or command failed" >&2
            echo "Raw output: $result" >&2
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
        fi

        ((retries++))
        log_error "Schema execution failed (attempt $retries/$LLM_MAX_RETRIES)"
        [[ $retries -lt $LLM_MAX_RETRIES ]] && sleep 2
    done

    log_error "Schema execution failed after $LLM_MAX_RETRIES retries"
    return 1
}

# Execute LLM with structured schema output (array of objects)
# Usage: llm_exec_schema_multi "prompt" "schema" [model] [system]
llm_exec_schema_multi() {
    local prompt="$1"
    local schema="$2"
    local model="${3:-$LLM_MODEL}"
    local system="${4:-}"
    local retries=0
    local result

    # Verbose logging
    if [[ "$LLM_VERBOSE" == "1" ]]; then
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
        echo "📤 SCHEMA-MULTI PROMPT (model: $model):" >&2
        echo "Schema: $schema" >&2
        echo "$prompt" | head -c 500 >&2
        [[ ${#prompt} -gt 500 ]] && echo "... (truncated)" >&2
        echo "" >&2
    fi

    while [[ $retries -lt $LLM_MAX_RETRIES ]]; do
        if [[ -n "$system" ]]; then
            result=$(timeout $LLM_TIMEOUT llm -m "$model" -s "$system" --schema-multi "$schema" "$prompt" 2>&1)
        else
            result=$(timeout $LLM_TIMEOUT llm -m "$model" --schema-multi "$schema" "$prompt" 2>&1)
        fi

        if [[ $? -eq 0 ]] && echo "$result" | jq empty 2>/dev/null; then
            if [[ "$LLM_VERBOSE" == "1" ]]; then
                echo "📥 SCHEMA-MULTI RESPONSE:" >&2
                # Pretty-print JSON, limit to first 50 lines
                local formatted=$(echo "$result" | jq -C '.' 2>/dev/null)
                local total_lines=$(echo "$formatted" | wc -l)
                echo "$formatted" | head -50 >&2
                if [[ $total_lines -gt 50 ]]; then
                    echo "... (${total_lines} total lines, showing first 50)" >&2
                fi
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
                echo "" >&2
            fi
            echo "$result"
            return 0
        fi

        # Log the error if verbose
        if [[ "$LLM_VERBOSE" == "1" ]]; then
            echo "❌ ERROR: Invalid JSON or command failed" >&2
            echo "Raw output: $result" >&2
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
        fi

        ((retries++))
        log_error "Schema-multi execution failed (attempt $retries/$LLM_MAX_RETRIES)"
        [[ $retries -lt $LLM_MAX_RETRIES ]] && sleep 2
    done

    log_error "Schema-multi execution failed after $LLM_MAX_RETRIES retries"
    return 1
}

# Extract a field from JSON response
# Usage: extract_json_field "json" "field_path"
# Handles both direct format (.field) and schema-wrapped format (.properties.field)
extract_json_field() {
    local json="$1"
    local field="$2"
    local result

    # Try direct path first
    result=$(echo "$json" | jq -r ".$field" 2>/dev/null)
    if [[ $? -eq 0 ]] && [[ "$result" != "null" ]]; then
        echo "$result"
        return 0
    fi

    # Try schema-wrapped path (.properties.field)
    result=$(echo "$json" | jq -r ".properties.$field" 2>/dev/null)
    if [[ $? -eq 0 ]] && [[ "$result" != "null" ]]; then
        echo "$result"
        return 0
    fi

    log_error "Failed to extract field: $field"
    return 1
}

# Extract array items from JSON (one per line)
# Usage: extract_json_array "json" "array_field"
# Handles multiple schema formats:
# 1. Direct: .items
# 2. Schema-wrapped: .properties.items
# 3. Double-nested schema (gpt-5-nano): .properties.items.items
extract_json_array() {
    local json="$1"
    local field="${2:-items}"

    # Try direct path first (.field)
    if echo "$json" | jq -e ".${field}" >/dev/null 2>&1; then
        if [[ "$(echo "$json" | jq -r ".${field} | type" 2>/dev/null)" == "array" ]]; then
            echo "$json" | jq -c ".${field}[]" 2>/dev/null
            return 0
        fi
    fi

    # Try double-nested schema path (.properties.field.field)
    if echo "$json" | jq -e ".properties.${field}.${field}" >/dev/null 2>&1; then
        if [[ "$(echo "$json" | jq -r ".properties.${field}.${field} | type" 2>/dev/null)" == "array" ]]; then
            echo "$json" | jq -c ".properties.${field}.${field}[]" 2>/dev/null
            return 0
        fi
    fi

    # Try schema-wrapped path (.properties.field)
    if echo "$json" | jq -e ".properties.${field}" >/dev/null 2>&1; then
        if [[ "$(echo "$json" | jq -r ".properties.${field} | type" 2>/dev/null)" == "array" ]]; then
            echo "$json" | jq -c ".properties.${field}[]" 2>/dev/null
            return 0
        fi
    fi

    # No valid array path found
    log_error "Array field '${field}' not found in JSON"
    return 1
}

# Validate schema response has required fields
# Usage: validate_schema_response "json" "field1 field2 field3"
# Handles both direct format and schema-wrapped format (.properties.field)
validate_schema_response() {
    local json="$1"
    local required_fields="$2"
    local missing_fields=""

    # Check if JSON is valid
    if ! echo "$json" | jq empty 2>/dev/null; then
        log_error "Invalid JSON response"
        return 1
    fi

    # Detect if this is schema-wrapped format
    local is_schema_wrapped=false
    if echo "$json" | jq -e '.type' >/dev/null 2>&1 && echo "$json" | jq -e '.properties' >/dev/null 2>&1; then
        is_schema_wrapped=true
    fi

    # Check each required field
    for field in $required_fields; do
        local field_exists=false

        # Try direct path
        if echo "$json" | jq -e ".$field" >/dev/null 2>&1; then
            field_exists=true
        # Try schema-wrapped path
        elif $is_schema_wrapped && echo "$json" | jq -e ".properties.$field" >/dev/null 2>&1; then
            field_exists=true
        fi

        if ! $field_exists; then
            missing_fields="$missing_fields $field"
        fi
    done

    if [[ -n "$missing_fields" ]]; then
        log_error "Missing required fields:$missing_fields"
        return 1
    fi

    return 0
}

# ============================================================================
# WORKFLOW: PROMPT CHAINING
# ============================================================================

# Chain multiple prompts where each output feeds into the next
# Usage: prompt_chain "prompt1" "prompt2" "prompt3" ...
# Supports piping: cat file | prompt_chain "analyze: {{input}}" "summarize: {{previous}}"
prompt_chain() {
    local stdin_data=$(read_stdin_if_available)
    local result=""
    local step=1
    local chain_history=""

    for prompt in "$@"; do
        log_info "Chain step $step: Processing prompt"

        # Replace {{input}} and {{previous}} placeholders
        local actual_prompt="${prompt//\{\{input\}\}/$stdin_data}"
        actual_prompt="${actual_prompt//\{\{previous\}\}/$result}"

        result=$(llm_exec "$actual_prompt")
        if [[ $? -ne 0 ]]; then
            log_error "Chain failed at step $step"
            return 1
        fi

        # Track chain history
        local prompt_preview="${prompt:0:60}"
        if [[ ${#prompt} -gt 60 ]]; then
            prompt_preview="${prompt_preview}..."
        fi
        chain_history+="Step $step: $prompt_preview
Result: $result

"

        ((step++))
    done

    # Format output with step count
    format_result "Prompt Chain Result" "$result" \
        "steps_completed" "$((step-1))" \
        "verbose_details" "$chain_history"
}

# Chain with transformations between steps
# Usage: prompt_chain_transform "prompt1" "transform_func1" "prompt2" "transform_func2" ...
# Supports piping: cat file | prompt_chain_transform "analyze: {{input}}" "transform_func" ...
prompt_chain_transform() {
    local stdin_data=$(read_stdin_if_available)
    local result=""
    local is_prompt=true

    for item in "$@"; do
        if $is_prompt; then
            local actual_prompt="${item//\{\{input\}\}/$stdin_data}"
            actual_prompt="${actual_prompt//\{\{previous\}\}/$result}"
            result=$(llm_exec "$actual_prompt")
            if [[ $? -ne 0 ]]; then
                log_error "Chain transform failed at prompt"
                return 1
            fi
            is_prompt=false
        else
            # Apply transformation function
            if declare -f "$item" > /dev/null; then
                result=$($item "$result")
            fi
            is_prompt=true
        fi
    done
    
    echo "$result"
}

# ============================================================================
# WORKFLOW: ROUTING
# ============================================================================

# Route to different prompts based on classifier with structured schema output
# Usage: route_by_classifier "input" "classifier_prompt" "route1:prompt1" "route2:prompt2" ...
# Supports piping: cat file | route_by_classifier "{{input}}" "classify: {{input}}" "route:prompt"
# Returns: Structured JSON with route, confidence, and reasoning
route_by_classifier() {
    local stdin_data=$(read_stdin_if_available)
    local input="$1"
    local classifier_prompt="$2"
    shift 2

    # Replace {{input}} in input and classifier_prompt
    input="${input//\{\{input\}\}/$stdin_data}"
    classifier_prompt="${classifier_prompt//\{\{input\}\}/$stdin_data}"

    log_info "Routing: Classifying input with schema"

    # Schema for structured classification
    local schema='route, confidence number: 0-1 confidence score, reasoning: why this route was selected'

    # Get structured classification
    local result=$(llm_exec_schema "$classifier_prompt: $input" "$schema")

    if [[ $? -ne 0 ]]; then
        log_error "Classification failed"
        return 1
    fi

    # Validate required fields
    if ! validate_schema_response "$result" "route confidence reasoning"; then
        log_error "Invalid classification response"
        return 1
    fi

    # Extract classification details
    local route=$(extract_json_field "$result" "route")
    local confidence=$(extract_json_field "$result" "confidence")
    local reasoning=$(extract_json_field "$result" "reasoning")

    log_info "Routing: Selected '$route' (confidence: $confidence)"
    log_info "Reasoning: $reasoning"

    # Find exact matching route
    for route_spec in "$@"; do
        local route_name="${route_spec%%:*}"
        local prompt="${route_spec#*:}"

        if [[ "$route" == "$route_name" ]]; then
            # Replace both {{input}} with actual input (which may contain stdin data)
            prompt="${prompt//\{\{input\}\}/$input}"
            local selected_output=$(llm_exec "$prompt")
            if [[ $? -ne 0 ]]; then
                log_error "Route execution failed for: $route"
                return 1
            fi

            # Format output with routing metadata
            format_result "Route Classification Result" "$selected_output" \
                "selected_route" "$route" \
                "confidence" "$confidence" \
                "reasoning" "$reasoning"
            return 0
        fi
    done

    log_error "No matching route found for classification: $route"
    return 1
}

# Conditional routing based on rules
# Usage: route_conditional "input" "condition_check_func" "true_prompt" "false_prompt"
# Supports piping: cat file | route_conditional "{{input}}" "check_func" "true_prompt" "false_prompt"
route_conditional() {
    local stdin_data=$(read_stdin_if_available)
    local input="$1"
    local condition_func="$2"
    local true_prompt="$3"
    local false_prompt="$4"

    # Replace {{input}} in input parameter
    input="${input//\{\{input\}\}/$stdin_data}"

    if $condition_func "$input"; then
        log_info "Routing: Condition true"
        local prompt="${true_prompt//\{\{input\}\}/$input}"
        llm_exec "$prompt"
    else
        log_info "Routing: Condition false"
        local prompt="${false_prompt//\{\{input\}\}/$input}"
        llm_exec "$prompt"
    fi
}

# ============================================================================
# WORKFLOW: PARALLELIZATION
# ============================================================================

# Run multiple prompts in parallel and collect results
# Usage: parallel_prompts "prompt1" "prompt2" "prompt3" ...
# Supports piping: cat file | parallel_prompts "analyze: {{input}}" "summarize: {{input}}"
parallel_prompts() {
    local stdin_data=$(read_stdin_if_available)
    local pids=()
    local temp_dir=$(mktemp -d)
    local i=0
    local -a prompts=("$@")

    log_info "Parallel Prompts: Launching ${#prompts[@]} prompts in parallel"

    # Launch parallel jobs
    for prompt in "$@"; do
        {
            # Replace {{input}} in each prompt
            local actual_prompt="${prompt//\{\{input\}\}/$stdin_data}"
            llm_exec "$actual_prompt" > "$temp_dir/result_$i"
        } &
        pids+=($!)
        ((i++))
    done

    # Wait for all jobs
    for pid in "${pids[@]}"; do
        wait "$pid"
    done

    # Collect labeled results
    local combined_output=""
    local verbose_details=""

    for ((j=0; j<i; j++)); do
        local result=$(cat "$temp_dir/result_$j")
        local prompt_preview="${prompts[$j]:0:60}"
        if [[ ${#prompts[$j]} -gt 60 ]]; then
            prompt_preview="${prompt_preview}..."
        fi

        combined_output+="--- Prompt $((j+1)): $prompt_preview ---
$result

"
        verbose_details+="Prompt $((j+1)) (full): ${prompts[$j]}
Result: $result

"
    done

    rm -rf "$temp_dir"

    # Format output with metadata
    format_result "Parallel Prompts Result" "$combined_output" \
        "prompts_executed" "${#prompts[@]}" \
        "verbose_details" "$verbose_details"
}

# Map-reduce pattern
# Usage: map_reduce "mapper_prompt" "reducer_prompt" "input1" "input2" ...
# Supports piping: cat file | map_reduce "map: {{input}}" "reduce: {{results}}"
# Note: When piping, stdin becomes first input. Additional args become inputs 2, 3, etc.
map_reduce() {
    local stdin_data=$(read_stdin_if_available)
    local mapper_prompt="$1"
    local reducer_prompt="$2"
    shift 2

    local temp_dir=$(mktemp -d)
    local pids=()
    local i=0

    # Build inputs array: if stdin exists, prepend it to the args
    local -a inputs=()
    if [[ -n "$stdin_data" ]]; then
        inputs=("$stdin_data" "$@")
    else
        inputs=("$@")
    fi

    log_info "Map-Reduce: Starting map phase with ${#inputs[@]} inputs"

    # Map phase - parallel
    for input in "${inputs[@]}"; do
        {
            local actual_prompt="${mapper_prompt//\{\{input\}\}/$input}"
            llm_exec "$actual_prompt" > "$temp_dir/map_$i"
        } &
        pids+=($!)
        ((i++))
    done

    # Wait for map phase
    for pid in "${pids[@]}"; do
        wait "$pid"
    done

    log_info "Map-Reduce: Map phase complete, starting reduce phase"

    # Reduce phase - combine results
    local combined=""
    local map_results=""

    for ((j=0; j<i; j++)); do
        local map_result=$(cat "$temp_dir/map_$j")
        local input_preview="${inputs[$j]:0:40}"
        if [[ ${#inputs[$j]} -gt 40 ]]; then
            input_preview="${input_preview}..."
        fi

        combined+="Part $((j+1)):\n$map_result\n\n"
        map_results+="Input $((j+1)): $input_preview
Mapped result: $map_result

"
    done

    local actual_reducer="${reducer_prompt//\{\{results\}\}/$combined}"
    local final_result=$(llm_exec "$actual_reducer")

    rm -rf "$temp_dir"

    # Format output with phase summaries
    format_result "Map-Reduce Result" "$final_result" \
        "inputs_processed" "${#inputs[@]}" \
        "map_phase" "completed" \
        "reduce_phase" "completed" \
        "verbose_details" "$map_results"
}

# ============================================================================
# WORKFLOW: ORCHESTRATOR-WORKERS
# ============================================================================

# Orchestrator that delegates subtasks to workers with structured schema output
# Usage: orchestrator "main_task" "decompose_prompt" "worker_prompt_template"
# Supports piping: cat file | orchestrator "{{input}}" "decompose: {{task}}" "work: {{subtask}}"
# Returns: Synthesized final answer with metadata
orchestrator() {
    local stdin_data=$(read_stdin_if_available)
    local main_task="$1"
    local decompose_prompt="$2"
    local worker_template="$3"

    # Replace {{input}} in main_task and prompts
    main_task="${main_task//\{\{input\}\}/$stdin_data}"
    decompose_prompt="${decompose_prompt//\{\{input\}\}/$stdin_data}"
    worker_template="${worker_template//\{\{input\}\}/$stdin_data}"

    log_info "Orchestrator: Decomposing task with schema"

    # Schema for structured subtask decomposition
    local decompose_schema='subtask, priority int: 1-5 priority level, estimated_effort: small/medium/large'

    # Decompose into structured subtasks
    local subtasks_json=$(llm_exec_schema_multi "${decompose_prompt//\{\{task\}\}/$main_task}" "$decompose_schema")

    if [[ $? -ne 0 ]]; then
        log_error "Orchestrator: Failed to decompose task"
        return 1
    fi

    # Handle multiple schema formats returned by different models:
    # 1. Direct: {"items": [...]}
    # 2. Schema-wrapped: {"type":"object","properties":{"items":[...]}}
    # 3. Double-nested schema (gpt-5-nano): {"properties":{"items":{"type":"array","items":[...]}}}
    local items_path=".items"

    if ! echo "$subtasks_json" | jq -e '.items' >/dev/null 2>&1; then
        # Check for .properties.items.items (double-nested schema format)
        if echo "$subtasks_json" | jq -e '.properties.items.items' >/dev/null 2>&1; then
            # Check if it's an array
            if [[ "$(echo "$subtasks_json" | jq -r '.properties.items.items | type' 2>/dev/null)" == "array" ]]; then
                items_path=".properties.items.items"
                log_info "Orchestrator: Detected double-nested schema format, using .properties.items.items path"
            fi
        # Check for .properties.items (schema wrapper format)
        elif echo "$subtasks_json" | jq -e '.properties.items' >/dev/null 2>&1; then
            # Check if it's an array
            if [[ "$(echo "$subtasks_json" | jq -r '.properties.items | type' 2>/dev/null)" == "array" ]]; then
                items_path=".properties.items"
                log_info "Orchestrator: Detected schema-wrapped format, using .properties.items path"
            else
                log_error "Orchestrator: .properties.items exists but is not an array"
                log_error "Orchestrator: Response was: $subtasks_json"
                return 1
            fi
        else
            log_error "Orchestrator: No items array found in response"
            log_error "Orchestrator: Response was: $subtasks_json"
            return 1
        fi
    fi

    # Debug: Check if JSON is valid and has items
    if [[ "$LLM_VERBOSE" == "1" ]]; then
        local item_count=$(echo "$subtasks_json" | jq -r "${items_path} | length" 2>/dev/null)
        log_info "Orchestrator: Received $item_count items from decomposition"
    fi

    # Process subtasks from JSON array using detected path
    local results=""
    local subtask_count=0

    # Debug: Show the jq command we're using
    if [[ "$LLM_VERBOSE" == "1" ]]; then
        log_info "Orchestrator: Extracting items using jq path: ${items_path}[]"
    fi

    # Extract items using the correct path (either .items or .properties.items)
    while IFS= read -r subtask_obj; do
        [[ -z "$subtask_obj" ]] && continue

        if [[ "$LLM_VERBOSE" == "1" ]]; then
            log_info "Orchestrator: Raw subtask object: $subtask_obj"
        fi

        local subtask=$(echo "$subtask_obj" | jq -r '.subtask' 2>/dev/null)
        local priority=$(echo "$subtask_obj" | jq -r '.priority' 2>/dev/null)
        local effort=$(echo "$subtask_obj" | jq -r '.estimated_effort' 2>/dev/null)

        log_info "Orchestrator: Processing subtask $((subtask_count + 1)) (priority: $priority, effort: $effort)"
        log_info "  → $subtask"

        local worker_prompt="${worker_template//\{\{subtask\}\}/$subtask}"
        # Redirect stdin to /dev/null to prevent llm_exec from consuming the while loop's input
        local result=$(llm_exec "$worker_prompt" </dev/null)

        if [[ $? -ne 0 ]]; then
            log_error "Orchestrator: Worker failed for subtask $((subtask_count + 1))"
            # Continue processing other subtasks even if one fails
        fi

        results+="Subtask $((++subtask_count)) (Priority: $priority, Effort: $effort):\n$subtask\nResult: $result\n\n"
    done < <(echo "$subtasks_json" | jq -c "${items_path}[]" 2>/dev/null)

    # Check if we processed any subtasks
    if [[ $subtask_count -eq 0 ]]; then
        log_error "Orchestrator: No subtasks were processed"
        return 1
    fi

    # Synthesize results with schema
    log_info "Orchestrator: Synthesizing $subtask_count results"

    local synthesis_schema='final_answer, confidence number: 0-1 confidence score, subtasks_completed int: number of subtasks'
    local synthesis_result=$(llm_exec_schema "Synthesize these results into a final answer:\n\n$results" "$synthesis_schema")

    if [[ $? -ne 0 ]]; then
        log_error "Orchestrator: Failed to synthesize results"
        format_result "Orchestrator Result" "$results" \
            "subtasks_processed" "$subtask_count" \
            "status" "synthesis_failed"
        return 1
    fi

    # Extract and display synthesis
    local final_answer=$(extract_json_field "$synthesis_result" "final_answer")
    local confidence=$(extract_json_field "$synthesis_result" "confidence")
    local completed=$(extract_json_field "$synthesis_result" "subtasks_completed")

    log_info "Orchestrator: Completed $completed subtasks (confidence: $confidence)"

    # Format output with metadata
    format_result "Orchestrator Result" "$final_answer" \
        "subtasks_completed" "$completed" \
        "confidence" "$confidence" \
        "verbose_details" "$results"
}

# Dynamic orchestrator with feedback loop
# Usage: orchestrator_dynamic "task" "plan_prompt" "execute_prompt" "evaluate_prompt"
# Supports piping: cat file | orchestrator_dynamic "{{input}}" "plan: {{task}}" "exec: {{plan}}" "eval: {{results}}"
orchestrator_dynamic() {
    local stdin_data=$(read_stdin_if_available)
    local task="$1"
    local plan_prompt="$2"
    local execute_prompt="$3"
    local evaluate_prompt="$4"

    # Replace {{input}} in task and prompts
    task="${task//\{\{input\}\}/$stdin_data}"
    plan_prompt="${plan_prompt//\{\{input\}\}/$stdin_data}"
    execute_prompt="${execute_prompt//\{\{input\}\}/$stdin_data}"
    evaluate_prompt="${evaluate_prompt//\{\{input\}\}/$stdin_data}"

    local max_iterations=5
    local iteration=0
    local state="planning"
    local plan=""
    local results=""
    local iteration_history=""

    while [[ $iteration -lt $max_iterations ]]; do
        case $state in
            planning)
                log_info "Dynamic Orchestrator: Planning (iteration $iteration)"
                plan=$(llm_exec "${plan_prompt//\{\{task\}\}/$task}")
                iteration_history+="Iteration $((iteration+1)) - Planning: Created plan for '$task'
"
                state="executing"
                ;;

            executing)
                log_info "Dynamic Orchestrator: Executing"
                local exec_prompt="${execute_prompt//\{\{plan\}\}/$plan}"
                results=$(llm_exec "$exec_prompt")
                iteration_history+="Iteration $((iteration+1)) - Executing: Processed plan
"
                state="evaluating"
                ;;

            evaluating)
                log_info "Dynamic Orchestrator: Evaluating"
                local eval_prompt="${evaluate_prompt//\{\{results\}\}/$results}"
                local evaluation=$(llm_exec "$eval_prompt")
                iteration_history+="Iteration $((iteration+1)) - Evaluating: $evaluation
"

                if [[ "$evaluation" == *"complete"* ]] || [[ "$evaluation" == *"done"* ]]; then
                    # Task completed successfully
                    format_result "Dynamic Orchestrator Result" "$results" \
                        "iterations" "$((iteration+1))" \
                        "exit_reason" "task_completed" \
                        "final_state" "$state" \
                        "verbose_details" "$iteration_history"
                    return 0
                fi

                state="planning"
                task="Refine based on: $evaluation"
                ;;
        esac

        ((iteration++))
    done

    # Max iterations reached
    format_result "Dynamic Orchestrator Result" "$results" \
        "iterations" "$iteration" \
        "exit_reason" "max_iterations_reached" \
        "final_state" "$state" \
        "verbose_details" "$iteration_history"
}

# ============================================================================
# WORKFLOW: EVALUATOR-OPTIMIZER
# ============================================================================

# Evaluate and optimize outputs iteratively with structured schema output
# Usage: evaluate_optimize "initial_prompt" "evaluator_prompt" "optimizer_prompt" [max_iterations] [quality_threshold]
# Supports piping: cat file | evaluate_optimize "analyze: {{input}}" "eval: {{output}}" "optimize: {{output}}"
# Returns: Optimized output based on quality scores
evaluate_optimize() {
    local stdin_data=$(read_stdin_if_available)
    local initial_prompt="$1"
    local evaluator_prompt="$2"
    local optimizer_prompt="$3"
    local max_iterations="${4:-3}"
    local quality_threshold="${5:-8}"  # Default quality score threshold: 8/10

    # Replace {{input}} in prompts
    initial_prompt="${initial_prompt//\{\{input\}\}/$stdin_data}"
    evaluator_prompt="${evaluator_prompt//\{\{input\}\}/$stdin_data}"
    optimizer_prompt="${optimizer_prompt//\{\{input\}\}/$stdin_data}"

    local current_output=$(llm_exec "$initial_prompt")
    local iteration=0

    # Schema for evaluation
    local eval_schema='quality_score int: 1-10 rating, meets_criteria bool: true if acceptable, issues: list of problems found, suggestions: list of improvements'

    # Schema for optimization
    local opt_schema='improved_output, changes_made: what was changed, improvement_score int: 1-10 improvement rating'

    # Track optimization history for verbose output
    local optimization_history=""
    local final_quality_score=""
    local final_issues=""
    local exit_reason=""

    while [[ $iteration -lt $max_iterations ]]; do
        log_info "Evaluate-Optimize: Iteration $((iteration+1))"

        # Evaluate current output with schema
        local eval_prompt="${evaluator_prompt//\{\{output\}\}/$current_output}"
        local evaluation=$(llm_exec_schema "$eval_prompt" "$eval_schema")

        if [[ $? -ne 0 ]]; then
            log_error "Evaluate-Optimize: Evaluation failed"
            exit_reason="evaluation_failed"
            format_result "Evaluation-Optimization Result" "$current_output" \
                "iterations" "$iteration" \
                "exit_reason" "$exit_reason"
            return 1
        fi

        # Extract evaluation metrics
        local quality_score=$(extract_json_field "$evaluation" "quality_score")
        local meets_criteria=$(extract_json_field "$evaluation" "meets_criteria")
        local issues=$(extract_json_field "$evaluation" "issues")
        local suggestions=$(extract_json_field "$evaluation" "suggestions")

        log_info "Quality score: $quality_score/10 (threshold: $quality_threshold)"
        log_info "Issues: $issues"

        # Track final scores
        final_quality_score="$quality_score"
        final_issues="$issues"

        # Check if output meets quality threshold
        if [[ "$quality_score" -ge "$quality_threshold" ]] || [[ "$meets_criteria" == "true" ]]; then
            log_info "Evaluate-Optimize: Output meets criteria (score: $quality_score)"
            exit_reason="quality_threshold_met"
            format_result "Evaluation-Optimization Result" "$current_output" \
                "iterations" "$((iteration + 1))" \
                "final_quality_score" "$final_quality_score/10" \
                "quality_threshold" "$quality_threshold/10" \
                "exit_reason" "$exit_reason" \
                "issues_found" "$final_issues" \
                "verbose_details" "$optimization_history"
            return 0
        fi

        # Optimize based on structured evaluation
        log_info "Evaluate-Optimize: Optimizing based on feedback"

        local opt_prompt="${optimizer_prompt//\{\{output\}\}/$current_output}"
        opt_prompt="${opt_prompt//\{\{evaluation\}\}/$evaluation}"

        local optimization=$(llm_exec_schema "$opt_prompt" "$opt_schema")

        if [[ $? -ne 0 ]]; then
            log_error "Evaluate-Optimize: Optimization failed"
            exit_reason="optimization_failed"
            format_result "Evaluation-Optimization Result" "$current_output" \
                "iterations" "$iteration" \
                "exit_reason" "$exit_reason" \
                "last_quality_score" "$final_quality_score/10"
            return 1
        fi

        # Extract optimized output
        current_output=$(extract_json_field "$optimization" "improved_output")
        local changes=$(extract_json_field "$optimization" "changes_made")
        local improvement=$(extract_json_field "$optimization" "improvement_score")

        log_info "Changes made: $changes (improvement: $improvement/10)"

        # Add to history
        optimization_history+="Iteration $((iteration + 1)): Score $quality_score/10 → Changes: $changes (improvement: $improvement/10)
"

        ((iteration++))
    done

    log_info "Evaluate-Optimize: Max iterations reached"
    exit_reason="max_iterations_reached"
    format_result "Evaluation-Optimization Result" "$current_output" \
        "iterations" "$iteration" \
        "final_quality_score" "$final_quality_score/10" \
        "quality_threshold" "$quality_threshold/10" \
        "exit_reason" "$exit_reason" \
        "issues_remaining" "$final_issues" \
        "verbose_details" "$optimization_history"
}

# A/B testing for prompts
# Usage: ab_test "input" "prompt_a" "prompt_b" "evaluator_prompt" [output_mode]
# Output modes: "clean" (default - returns only selected variant), "with_metadata" (returns formatted result with metadata)
# Supports piping: cat file | ab_test "{{input}}" "prompt_a: {{input}}" "prompt_b: {{input}}" "evaluate"
ab_test() {
    local stdin_data=$(read_stdin_if_available)
    local input="$1"
    local prompt_a="$2"
    local prompt_b="$3"
    local evaluator="$4"
    local output_mode="${5:-clean}"  # Default to clean output

    # Replace {{input}} in input parameter
    input="${input//\{\{input\}\}/$stdin_data}"

    log_info "A/B Test: Generating variant A"
    local result_a=$(llm_exec "${prompt_a//\{\{input\}\}/$input}")

    log_info "A/B Test: Generating variant B"
    local result_b=$(llm_exec "${prompt_b//\{\{input\}\}/$input}")

    log_info "A/B Test: Evaluating results with schema"

    # Schema for structured evaluation
    local eval_schema='selected_variant: A or B, reasoning: why this variant is better, confidence number: 0-1 confidence score'

    local comparison="Compare these two results and select the better one.

Result A:
$result_a

Result B:
$result_b

Evaluation criteria: $evaluator"

    local evaluation=$(llm_exec_schema "$comparison" "$eval_schema")

    if [[ $? -ne 0 ]]; then
        log_error "A/B Test: Evaluation failed"
        echo "$result_a"  # Fallback to variant A
        return 1
    fi

    # Extract structured evaluation
    local selected=$(extract_json_field "$evaluation" "selected_variant")
    local reasoning=$(extract_json_field "$evaluation" "reasoning")
    local confidence=$(extract_json_field "$evaluation" "confidence")

    # Determine which variant was selected
    local selected_variant selected_output
    if [[ "$selected" =~ ^[Aa] ]]; then
        selected_variant="A"
        selected_output="$result_a"
        log_info "A/B Test: Selected variant A (confidence: $confidence)"
    else
        selected_variant="B"
        selected_output="$result_b"
        log_info "A/B Test: Selected variant B (confidence: $confidence)"
    fi

    # Return based on output mode
    if [[ "$output_mode" == "with_metadata" ]]; then
        # Prepare verbose details showing both variants
        local verbose_details="Variant A:
$result_a

Variant B:
$result_b"

        # Format output with metadata
        format_result "A/B Test Result" "$selected_output" \
            "selected_variant" "$selected_variant" \
            "confidence" "$confidence" \
            "reasoning" "$reasoning" \
            "verbose_details" "$verbose_details"
    else
        # Clean output - just return the selected variant
        echo "$selected_output"
    fi
}

# ============================================================================
# AGENTS: Autonomous loops with memory and tools
# ============================================================================

# Simple agent with memory
# Usage: agent_loop "goal" "think_prompt" "act_prompt" "observe_prompt" [max_steps]
# Supports piping: cat file | agent_loop "{{input}}" "think: {{goal}}" "act: {{thought}}" "observe: {{action}}"
agent_loop() {
    local stdin_data=$(read_stdin_if_available)
    local goal="$1"
    local think_prompt="$2"
    local act_prompt="$3"
    local observe_prompt="$4"
    local max_steps="${5:-10}"

    # Replace {{input}} in goal and prompts
    goal="${goal//\{\{input\}\}/$stdin_data}"
    think_prompt="${think_prompt//\{\{input\}\}/$stdin_data}"
    act_prompt="${act_prompt//\{\{input\}\}/$stdin_data}"
    observe_prompt="${observe_prompt//\{\{input\}\}/$stdin_data}"

    local memory=""
    local step=0
    
    while [[ $step -lt $max_steps ]]; do
        log_info "Agent: Step $((step+1))"
        
        # Think
        local think_input="Goal: $goal\nMemory: $memory\n$think_prompt"
        local thought=$(llm_exec "$think_input")
        memory+="\nThought: $thought"
        
        # Act
        local act_input="Goal: $goal\nThought: $thought\n$act_prompt"
        local action=$(llm_exec "$act_input")
        memory+="\nAction: $action"
        
        # Observe
        local observe_input="Action: $action\n$observe_prompt"
        local observation=$(llm_exec "$observe_input")
        memory+="\nObservation: $observation"
        
        # Check if goal achieved
        if [[ "$observation" == *"complete"* ]] || [[ "$observation" == *"achieved"* ]]; then
            log_info "Agent: Goal achieved"
            echo "$memory"
            return 0
        fi
        
        ((step++))
    done
    
    log_info "Agent: Max steps reached"
    echo "$memory"
}

# ReAct pattern agent with structured schema output
# Usage: react_agent "task" "tool_descriptions" [max_steps]
# Supports piping: cat file | react_agent "{{input}}" "tool_descriptions" [max_steps]
# Returns: Structured reasoning history with thoughts, actions, and observations
react_agent() {
    local stdin_data=$(read_stdin_if_available)
    local task="$1"
    local tools="$2"
    local max_steps="${3:-10}"

    # Replace {{input}} in task and tools
    task="${task//\{\{input\}\}/$stdin_data}"
    tools="${tools//\{\{input\}\}/$stdin_data}"

    local history=""
    local step=0
    local last_confidence=""
    local final_thought=""

    # Schema for structured ReAct response
    local schema='thought: reasoning process, action: tool name or finish, action_params: parameters for the action if any, confidence number: 0-1 confidence score'

    local react_prompt="You are a ReAct agent. Respond with structured reasoning.

Available tools:
$tools

Task: $task

History:
{{history}}

Based on the above, what is your next thought and action?"

    while [[ $step -lt $max_steps ]]; do
        log_info "ReAct Agent: Step $((step+1))"

        local prompt="${react_prompt//\{\{history\}\}/$history}"
        local response=$(llm_exec_schema "$prompt" "$schema")

        if [[ $? -ne 0 ]]; then
            log_error "ReAct Agent: Failed to get structured response"
            format_result "ReAct Agent Result" "$history" \
                "steps_taken" "$step" \
                "exit_reason" "error" \
                "final_confidence" "$last_confidence"
            return 1
        fi

        # Validate and extract structured response
        if ! validate_schema_response "$response" "thought action confidence"; then
            log_error "ReAct Agent: Invalid response structure"
            format_result "ReAct Agent Result" "$history" \
                "steps_taken" "$step" \
                "exit_reason" "invalid_response" \
                "final_confidence" "$last_confidence"
            return 1
        fi

        local thought=$(extract_json_field "$response" "thought")
        local action=$(extract_json_field "$response" "action")
        local action_params=$(extract_json_field "$response" "action_params")
        local confidence=$(extract_json_field "$response" "confidence")

        log_info "Thought: $thought"
        log_info "Action: $action (confidence: $confidence)"

        history+="\nStep $((step+1)):\nThought: $thought\nAction: $action\nParams: $action_params\nConfidence: $confidence"
        last_confidence="$confidence"
        final_thought="$thought"

        # Check if finished
        if [[ "$action" == "finish" ]] || [[ "$action" == *"finish"* ]]; then
            log_info "ReAct Agent: Task completed"
            ((step++))
            format_result "ReAct Agent Result" "$final_thought" \
                "steps_taken" "$step" \
                "exit_reason" "task_completed" \
                "final_confidence" "$confidence" \
                "verbose_details" "$history"
            return 0
        fi

        # Simulate tool execution (replace with actual tool calls)
        local observation="[Tool executed: $action with params: $action_params]"
        history+="\nObservation: $observation"

        ((step++))
    done

    log_info "ReAct Agent: Max steps reached"
    format_result "ReAct Agent Result" "$final_thought" \
        "steps_taken" "$step" \
        "exit_reason" "max_steps_reached" \
        "final_confidence" "$last_confidence" \
        "verbose_details" "$history"
}

# ============================================================================
# ADVANCED PATTERNS
# ============================================================================

# Self-consistency: Multiple samples with voting
# Usage: self_consistency "prompt" [num_samples]
# Supports piping: cat file | self_consistency "analyze: {{input}}" [num_samples]
self_consistency() {
    local stdin_data=$(read_stdin_if_available)
    local prompt="$1"
    local num_samples="${2:-5}"

    # Replace {{input}} in prompt
    prompt="${prompt//\{\{input\}\}/$stdin_data}"

    local temp_dir=$(mktemp -d)
    local pids=()

    log_info "Self-Consistency: Generating $num_samples samples"

    # Generate multiple samples in parallel
    for ((i=0; i<num_samples; i++)); do
        {
            llm_exec "$prompt" > "$temp_dir/sample_$i"
        } &
        pids+=($!)
    done

    # Wait for all samples
    for pid in "${pids[@]}"; do
        wait "$pid"
    done

    # Collect all samples
    local all_samples=""
    local samples_list=""

    for ((i=0; i<num_samples; i++)); do
        local sample_content=$(cat "$temp_dir/sample_$i")
        all_samples+="Sample $((i+1)):\n$sample_content\n\n"
        samples_list+="Sample $((i+1)): $sample_content

"
    done

    log_info "Self-Consistency: Aggregating results"

    # Use schema to get consensus answer with confidence score
    local schema='consensus_answer: the most consistent answer, consensus_score number: 0-1 agreement level, reasoning: why this is the consensus'
    local aggregation_result=$(llm_exec_schema "Given these $num_samples different answers to the same question, determine the most consistent and accurate answer:\n\n$all_samples" "$schema")

    if [[ $? -ne 0 ]]; then
        log_error "Self-Consistency: Aggregation failed"
        rm -rf "$temp_dir"
        return 1
    fi

    # Extract consensus details
    local consensus_answer=$(extract_json_field "$aggregation_result" "consensus_answer")
    local consensus_score=$(extract_json_field "$aggregation_result" "consensus_score")
    local reasoning=$(extract_json_field "$aggregation_result" "reasoning")

    rm -rf "$temp_dir"

    # Format output with consensus metrics
    format_result "Self-Consistency Result" "$consensus_answer" \
        "samples_generated" "$num_samples" \
        "consensus_score" "$consensus_score" \
        "reasoning" "$reasoning" \
        "verbose_details" "$samples_list"
}

# Tree of thoughts
# Usage: tree_of_thoughts "problem" "generate_prompt" "evaluate_prompt" "select_prompt" [depth] [branches]
# Supports piping: cat file | tree_of_thoughts "{{input}}" "gen: {{thought}}" "eval: {{candidates}}" "select: {{evaluations}}"
tree_of_thoughts() {
    local stdin_data=$(read_stdin_if_available)
    local problem="$1"
    local generate="$2"
    local evaluate="$3"
    local select="$4"
    local depth="${5:-3}"
    local branches="${6:-3}"

    # Replace {{input}} in all prompts
    problem="${problem//\{\{input\}\}/$stdin_data}"
    generate="${generate//\{\{input\}\}/$stdin_data}"
    evaluate="${evaluate//\{\{input\}\}/$stdin_data}"
    select="${select//\{\{input\}\}/$stdin_data}"
    
    local explore_tree
    explore_tree() {
        local current_thought="$1"
        local current_depth="$2"
        
        if [[ $current_depth -ge $depth ]]; then
            echo "$current_thought"
            return
        fi
        
        log_info "Tree of Thoughts: Depth $current_depth, generating $branches branches"
        
        # Generate candidate thoughts
        local candidates=""
        for ((i=0; i<branches; i++)); do
            local gen_prompt="${generate//\{\{thought\}\}/$current_thought}"
            local candidate=$(llm_exec "$gen_prompt")
            candidates+="Candidate $((i+1)): $candidate\n"
        done
        
        # Evaluate candidates
        local eval_prompt="${evaluate//\{\{candidates\}\}/$candidates}"
        local evaluations=$(llm_exec "$eval_prompt")
        
        # Select best candidate
        local select_prompt="${select//\{\{evaluations\}\}/$evaluations}"
        local best=$(llm_exec "$select_prompt")
        
        # Recurse
        explore_tree "$best" $((current_depth + 1))
    }
    
    explore_tree "$problem" 0
}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Save conversation/agent state
save_state() {
    local state_file="$1"
    local state_data="$2"
    echo "$state_data" > "$state_file"
    log_info "State saved to $state_file"
}

# Load conversation/agent state
load_state() {
    local state_file="$1"
    if [[ -f "$state_file" ]]; then
        cat "$state_file"
        log_info "State loaded from $state_file"
    else
        log_error "State file not found: $state_file"
        return 1
    fi
}

# Export functions for use in other scripts
export -f read_stdin_if_available llm_exec parse_json log_info log_error
export -f format_result format_result_text format_result_json
export -f llm_exec_schema llm_exec_schema_multi extract_json_field extract_json_array validate_schema_response
export -f prompt_chain prompt_chain_transform
export -f route_by_classifier route_conditional
export -f parallel_prompts map_reduce
export -f orchestrator orchestrator_dynamic
export -f evaluate_optimize ab_test
export -f agent_loop react_agent
export -f self_consistency tree_of_thoughts
export -f save_state load_state

# ============================================================================
# EXAMPLE USAGE
# ============================================================================

# Only run examples if script is executed directly with --examples flag
if [[ "${BASH_SOURCE[0]}" == "${0}" ]] && [[ "$1" == "--examples" ]]; then
    echo "Running examples..."
    
    # Example 1: Prompt chaining
    echo -e "\n=== Prompt Chain Example ==="
    result=$(prompt_chain \
        "List 3 interesting historical events" \
        "Pick the most interesting from: {{previous}}" \
        "Write a haiku about: {{previous}}")
    echo "$result"
    
    # Example 2: Parallel execution
    echo -e "\n=== Parallel Prompts Example ==="
    parallel_prompts \
        "Write a joke about programming" \
        "Write a joke about mathematics" \
        "Write a joke about physics"
    
    # Example 3: Map-reduce
    echo -e "\n=== Map-Reduce Example ==="
    map_reduce \
        "Summarize this text: {{input}}" \
        "Combine these summaries into one: {{results}}" \
        "The quick brown fox jumps over the lazy dog" \
        "Lorem ipsum dolor sit amet, consectetur adipiscing elit" \
        "To be or not to be, that is the question"
fi
