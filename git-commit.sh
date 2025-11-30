#!/bin/bash

CONFIG_DIR="$HOME/.config/git-commit-ai"
CONFIG_FILE="$CONFIG_DIR/config"
MODEL_FILE="$CONFIG_DIR/model"
BASE_URL_FILE="$CONFIG_DIR/base_url"
PROVIDER_FILE="$CONFIG_DIR/provider"

# Debug mode flag
DEBUG=false
# Push flag
PUSH=false
# Message only flag
MESSAGE_ONLY=false
# Add-all flag (stage all changes before commit when enabled)
ADD_ALL=false
# Preview flag (show and optionally revise commit message before committing)
PREVIEW=false

# Colors for nicer terminal output (fallback to plain text if disabled)
COLOR_PREVIEW="\033[1;33m"  # bright yellow (orange-ish)
COLOR_COMMIT="\033[0;32m"        # green for final commit message
COLOR_RESET="\033[0m"
# Default providers and URLs
PROVIDER_OPENROUTER="openrouter"
PROVIDER_OLLAMA="ollama"
PROVIDER_LMSTUDIO="lmstudio"
PROVIDER_CUSTOM="custom"

OPENROUTER_URL="https://openrouter.ai/api/v1"
OLLAMA_URL="http://localhost:11434/api"
LMSTUDIO_URL="http://localhost:1234/v1"

# Default models for providers
OLLAMA_MODEL="codellama"
OPENROUTER_MODEL="google/gemini-flash-1.5-8b"
LMSTUDIO_MODEL="default"

# Debug function
debug_log() {
    if [ "$DEBUG" = true ]; then
        echo "DEBUG: $1"
        if [ ! -z "$2" ]; then
            echo "DEBUG: Content >>>"
            echo "$2"
            echo "DEBUG: <<<"
        fi
    fi
}

# Function to save API key
save_api_key() {
    mkdir -p "$CONFIG_DIR"
    # Remove any quotes or extra arguments from the API key
    API_KEY=$(echo "$1" | cut -d' ' -f1)
    echo "$API_KEY" >"$CONFIG_FILE"
    chmod 600 "$CONFIG_FILE"
    debug_log "API key saved to config file"
}

# Function to get API key
get_api_key() {
    if [ -f "$CONFIG_FILE" ]; then
        cat "$CONFIG_FILE"
    else
        echo ""
    fi
}

# Function to save model
save_model() {
    echo "$1" >"$MODEL_FILE"
    chmod 600 "$MODEL_FILE"
    debug_log "Model saved to config file"
}

# Function to get model
get_model() {
    if [ -f "$MODEL_FILE" ]; then
        cat "$MODEL_FILE"
    else
        echo "" # Return empty string to let provider-specific default be used
    fi
}

# Function to save base URL
save_base_url() {
    echo "$1" >"$BASE_URL_FILE"
    chmod 600 "$BASE_URL_FILE"
    debug_log "Base URL saved to config file"
}

# Function to save provider
save_provider() {
    echo "$1" >"$PROVIDER_FILE"
    chmod 600 "$PROVIDER_FILE"
    debug_log "Provider saved to config file"
}

# Function to get provider
get_provider() {
    if [ -f "$PROVIDER_FILE" ]; then
        cat "$PROVIDER_FILE"
    else
        echo "$PROVIDER_OPENROUTER"
    fi
}

# Function to get base URL
get_base_url() {
    if [ -f "$BASE_URL_FILE" ]; then
        cat "$BASE_URL_FILE"
    else
        echo "$OPENROUTER_URL" # Default base URL
    fi
}

# Function to print config
print_config() {
    echo "Current configuration:"
    echo "  Provider:  $(get_provider)"
    echo "  Base URL:  $(get_base_url)"
    echo "  Model:     $(get_model)"
    API_KEY=$(get_api_key)
    if [ -z "$API_KEY" ]; then
        echo "  API Key:   Not set"
    else
        echo "  API Key:   ****"
    fi
}



# Load saved provider and base URL or use defaults
PROVIDER=$(get_provider)
BASE_URL=$(get_base_url)

# If no saved provider, use defaults
if [ -z "$PROVIDER" ]; then
    PROVIDER="$PROVIDER_OPENROUTER"
    BASE_URL="$OPENROUTER_URL"
fi

# Default models for providers
OLLAMA_MODEL="codellama"
OPENROUTER_MODEL="google/gemini-flash-1.5-8b"
LMSTUDIO_MODEL="default"

# Get saved model or use default based on provider
MODEL=$(get_model)
if [ -z "$MODEL" ]; then
    case "$PROVIDER" in
    "$PROVIDER_OLLAMA")
        MODEL="$OLLAMA_MODEL"
        ;;
    "$PROVIDER_OPENROUTER")
        MODEL="$OPENROUTER_MODEL"
        ;;
    esac
fi

# Get saved base URL or use default
BASE_URL=$(get_base_url)

debug_log "Script started"
debug_log "Config directory: $CONFIG_DIR"

# Create config directory if it doesn't exist
mkdir -p "$CONFIG_DIR"
chmod 700 "$CONFIG_DIR"
debug_log "Config directory created/checked"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
    --debug)
        DEBUG=true
        shift
        ;;
    --use-ollama)
        PROVIDER="$PROVIDER_OLLAMA"
        BASE_URL="$OLLAMA_URL"
        MODEL="$OLLAMA_MODEL"
        save_provider "$PROVIDER"
        save_base_url "$BASE_URL"
        save_model "$MODEL"
        shift
        ;;
    --use-openrouter)
        PROVIDER="$PROVIDER_OPENROUTER"
        BASE_URL="$OPENROUTER_URL"
        MODEL="$OPENROUTER_MODEL"
        save_provider "$PROVIDER"
        save_base_url "$BASE_URL"
        save_model "$MODEL"
        shift
        ;;
    --use-lmstudio)
        PROVIDER="$PROVIDER_LMSTUDIO"
        BASE_URL="$LMSTUDIO_URL"
        MODEL="$LMSTUDIO_MODEL"
        save_provider "$PROVIDER"
        save_base_url "$BASE_URL"
        save_model "$MODEL"
        shift
        ;;
    --use-custom)
        if [ -z "$2" ]; then
            echo "Error: --use-custom requires a base URL"
            exit 1
        fi
        PROVIDER="$PROVIDER_CUSTOM"
        BASE_URL="$2"
        save_provider "$PROVIDER"
        save_base_url "$BASE_URL"
        shift 2
        ;;
    --push)
        PUSH=true
        shift
        ;;
    -a)
        ADD_ALL=true
        shift
        ;;
    -p)
        PREVIEW=true
        shift
        ;;
    -ap|-pa)
        ADD_ALL=true
        PREVIEW=true
        shift
        ;;
    --message-only)
        MESSAGE_ONLY=true
        shift
        ;;
    --print-config)
        print_config
        exit 0
        ;;
    -h | --help)
        echo "Usage: gca [options] [api_key]"
        echo ""
        echo "Options:"
        echo "  --debug               Enable debug mode"
        echo "  --push                Push changes after commit"
        echo "  -a                    Stage all changes (equivalent to 'git add .')"
        echo "  -p                    Preview commit message and confirm before committing"
        echo "  --message-only        Generate message only, no git add/commit/push"
        echo "  --model <model>       Use specific model (default: google/gemini-flash-1.5-8b)"
        echo "  --use-ollama          Use Ollama as provider (saves for future use)"
        echo "  --use-openrouter      Use OpenRouter as provider (saves for future use)"
        echo "  --use-lmstudio        Use LMStudio as provider (saves for future use)"
        echo "  --use-custom <url>    Use custom provider with base URL (saves for future use)"
        echo "  --print-config        Print the current config"
        echo "  -h, --help            Show this help message"
        echo ""
        echo "Examples:"
        echo "  gca --api-key your_api_key          # First time setup with API key"
        echo "  gca --use-ollama                    # Switch to Ollama provider"
        echo "  gca --use-openrouter                # Switch back to OpenRouter"
        echo "  gca --use-lmstudio                  # Switch to LMStudio provider"
        echo "  gca --use-custom http://my-api.com  # Use custom provider"
        echo "  gca --message-only                  # Generate message only, no commit"
        exit 0
        ;;
    --model)
        # Check if next argument exists and doesn't start with -
        if [[ -n "$2" && "$2" != -* ]]; then
            # Remove any quotes from model name and save it
            MODEL=$(echo "$2" | tr -d '"')
            save_model "$MODEL"
            debug_log "New model saved: $MODEL"
            shift 2
        else
            echo "Error: --model requires a valid model name"
            exit 1
        fi
        ;;
    --base-url)
        # Check if next argument exists and doesn't start with -
        if [[ -n "$2" && "$2" != -* ]]; then
            BASE_URL="$2"
            save_base_url "$BASE_URL"
            debug_log "New base URL saved: $BASE_URL"
            shift 2
        else
            echo "Error: --base-url requires a valid URL"
            exit 1
        fi
        ;;
    --api-key)
        # Check if next argument exists and doesn't start with -
        if [[ -n "$2" && "$2" != -* ]]; then
            save_api_key "$2"
            debug_log "New API key saved"
            shift 2
        else
            echo "Error: --api-key requires a valid API key"
            exit 1
        fi
        ;;
    *)
        echo "Error: Unknown argument $1"
        exit 1
        ;;
    esac
done

# Get API key from config
API_KEY=$(get_api_key)
debug_log "API key retrieved from config"

if [ -z "$API_KEY" ] && [ "$PROVIDER" = "$PROVIDER_OPENROUTER" ]; then
    echo "No API key found. Please provide the OpenRouter API key using --api-key flag"
    echo "Usage: gca [--debug] [--push] [-a] [-p] [--use-ollama] [--model <model_name>] [--base-url <url>] [--api-key <key>]"
    exit 1
fi

# Set default model based on provider
if [ "$PROVIDER" = "$PROVIDER_OLLAMA" ]; then
    [ -z "$MODEL" ] && MODEL="$OLLAMA_MODEL"
    # Check if Ollama is running
    if ! pgrep ollama >/dev/null; then
        echo "Error: Ollama server not running. Please start Ollama first:"
        echo "ollama serve"
        exit 1
    fi
    # Check if model exists using ollama ls
    if ! ollama ls | awk '{print $1}' | grep -q "^${MODEL}$"; then
        echo "Error: Model '$MODEL' not found in Ollama. Please pull it first:"
        echo "ollama pull $MODEL"
        exit 1
    fi
fi

# Optionally stage all changes if requested and not using message-only mode
if [ "$MESSAGE_ONLY" = false ] && [ "$ADD_ALL" = true ]; then
    debug_log "Staging all changes (git add .)"
    git add .
fi

# Use a single, readable format for all providers (jq will handle JSON escaping)
# IMPORTANT: never send .env-style files to the model, but allow .env.example templates
# We exclude:
# - .env
# - .env.* (e.g. .env.local, .env.production) — EXCEPT *.env.example
# - *.env and *.env.* (e.g. app.env, app.env.local) — EXCEPT *.env.example
CHANGES=$(
    {
        git diff --cached --name-status -- \
            . \
            ':(exclude).env' \
            ':(exclude).env.*' \
            ':(exclude)*.env' \
            ':(exclude)*.env.*'
        # Explicitly re-include any staged *.env.example files in the summary
        git diff --cached --name-status -- '*.env.example' 2>/dev/null || true
    } | tr '\t' ' ' | sed 's/  */ /g'
)

# Get git diff for context, with the same exclusions but re-adding *.env.example diffs
DIFF_CONTENT=$(
    {
        git diff --cached -- \
            . \
            ':(exclude).env' \
            ':(exclude).env.*' \
            ':(exclude)*.env' \
            ':(exclude)*.env.*'
        # Explicitly re-include any staged *.env.example diffs
        git diff --cached -- '*.env.example' 2>/dev/null || true
    }
)
debug_log "Git changes detected" "$CHANGES"

if [ -z "$CHANGES" ]; then
    echo "No staged changes found. Please stage your changes using 'git add' first, or run 'gca -a' to stage all changes."
    exit 1
fi

# Global conversation history for chat providers (JSON array of message objects)
CONVERSATION_HISTORY="[]"

generate_commit_message() {
    local previous_message="$1"
    local extra_instructions="$2"

    # Assemble the user prompt with raw content; jq will escape JSON safely
    USER_CONTENT=$(cat <<EOF
Generate a commit message for these changes:

## File changes:
<file_changes>
$CHANGES
</file_changes>

## Diff:
<diff>
$DIFF_CONTENT
</diff>

## Format:
<type>(<scope>): <subject>

<body>

Important:
- Terminology in this prompt and in any later user feedback:
  - "summary", "subject", "title", or "first line" = the <type>(<scope>): <subject> line
  - "body", "description", "details", "bullets", or "bullet points" = all lines after the first line
- Type must be one of: feat, fix, docs, style, refactor, perf, test, chore
- Subject: max 70 characters, imperative mood, no period
- Body: OPTIONAL. Only include if needed. 1-3 very short bullet points or lines summarizing the MOST important changes (never more than 6, even for huge diffs)
- For small or localized changes (one file, small prompt/docs tweak, minor refactor), use exactly ONE short bullet whenever possible
- When there are many files/changes, group related changes into a few high-level bullets instead of listing everything
- Focus on what and why, not how; avoid very long, detailed, or repetitive descriptions
- Produce exactly ONE commit: a single '<type>(<scope>): <subject>' line optionally followed by the body; do not create multiple feat(...), fix(...), etc. sections
- Do not add extra headings or section titles; body should be just bullets or short lines under the summary
- The body can be completely omitted if the summary is self-explanatory. If user says "remove body" or "remove description", output ONLY the summary line with NO body at all.
- Scope: max 3 words
- For minor changes: use 'fix' instead of 'feat'
- Do not wrap your response in triple backticks
- Response should be the commit message only, no explanations.
EOF
)

    if [ -n "$previous_message" ] && [ -n "$extra_instructions" ]; then
        USER_CONTENT="$USER_CONTENT

Current draft commit message:
<current_commit_message>
$previous_message
</current_commit_message>

Please REVISE the current commit message above (do NOT create a completely new commit),
strictly following these user instructions:
$extra_instructions"
    elif [ -n "$extra_instructions" ]; then
        USER_CONTENT="$USER_CONTENT

Additional instructions from the user (apply these when generating the commit message):
$extra_instructions"
    fi

    # Make the API request
    case "$PROVIDER" in
    "$PROVIDER_OLLAMA")
        debug_log "Making API request to Ollama"
        ENDPOINT="api/generate"
        HEADERS=(-H "Content-Type: application/json")
        BASE_URL="http://localhost:11434"
        REQUEST_BODY=$(jq -n \
            --arg model "$MODEL" \
            --arg prompt "$USER_CONTENT" \
            '{model:$model, prompt:$prompt, stream:false}')
        ;;
    "$PROVIDER_LMSTUDIO" | "$PROVIDER_OPENROUTER" | "$PROVIDER_CUSTOM")
        debug_log "Making API request to chat provider: $PROVIDER"
        ENDPOINT="chat/completions"
        
        # Set provider-specific headers
        if [ "$PROVIDER" = "$PROVIDER_OPENROUTER" ]; then
            HEADERS=(
                "HTTP-Referer: https://github.com/mrgoonie/cmai"
                "Authorization: Bearer $API_KEY"
                "Content-Type: application/json"
                "X-Title: cmai - AI Commit Message Generator"
            )
        elif [ "$PROVIDER" = "$PROVIDER_CUSTOM" ]; then
            HEADERS=(-H "Content-Type: application/json")
            [ -n "$API_KEY" ] && HEADERS+=(-H "Authorization: Bearer ${API_KEY}")
        else
            HEADERS=(-H "Content-Type: application/json")
        fi
        
        SYSTEM_PROMPT="You are an expert git commit message generator following the Conventional Commits format. Your task is to create or revise commit messages based on code diffs and user feedback. When the user asks you to revise a message, carefully apply their specific instructions (like 'remove body', 'make it shorter', 'add more detail', etc.) to the current draft. You understand terms like 'summary'/'subject'/'title'/'first line' refer to the first line, and 'body'/'description'/'details'/'bullets' refer to lines after the first. Always output ONLY the commit message itself with no extra commentary."
        
        # Initialize conversation on first call
        if [ "$CONVERSATION_HISTORY" = "[]" ]; then
            CONVERSATION_HISTORY=$(jq -n \
                --arg system "$SYSTEM_PROMPT" \
                --arg user "$USER_CONTENT" \
                '[{role:"system", content:$system}, {role:"user", content:$user}]')
        else
            # Append new user message to history
            CONVERSATION_HISTORY=$(echo "$CONVERSATION_HISTORY" | jq \
                --arg user "$USER_CONTENT" \
                '. += [{role:"user", content:$user}]')
        fi
        
        REQUEST_BODY=$(jq -n \
            --arg model "$MODEL" \
            --argjson messages "$CONVERSATION_HISTORY" \
            '{
               model: $model,
               stream: false,
               messages: $messages
             }')
        
        debug_log "Chat provider request body:" "$REQUEST_BODY"
        ;;
    esac

    # Debug
    debug_log "Using provider: $PROVIDER"
    debug_log "Provider endpoint: $ENDPOINT"
    debug_log "Request headers: ${HEADERS[*]}"
    debug_log "Request model: ${MODEL}"
    debug_log "Request body: $REQUEST_BODY"

    # Convert headers array to proper curl format
    CURL_HEADERS=()
    for header in "${HEADERS[@]}"; do
        CURL_HEADERS+=(-H "$header")
    done

    RESPONSE=$(curl -s -X POST "$BASE_URL/$ENDPOINT" \
        "${CURL_HEADERS[@]}" \
        -d "$REQUEST_BODY")
    debug_log "API response received" "$RESPONSE"

    # Extract and clean the commit message
    case "$PROVIDER" in
    "$PROVIDER_OLLAMA")
        # For Ollama, extract content from non-streaming response
        if echo "$RESPONSE" | grep -q "404 page not found"; then
            echo "Error: Ollama API endpoint not found. Make sure Ollama is running and try again."
            echo "Run: ollama serve"
            exit 1
        fi
        if echo "$RESPONSE" | grep -q "error"; then
            ERROR=$(echo "$RESPONSE" | jq -r '.error')
            echo "Error from Ollama: $ERROR"
            exit 1
        fi
        COMMIT_FULL=$(echo "$RESPONSE" | jq -r '.response // empty')
        if [ -z "$COMMIT_FULL" ]; then
            echo "Error: Failed to get response from Ollama. Response: $RESPONSE"
            exit 1
        fi
        ;;
    "$PROVIDER_LMSTUDIO")
        # For LMStudio, extract content from response
        debug_log "LMStudio raw response:" "$RESPONSE"

        # Check if response is HTML error page
        if echo "$RESPONSE" | grep -q "<!DOCTYPE html>"; then
            echo "Error: LMStudio API returned HTML error. Make sure LMStudio is running and the API is accessible."
            echo "Response: $RESPONSE"
            exit 1
        fi

        # Check for JSON error - only if there's an actual error field with content
        if echo "$RESPONSE" | jq -e '.error' >/dev/null 2>&1; then
            ERROR=$(echo "$RESPONSE" | jq -r '.error.message // .error' 2>/dev/null)
            echo "Error from LMStudio: $ERROR"
            exit 1
        fi

        # Try to extract content with proper error handling
        COMMIT_FULL=$(echo "$RESPONSE" | jq -r '.choices[0].message.content' 2>/dev/null)
        if [ $? -ne 0 ] || [ -z "$COMMIT_FULL" ] || [ "$COMMIT_FULL" = "null" ]; then
            echo "Error: Failed to parse LMStudio response. Response format may be unexpected."
            echo "Response: $RESPONSE"
            exit 1
        fi
        ;;
    "$PROVIDER_OPENROUTER" | "$PROVIDER_CUSTOM")
        # For OpenRouter and custom providers
        COMMIT_FULL=$(echo "$RESPONSE" | jq -r '.choices[0].message.content')

        # If jq fails or returns null, fallback to grep method
        if [ -z "$COMMIT_FULL" ] || [ "$COMMIT_FULL" = "null" ]; then
            COMMIT_FULL=$(echo "$RESPONSE" | grep -o '"content":"[^"]*"' | cut -d'"' -f4)
        fi
        
        # Append assistant response to conversation history for chat providers
        if [ "$PROVIDER" != "$PROVIDER_OLLAMA" ]; then
            CONVERSATION_HISTORY=$(echo "$CONVERSATION_HISTORY" | jq \
                --arg assistant "$COMMIT_FULL" \
                '. += [{role:"assistant", content:$assistant}]')
        fi
        ;;
    esac

    # Clean the message:
    # 1. Preserve the structure of the commit message
    # 2. Clean up escape sequences
    COMMIT_FULL=$(echo "$COMMIT_FULL" |
        sed 's/\\n/\n/g' |
        sed 's/\\r//g' |
        sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' |
        sed 's/\\[[:alpha:]]//g')

    debug_log "Extracted commit message" "$COMMIT_FULL"

    if [ -z "$COMMIT_FULL" ]; then
        echo "Failed to generate commit message. API response:"
        echo "$RESPONSE"
        exit 1
    fi
}

generate_commit_message "" ""

if [ "$PREVIEW" = true ] && [ "$MESSAGE_ONLY" = false ]; then
    while true; do
        echo
        printf "%b\n" "${COLOR_PREVIEW}==== Commit message preview ====${COLOR_RESET}"
        echo
        printf "%s\n" "$COMMIT_FULL"
        echo
        printf "%b\n" "${COLOR_PREVIEW}================================${COLOR_RESET}"
        echo
        printf "%b" "${COLOR_PREVIEW}Press Enter to accept and commit, type instructions to revise, or Ctrl+C to cancel:${COLOR_RESET} "
        read -r USER_FEEDBACK
        if [ -z "$USER_FEEDBACK" ]; then
            break
        fi
        generate_commit_message "$COMMIT_FULL" "$USER_FEEDBACK"
    done
fi

if [ "$MESSAGE_ONLY" = true ]; then
    echo "$COMMIT_FULL"
    exit 0
fi

# Execute git commit
debug_log "Executing git commit"
git commit -m "$COMMIT_FULL"

if [ $? -ne 0 ]; then
    echo "Failed to commit changes"
    exit 1
fi

# Push to origin if flag is set
if [ "$PUSH" = true ]; then
    debug_log "Pushing to origin"
    git push origin

    if [ $? -ne 0 ]; then
        echo "Failed to push changes"
        exit 1
    fi
    echo "Successfully pushed changes to origin"
fi

echo
printf "%b\n" "${COLOR_COMMIT}==== Commit message ====${COLOR_RESET}"
echo
printf "%s\n" "$COMMIT_FULL"
echo
printf "%b\n" "${COLOR_COMMIT}================================${COLOR_RESET}"
debug_log "Script completed successfully"
