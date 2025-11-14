#!/bin/bash
# Demo script showing stdin handling behavior

# Source the main script
source ./llm-bash.sh

# Mock llm_exec to avoid actual LLM calls
llm_exec() {
    echo "[MOCK LLM OUTPUT] Received prompt: $1"
}
export -f llm_exec

echo "Demo 1: Using prompt_chain with {{input}} placeholder"
echo "======================================================="
echo "Command: echo 'test data' | prompt_chain 'Process: {{input}}'"
echo "test data" | prompt_chain "Process: {{input}}"
echo
echo

echo "Demo 2: Using prompt_chain WITHOUT {{input}} placeholder"
echo "=========================================================="
echo "Command: echo 'test data' | prompt_chain 'Process this text'"
echo "test data" | prompt_chain "Process this text"
echo
echo

echo "Demo 3: Using parallel_prompts without placeholder"
echo "==================================================="
echo "Command: echo 'important info' | parallel_prompts 'Analyze' 'Summarize'"
echo "important info" | parallel_prompts "Analyze" "Summarize"
echo
