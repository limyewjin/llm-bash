#!/bin/bash
# Test script for stdin handling changes

# Source the main script
source ./llm-bash.sh

echo "Testing stdin handling..."
echo "========================"
echo

# Test 1: Test the helper function with placeholder
echo "Test 1: Prompt with {{input}} placeholder"
result=$(prepend_stdin_if_no_placeholder "Analyze this: {{input}}" "Hello World")
echo "Input: 'Analyze this: {{input}}' with stdin='Hello World'"
echo "Result: '$result'"
echo "Expected: 'Analyze this: {{input}}' (unchanged)"
echo

# Test 2: Test the helper function without placeholder
echo "Test 2: Prompt without placeholder"
result=$(prepend_stdin_if_no_placeholder "Analyze this text" "Hello World")
echo "Input: 'Analyze this text' with stdin='Hello World'"
echo "Result: '$result'"
echo "Expected: Stdin prepended to prompt"
echo

# Test 3: Test with empty stdin
echo "Test 3: Prompt with empty stdin"
result=$(prepend_stdin_if_no_placeholder "Analyze this text" "")
echo "Input: 'Analyze this text' with stdin=''"
echo "Result: '$result'"
echo "Expected: 'Analyze this text' (unchanged)"
echo

# Test 4: Test with other placeholders
echo "Test 4: Prompt with {{previous}} placeholder"
result=$(prepend_stdin_if_no_placeholder "Continue from: {{previous}}" "Hello World")
echo "Input: 'Continue from: {{previous}}' with stdin='Hello World'"
echo "Result: '$result'"
echo "Expected: 'Continue from: {{previous}}' (unchanged)"
echo

echo "========================"
echo "All tests completed!"
