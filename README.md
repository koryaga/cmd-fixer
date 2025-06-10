# cmd-fixer

A shell agent that automatically detects incorrect shell commands (exit code `127`: _command not found_, or `2`: _syntax error_), uses an LLM to suggest corrections, and appends the corrected command to your shell history for easy recall. 

## Usage

1. **Set your LLM API:**

    For OpenAI:

    ```bash
    export LLM_MODEL=gpt-4.1-mini
    export OPENAI_API_KEY=your_openai_api_key
    export OPENAI_API_BASE="https://api.openai.com/v1/chat/completions"
    ```

    For Ollama (used by default):

    ```bash
    export LLM_MODEL=gemma3
    export OPENAI_API_BASE="http://localhost:11434/v1/chat/completions"
    # Ollama must be running locally with respective LLM model installed
    ```

1. **Source the agent in your shell:**

    ```bash
    source shell-agent.sh
    ```

1. **Use your shell as usual.**
   - When you enter a command that fails with exit code `127` or `2`, the agent will automatically attempt to correct it and add the suggestion to your history.

    ```bash
    $ sl
    bash: command not found: sl
    $ <Up Arrow>
    ls #
    ```
