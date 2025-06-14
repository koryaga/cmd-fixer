#!/usr/bin/env bash
# fixes incorrect shell commands using LLM model and put them back to history

#TODO make more sophisticated prompt, to avoid extra AI generated code
#TODO need call in async manner request to controller.py getting kind of job id ???
# shellcheck disable=SC2155

OPENAI_API_KEY=${OPENAI_API_KEY:-"TOKEN"} 
LLM_MODEL="${LLM_MODEL:-"gemma3"}" #gpt-4.1-mini
OPENAI_API_BASE="${OPENAI_API_BASE:-"http://localhost:11434/v1/chat/completions"}" #ollama by default , https://api.openai.com/v1/chat/completions
HIST_LEN="${HIST_LEN:-5}" #by default use 5 last commands as a context

HISTCMD_previous=0

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
        local err_comm=$(history "${HIST_LEN}" | sed 's/ *[0-9]* *//')
        [ "$DEBUG" ] && echo "Error in syntax ${exit_status} ${err_comm}"
        #send command to LLM , get the response and append it to the history
        history -s "$(send_command  "${err_comm}" ${exit_status}) #"  # comment as a sign that command was corrected 
        
    fi
    HISTCMD_previous=$current_histcmd

}

#system prompt for the AI model
export system_prompt=$(cat <<EOF
You are a shell command fixer. Your only task is to correct shell commands that fail with: 
    Exit code "${exit_status}".
Rules:
    Take a number of shell commands as input delimeted with '\n' or single. 
    Correct the last command that cause exit code "${exit_status}".
    Also use the previous commands as context if NOT POSSIBLE to correct.
    Do not improve formatting, style, or performance.
    Do not optimize or alter the command unless it directly addresses one of the above errors.
    Command may be enter in a WRONG KEYBOARD LAYOUT, also correct if that is the case.
Context:
    Assume the command is for bash "$(bash --version|head -n1)".
Output:
    Respond only with the corrected last command.
    Validate the command and ensure it is correct
    Do not change the command in case no issues are found.
    No extra text, no explanation, no formatting.
EOF
)


send_command() {
    local command=$1
    local exit_status=$2
    
    # Generate JSON payload using jq for LLM API
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
    [ "$DEBUG" ] && echo "$json_payload" >&2
    # Send the POST request to LLM API
    response=$(curl -s ${DEBUG:+"-v"} -X POST "${OPENAI_API_BASE}" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $OPENAI_API_KEY" \
        -d "$json_payload" | jq -r '.choices[0].message.content')
    echo "$response"
}


# Set the PROMPT_COMMAND to call the function
PROMPT_COMMAND=check_command_result
