#!/bin/bash
# Example scripts demonstrating the LLM Agent Framework
set -euo pipefail

# Get the directory where this script lives (for robust path handling)
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"

# Source the main framework first (using . for POSIX portability)
. "${SCRIPT_DIR}/llm-bash.sh"

# ============================================================================
# OUTPUT FORMAT CONFIGURATION
# ============================================================================
# All workflow functions support configurable output formats via LLM_OUTPUT_FORMAT:
#
# LLM_OUTPUT_FORMAT="text"  (default) - Human-readable with labeled metadata
# LLM_OUTPUT_FORMAT="json"            - Structured JSON for machine parsing
#
# Examples:
#   LLM_OUTPUT_FORMAT="text" ab_test "input" "prompt_a" "prompt_b" "evaluator"
#   LLM_OUTPUT_FORMAT="json" orchestrator "task" "decompose" "worker"
#
# With LLM_VERBOSE=1, additional details are included in the output
#
# ============================================================================
# EXAMPLE 1: Code Review Pipeline (Prompt Chaining + Evaluation)
# ============================================================================

code_review() {
    local file="$1"
    local code=$(cat "$file")

    echo "Starting code review for $file..."

    # prompt_chain: Chain multiple prompts where each output feeds into the next
    # Arguments:
    #   $1: First prompt - initial analysis
    #   $2: Second prompt - uses {{previous}} to reference first output
    #   $3: Third prompt - uses {{previous}} to reference second output
    #   ... (can chain as many prompts as needed)
    prompt_chain \
        "Analyze this code for potential bugs and issues: $code" \
        "Based on the issues found: {{previous}}, suggest specific fixes" \
        "Rate the code quality and provide a summary: {{previous}}"
}

# ============================================================================
# EXAMPLE 2: Research Assistant (Map-Reduce + Orchestrator)
# ============================================================================

research_topic() {
    local topic="$1"

    echo "Researching topic: $topic"

    # orchestrator: Delegates subtasks to workers using schema-based decomposition
    # Arguments:
    #   $1: main_task - The overall task to accomplish
    #   $2: decompose_prompt - Prompt to break task into subtasks (use {{task}} placeholder)
    #   $3: worker_prompt_template - Prompt for each subtask (use {{subtask}} placeholder)
    # Returns: Synthesized final answer with metadata (confidence, subtasks_completed)
    orchestrator \
        "$topic" \
        "Break down this research topic into 3-5 specific questions: {{task}}" \
        "Research and provide detailed answer for: {{subtask}}"
}

# ============================================================================
# EXAMPLE 3: Content Generator with A/B Testing
# ============================================================================

generate_optimized_content() {
    local topic="$1"
    local audience="$2"

    echo "Generating content for topic: $topic, audience: $audience"

    # ab_test: Test two different prompts and select the better one using schema-based evaluation
    # Arguments:
    #   $1: input - The input to process with both prompts
    #   $2: prompt_a - First prompt variant (use {{input}} placeholder)
    #   $3: prompt_b - Second prompt variant (use {{input}} placeholder)
    #   $4: evaluator_prompt - Prompt to compare and select the better result
    #   $5: output_mode - "clean" (default, returns only selected variant) or "with_metadata"
    # Returns: By default, the selected variant output only
    ab_test \
        "Topic: $topic, Audience: $audience" \
        "Write a formal, professional article about {{input}}" \
        "Write an engaging, conversational article about {{input}}" \
        "Which article better suits the target audience and why?"
}

# ============================================================================
# EXAMPLE 4: Data Analysis Pipeline (Parallel + Chain)
# ============================================================================

analyze_dataset() {
    local data="$1"

    echo "Analyzing dataset..."

    # parallel_prompts: Run multiple prompts in parallel and collect results
    # Arguments:
    #   $1, $2, $3, ... - Each argument is a prompt to execute in parallel
    # Returns: Formatted result with labeled outputs and metadata (prompts_executed, verbose_details)
    results=$(parallel_prompts \
        "Identify patterns in this data: $data" \
        "Find anomalies in this data: $data" \
        "Generate statistics for this data: $data" \
        "Suggest visualizations for this data: $data")

    # Synthesize results
    llm_exec "Synthesize these parallel analyses into a comprehensive report: $results"
}

# ============================================================================
# EXAMPLE 5: Decision Support System (Router + Evaluator)
# ============================================================================

decision_support() {
    local decision="$1"

    echo "Analyzing decision: $decision"

    # route_by_classifier: Route to different prompts based on schema-based classification
    # Arguments:
    #   $1: input - The input to classify and route
    #   $2: classifier_prompt - Prompt to classify the input
    #   $3+: route_spec - Format "route_name:prompt_template" (use {{input}} placeholder)
    # Returns: Result from the selected route with confidence and reasoning logged
    route_by_classifier \
        "$decision" \
        "Classify this as technical, business, or strategic decision" \
        "technical:Analyze technical implications and risks: {{input}}" \
        "business:Analyze ROI and business impact: {{input}}" \
        "strategic:Analyze long-term strategic implications: {{input}}"
}

# ============================================================================
# EXAMPLE 6: Interactive Debugging Assistant (ReAct Agent)
# ============================================================================

debug_assistant() {
    local error="$1"
    local context="$2"

    echo "Starting debugging assistant..."

    # react_agent: ReAct pattern agent with structured schema output
    # Arguments:
    #   $1: task - The task for the agent to accomplish
    #   $2: tool_descriptions - List of available tools the agent can use
    #   $3: max_steps - Maximum number of reasoning steps (default: 10)
    # Returns: Structured reasoning history with thoughts, actions, params, and confidence
    react_agent \
        "Debug this error: $error with context: $context" \
        "Available tools:
        - analyze_stack_trace: Analyze error stack trace
        - check_dependencies: Check for dependency issues
        - suggest_fix: Suggest potential fixes
        - test_fix: Validate proposed solution" \
        5
}

# ============================================================================
# EXAMPLE 7: Documentation Generator (Chain + Optimization)
# ============================================================================

generate_docs() {
    local code_file="$1"
    local code=$(cat "$code_file")

    echo "Generating documentation for $code_file..."

    # evaluate_optimize: Iteratively improve output using schema-based quality scoring
    # Arguments:
    #   $1: initial_prompt - Prompt to generate initial output
    #   $2: evaluator_prompt - Prompt to evaluate quality (use {{output}} placeholder)
    #   $3: optimizer_prompt - Prompt to improve output (use {{output}} and {{evaluation}} placeholders)
    #   $4: max_iterations - Maximum optimization iterations (default: 3)
    #   $5: quality_threshold - Quality score 1-10 to stop optimization (default: 8)
    # Returns: Optimized output meeting quality threshold with scores and changes logged
    evaluate_optimize \
        "Generate comprehensive documentation for this code: $code" \
        "Evaluate this documentation for completeness, clarity, and accuracy: {{output}}" \
        "Improve this documentation based on the evaluation: {{output}} \n\nEvaluation: {{evaluation}}" \
        3
}

# ============================================================================
# EXAMPLE 8: Multi-Stage Data Pipeline
# ============================================================================

data_pipeline() {
    local input_file="$1"
    local data=$(cat "$input_file")

    echo "Running data pipeline..."

    # Define transformation functions
    clean_data() {
        echo "$1" | tr '[:lower:]' '[:upper:]'  # Simple example
    }

    # prompt_chain_transform: Chain prompts with transformations between steps
    # Arguments (alternating pattern):
    #   $1: prompt (use {{previous}} placeholder)
    #   $2: transformation_function_name (bash function to transform output)
    #   $3: next_prompt (use {{previous}} placeholder)
    #   $4: next_transformation_function_name
    #   ... (alternate prompts and transformations)
    # Returns: Final output after all prompts and transformations
    prompt_chain_transform \
        "Extract key information from: $data" \
        "clean_data" \
        "Analyze the cleaned data: {{previous}}" \
        "echo" \
        "Generate insights from: {{previous}}"
}

# ============================================================================
# EXAMPLE 9: Quality Assurance Bot (Self-Consistency)
# ============================================================================

qa_check() {
    local content="$1"

    echo "Running QA check with self-consistency..."

    # self_consistency: Generate multiple samples and select the most consistent answer
    # Arguments:
    #   $1: prompt - The prompt to execute multiple times
    #   $2: num_samples - Number of parallel samples to generate (default: 5)
    # Returns: Aggregated consensus answer from all samples
    self_consistency \
        "Check this content for factual accuracy, grammar, and clarity: $content" \
        3
}

# ============================================================================
# EXAMPLE 10: Complex Problem Solver (Tree of Thoughts)
# ============================================================================

solve_complex_problem() {
    local problem="$1"

    echo "Solving complex problem using tree of thoughts..."

    # tree_of_thoughts: Explore multiple solution paths recursively
    # Arguments:
    #   $1: problem - The initial problem or thought to explore
    #   $2: generate_prompt - Prompt to generate candidate next steps (use {{thought}} placeholder)
    #   $3: evaluate_prompt - Prompt to evaluate candidates (use {{candidates}} placeholder)
    #   $4: select_prompt - Prompt to select best candidate (use {{evaluations}} placeholder)
    #   $5: depth - How deep to explore the tree (default: 3)
    #   $6: branches - Number of branches per node (default: 3)
    # Returns: Selected solution path after tree exploration
    tree_of_thoughts \
        "$problem" \
        "Generate a possible next step for solving: {{thought}}" \
        "Evaluate these solution steps: {{candidates}}" \
        "Select the most promising approach from: {{evaluations}}" \
        3 \
        3
}

# ============================================================================
# EXAMPLE 11: Customer Support Router (Schema-Based Classification)
# ============================================================================
# This example demonstrates the route_by_classifier function with structured
# schema output. The classifier now returns:
#   - route: the selected category
#   - confidence: 0-1 confidence score
#   - reasoning: explanation for the classification
# These are automatically logged by route_by_classifier for better observability.

customer_support_router() {
    local query="$1"

    echo "╔════════════════════════════════════════════════════════════════════╗"
    echo "║ Customer Support Router (with Schema-Based Classification)        ║"
    echo "╚════════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Query: $query"
    echo ""
    echo "Classifying with structured schema output..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # route_by_classifier: Route to different prompts based on schema-based classification
    # Arguments:
    #   $1: input - The customer query to classify and route
    #   $2: classifier_prompt - Prompt to classify the input into a category
    #   $3+: route_spec - Format "route_name:prompt_template" (use {{input}} placeholder)
    # Returns: Formatted result with metadata (selected_route, confidence, reasoning)
    local result=$(route_by_classifier \
        "$query" \
        "Classify this customer query as one of: technical, billing, refund, account, or general" \
        "technical:You are a technical support specialist. Provide detailed technical assistance for: {{input}}" \
        "billing:You are a billing specialist. Help with this billing question: {{input}}" \
        "refund:You are a refund specialist. Process this refund request professionally: {{input}}" \
        "account:You are an account specialist. Help with this account-related issue: {{input}}" \
        "general:You are a general customer service representative. Provide friendly assistance for: {{input}}")

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Response:"
    echo "$result"
}

# ============================================================================
# EXAMPLE 12: Output Format Demonstration
# ============================================================================

output_format_demo() {
    local query="$1"

    echo "╔════════════════════════════════════════════════════════════════════╗"
    echo "║ Output Format Demonstration                                       ║"
    echo "╚════════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Demonstrating different output formats for the same query..."
    echo ""

    # Text format (default) - human-readable with labeled metadata
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "TEXT FORMAT (Human-Readable):"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    LLM_OUTPUT_FORMAT="text" route_by_classifier \
        "$query" \
        "Classify this as: technical, general, or urgent" \
        "technical:Provide technical help for: {{input}}" \
        "general:Provide general assistance for: {{input}}" \
        "urgent:Urgent support needed for: {{input}}"

    echo ""
    echo ""

    # JSON format - structured for machine parsing
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "JSON FORMAT (Machine-Parseable):"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    LLM_OUTPUT_FORMAT="json" route_by_classifier \
        "$query" \
        "Classify this as: technical, general, or urgent" \
        "technical:Provide technical help for: {{input}}" \
        "general:Provide general assistance for: {{input}}" \
        "urgent:Urgent support needed for: {{input}}"

    echo ""
    echo ""
    echo "Note: Use jq to parse JSON output, e.g.:"
    echo "  result=\$(LLM_OUTPUT_FORMAT=\"json\" route_by_classifier ...)"
    echo "  echo \"\$result\" | jq -r '.metadata.selected_route'"
    echo "  echo \"\$result\" | jq -r '.metadata.confidence'"
}

# ============================================================================
# EXAMPLE 13: Debugging - Show Intermediate Steps
# ============================================================================

debug_verbose_example() {
    echo "Running prompt chain with verbose debugging enabled..."
    echo ""

    # Enable verbose mode to see all prompts and responses
    LLM_VERBOSE=1 prompt_chain \
        "List 3 colors" \
        "Pick one color from: {{previous}}" \
        "Write one sentence about: {{previous}}"
}

# ============================================================================
# MAIN MENU
# ============================================================================

show_menu() {
    echo "
    ========================================
    LLM Agent Framework - Example Menu
    ========================================
    1. Code Review
    2. Research Assistant
    3. Content Generator (with A/B testing)
    4. Data Analysis Pipeline
    5. Decision Support
    6. Debugging Assistant
    7. Documentation Generator
    8. Data Pipeline
    9. Quality Assurance Check
    10. Complex Problem Solver
    11. Customer Support Router (Classifier)
    12. Output Format Demonstration
    13. Verbose Debugging Example
    0. Exit
    ========================================
    "
}

# Interactive mode
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -eq 0 ]]; then
        while true; do
            show_menu
            read -p "Select an option: " choice
            
            case $choice in
                1)
                    read -p "Enter file path to review: " file
                    code_review "$file"
                    ;;
                2)
                    read -p "Enter research topic: " topic
                    research_topic "$topic"
                    ;;
                3)
                    read -p "Enter content topic: " topic
                    read -p "Enter target audience: " audience
                    generate_optimized_content "$topic" "$audience"
                    ;;
                4)
                    read -p "Enter data or file path: " data
                    analyze_dataset "$data"
                    ;;
                5)
                    read -p "Enter decision to analyze: " decision
                    decision_support "$decision"
                    ;;
                6)
                    read -p "Enter error message: " error
                    read -p "Enter context: " context
                    debug_assistant "$error" "$context"
                    ;;
                7)
                    read -p "Enter code file path: " file
                    generate_docs "$file"
                    ;;
                8)
                    read -p "Enter data file path: " file
                    data_pipeline "$file"
                    ;;
                9)
                    read -p "Enter content to check: " content
                    qa_check "$content"
                    ;;
                10)
                    read -p "Enter problem to solve: " problem
                    solve_complex_problem "$problem"
                    ;;
                11)
                    read -p "Enter customer query: " query
                    customer_support_router "$query"
                    ;;
                12)
                    read -p "Enter query for format demo: " query
                    output_format_demo "$query"
                    ;;
                13)
                    debug_verbose_example
                    ;;
                0)
                    echo "Exiting..."
                    exit 0
                    ;;
                *)
                    echo "Invalid option"
                    ;;
            esac
            
            echo
            read -p "Press Enter to continue..."
        done
    else
        # Command line arguments
        case "$1" in
            review)
                code_review "$2"
                ;;
            research)
                research_topic "$2"
                ;;
            generate)
                generate_optimized_content "$2" "$3"
                ;;
            analyze)
                analyze_dataset "$2"
                ;;
            decide)
                decision_support "$2"
                ;;
            debug)
                debug_assistant "$2" "$3"
                ;;
            docs)
                generate_docs "$2"
                ;;
            pipeline)
                data_pipeline "$2"
                ;;
            qa)
                qa_check "$2"
                ;;
            solve)
                solve_complex_problem "$2"
                ;;
            support)
                customer_support_router "$2"
                ;;
            format-demo)
                output_format_demo "$2"
                ;;
            verbose)
                debug_verbose_example
                ;;
            *)
                echo "Usage: $0 [command] [args...]"
                echo "Commands:"
                echo "  review <file>           - Review code"
                echo "  research <topic>        - Research topic"
                echo "  generate <topic> <audience> - Generate content"
                echo "  analyze <data>          - Analyze data"
                echo "  decide <decision>       - Decision support"
                echo "  debug <error> <context> - Debug assistant"
                echo "  docs <file>            - Generate documentation"
                echo "  pipeline <file>        - Run data pipeline"
                echo "  qa <content>           - QA check"
                echo "  solve <problem>        - Solve complex problem"
                echo "  support <query>        - Route customer support query"
                echo "  format-demo <query>    - Demonstrate output formats"
                echo "  verbose                - Run verbose debugging example"
                ;;
        esac
    fi
fi
