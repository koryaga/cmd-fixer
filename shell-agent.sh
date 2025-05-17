#!/usr/bin/env bash
# fixes incorrect shell commands using LLM model and put them back to history

#TODO need call in async manner request to controller.py getting kind of job id
#TODO to avoid extra AI generated code
#TODO add error code to the prompt
#TODO make more sophisticated prompt using environment 
# shellcheck disable=SC2155

OPENAI_API_KEY=TOKEN
LLM_MODEL="${LLM_MODEL:-gemma3:12b}" #gpt-4.1-mini
LLM_URL="${LLM_URL:-"localhost:11434"}" #ollama by default , https://api.openai.com
HIST_LEN="${HIST_LEN:-1}" #by default use only current failed command to correct


check_command_result() {
    # Get the exit status of the last command. Always first command !!!!
    local exit_status=$?

    # trick to avoid empty prompt
    local current_histcmd
    current_histcmd=$(fc -l -1 | awk '{print $1}')
    [ "$DEBUG" ] && echo "DEBUG: $current_histcmd $HISTCMD_previous"

    # Check if the exit status indicates a syntax error
    if [ "$current_histcmd" -ne "$HISTCMD_previous" ] && \
    { [ "$exit_status" -eq 127 ] || [ "$exit_status" -eq 2 ];}; then
        local err_comm=$(history "${HIST_LEN}" | cut -d' ' -f4-)
        [ "$DEBUG" ] && echo "Error in syntax ${exit_status}"
        history -s "$(send_command  "${err_comm}")   #AI corrected"
        
    fi
    HISTCMD_previous=$current_histcmd

}

#system prompt for the AI model
export system_prompt=$(cat <<EOF
You are a shell command fixer. Your only task is to correct shell commands that fail with: 
    Exit code 127: command not found
    Exit code 2: syntax or misuse error
Rules:
    Take a number of shell commands as input. Correct last command that cause exit code 127 or 2.
    Also use  the previous commands as context if NOT POSSIBLE to correct.
    Do not improve formatting, style, or performance.
    Do not optimize or alter the command unless it directly addresses one of the above errors.
Context:
    Assume the command is for bash macOS.
Output:
    Respond only with the corrected last command.
    Do not change the command in case no issues are found.
    No extra text, no explanation, no formatting.
EOF
)


send_command() {
    local command=$1

    # Generate JSON payload using jq for Ollama API
    # shellcheck disable=SC2155
    local json_payload=$(jq -n \
        --arg system "$system_prompt" \
        --arg prompt "$command" \
        --arg model "$LLM_MODEL" \
        '{
            model: $model,
            messages: [
                {"role": "system", "content": $system},
                {"role": "user", "content": $prompt}
            ]
        }')

    # Send the POST request to Ollama API
    response=$(curl -s -X POST "${LLM_URL}"/v1/chat/completions \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $OPENAI_API_KEY" \
        -d "$json_payload" | jq -r '.choices[0].message.content')

    echo "$response"
}


# Set the PROMPT_COMMAND to call the function
PROMPT_COMMAND=check_command_result
