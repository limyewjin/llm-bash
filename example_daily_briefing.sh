#!/bin/bash
set -euo pipefail

# Daily Briefing Email Workflow
# Fetches weather + news, synthesizes with LLM, A/B tests formats, and emails result

# ============================================================================
# CONFIGURATION
# ============================================================================

# Get the directory where this script lives
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"

# Source the LLM Agent Framework
. "${SCRIPT_DIR}/llm-bash.sh"

# Configuration
USER_EMAIL="${BRIEFING_EMAIL:-user@example.com}"
USER_LOCATION="${BRIEFING_LOCATION:-San Francisco}"
NEWS_TOPICS="${BRIEFING_TOPICS:-technology,ai,science}"

# ============================================================================
# STEP 1: FETCH WEATHER DATA
# ============================================================================

echo "📡 Fetching weather report for $USER_LOCATION..." >&2

# Using wttr.in - free weather service, no API key needed
weather_data=$(curl -s "https://wttr.in/${USER_LOCATION// /+}?format=j1" 2>/dev/null || echo '{"error": "Weather unavailable"}')

# Extract key weather info
if echo "$weather_data" | jq empty 2>/dev/null; then
    weather_summary=$(echo "$weather_data" | jq -r '
        .current_condition[0] |
        "Temperature: \(.temp_F)°F/\(.temp_C)°C, " +
        "Conditions: \(.weatherDesc[0].value), " +
        "Humidity: \(.humidity)%, " +
        "Wind: \(.windspeedMiles)mph"
    ' 2>/dev/null || echo "Weather data unavailable")
else
    weather_summary="Weather data unavailable"
fi

echo "✓ Weather: $weather_summary" >&2

# ============================================================================
# STEP 2: FETCH NEWS DATA
# ============================================================================

echo "📡 Fetching news headlines..." >&2

# Fetch tech news from Hacker News (simple RSS feed)
news_raw=$(curl -s "https://hnrss.org/frontpage?count=20" 2>/dev/null || echo "")

# Parse RSS feed to extract headlines (simple extraction)
if [[ -n "$news_raw" ]]; then
    news_headlines=$(echo "$news_raw" | grep -oP '(?<=<title>).*?(?=</title>)' | head -15 | tail -10 | nl)
else
    news_headlines="News unavailable"
fi

echo "✓ Fetched news headlines" >&2

# ============================================================================
# STEP 3: SYNTHESIZE INFORMATION WITH PROMPT CHAIN
# ============================================================================

echo "🤖 Synthesizing briefing with LLM..." >&2

# Combine weather and news into one data package
briefing_data="DATE: $(date '+%A, %B %d, %Y')
LOCATION: $USER_LOCATION

WEATHER:
$weather_summary

NEWS HEADLINES:
$news_headlines
"

# Use prompt_chain to synthesize the information
synthesized_info=$(echo "$briefing_data" | prompt_chain \
    "Analyze this data and identify the 3 most important and meaningful news headlines from the list. Consider relevance, impact, and user interest: {{input}}" \
    "Based on these top headlines and the weather info, create a cohesive summary that connects the information naturally: {{previous}}")

echo "✓ Information synthesized" >&2

# ============================================================================
# STEP 4: A/B TEST EMAIL FORMATS
# ============================================================================

echo "🧪 A/B testing email formats..." >&2

# Prepare the synthesized content for A/B testing
briefing_context="Date: $(date '+%A, %B %d, %Y')
Location: $USER_LOCATION
Weather: $weather_summary

Synthesized Content:
$synthesized_info"

# A/B test two different email styles
email_result=$(echo "$briefing_context" | ab_test \
    "{{input}}" \
    "Create a professional, formal HTML email briefing with exactly 3 headline bullets, weather summary, and concise tone. Include proper HTML structure with <html>, <head>, <body> tags, use a clean sans-serif font, subtle colors (#f4f4f4 background, #333 text). Format as complete HTML document ready to send. Context: {{input}}" \
    "Create a friendly, conversational HTML email briefing with exactly 3 engaging headline bullets (use emojis sparingly), weather summary, and warm tone. Include proper HTML structure with <html>, <head>, <body> tags, use modern styling with gradients or colors, readable fonts. Format as complete HTML document ready to send. Context: {{input}}" \
    "Which email style is more effective for a daily briefing: clear, engaging, and likely to be read? Consider readability, information density, and user engagement.")

echo "✓ Best email format selected" >&2

# ============================================================================
# STEP 5: PREPARE HTML FOR SENDING
# ============================================================================

# ab_test now returns clean output by default (just the selected variant)
selected_html="$email_result"

# If HTML doesn't start with <!DOCTYPE or <html, wrap it properly
if [[ ! "$selected_html" =~ ^[[:space:]]*(\<\!DOCTYPE|\<html) ]]; then
    selected_html="<!DOCTYPE html>
<html>
<head>
    <meta charset='UTF-8'>
    <meta name='viewport' content='width=device-width, initial-scale=1.0'>
    <title>Daily Briefing</title>
</head>
<body style='font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;'>
$selected_html
</body>
</html>"
fi

# ============================================================================
# STEP 6: SEND EMAIL
# ============================================================================

echo "📧 Sending email to $USER_EMAIL..." >&2

# Save HTML to temp file
temp_html=$(mktemp /tmp/briefing.XXXXXX.html)
echo "$selected_html" > "$temp_html"

# Use clean subject line
subject="Daily Briefing - $USER_LOCATION - $(date '+%A, %B %d, %Y')"

# Send email (using multiple methods for compatibility)
if command -v mail >/dev/null 2>&1; then
    # Using mail command (most common)
    (
        echo "To: $USER_EMAIL"
        echo "Subject: $subject"
        echo "Content-Type: text/html; charset=UTF-8"
        echo "MIME-Version: 1.0"
        echo ""
        cat "$temp_html"
    ) | sendmail -t 2>/dev/null || {
        echo "⚠️  sendmail failed, trying mail command..." >&2
        cat "$temp_html" | mail -s "$(echo -e "Content-Type: text/html\n$subject")" "$USER_EMAIL" 2>/dev/null || {
            echo "⚠️  mail command failed, saving to file instead" >&2
            cp "$temp_html" "$HOME/daily-briefing-$(date +%Y%m%d).html"
            echo "📄 Briefing saved to: $HOME/daily-briefing-$(date +%Y%m%d).html" >&2
        }
    }
elif command -v mutt >/dev/null 2>&1; then
    # Using mutt
    mutt -e "set content_type=text/html" -s "$subject" "$USER_EMAIL" < "$temp_html" || {
        echo "⚠️  mutt failed, saving to file instead" >&2
        cp "$temp_html" "$HOME/daily-briefing-$(date +%Y%m%d).html"
        echo "📄 Briefing saved to: $HOME/daily-briefing-$(date +%Y%m%d).html" >&2
    }
else
    # No mail client available, save to file
    echo "⚠️  No mail client found (mail, sendmail, mutt)" >&2
    cp "$temp_html" "$HOME/daily-briefing-$(date +%Y%m%d).html"
    echo "📄 Briefing saved to: $HOME/daily-briefing-$(date +%Y%m%d).html" >&2
    echo "📄 You can open it in a browser to view" >&2
fi

# Also save a copy for debugging/archiving
mkdir -p "$HOME/.llm-briefings"
cp "$temp_html" "$HOME/.llm-briefings/briefing-$(date +%Y%m%d-%H%M%S).html"

echo "✅ Daily briefing complete!" >&2
echo "" >&2
echo "Preview:" >&2
echo "========================================" >&2
echo "$selected_html" | head -30 >&2
echo "========================================" >&2
echo "Full HTML saved to: $HOME/.llm-briefings/briefing-$(date +%Y%m%d-%H%M%S).html" >&2

# Cleanup
rm -f "$temp_html"
