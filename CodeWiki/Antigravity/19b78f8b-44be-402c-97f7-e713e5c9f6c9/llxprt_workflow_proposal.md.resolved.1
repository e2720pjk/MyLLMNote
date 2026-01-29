# llxprt Agent Workflow Proposal

## 1. Mode Assessment: Interactive vs. Non-Interactive

### Findings
- **Interactive Mode** (`llxprt` or `llxprt -i "prompt"`):
  - Designed for human-in-the-loop sessions.
  - Supports built-in slash commands (e.g., `/help`, `/clear`, `/model`) which are executed locally by the UI.
  - **Verdict for Agents**: Generally **NOT recommended** for automated workflows due to complexity in managing stdin/stdout and process lifecycle.

- **Non-Interactive Mode** (`llxprt "prompt"`):
  - Executes the given prompt and exits.
  - **CRITICAL DIFFERENCE**: Built-in slash commands (like `/help`) are **NOT** executed locally. They are sent to the LLM as a prompt.
  - Only *custom* slash commands (loaded from files) are supported locally.
  - **Verdict for Agents**: **Recommended** for standard tasks, but **CANNOT** be used to trigger built-in UI features via slash commands.

## 2. Accessing Features in Non-Interactive Mode

Since slash commands like `/help` or `/model` are sent to the LLM in non-interactive mode, you must use **CLI flags** or **Configuration Files** to achieve the same effects.

| Feature | Interactive Command | Non-Interactive Strategy |
| :--- | :--- | :--- |
| **Change Model** | `/model <name>` | Use `--model <name>` flag |
| **Clear Context** | `/clear` | N/A (Each non-interactive run is a fresh session unless context is manually managed) |
| **Show Help** | `/help` | Use `llxprt --help` (CLI help) |
| **Add File** | `@file` | Use `@file` in prompt (supported in both) |

> [!WARNING]
> Do not use `llxprt "/help"` in a script expecting the CLI help text. You will get an LLM response explaining how it can help you.

## 3. Recommended Agent Workflow Template

### Workflow Structure

1.  **Configuration**:
    - Use `settings.json` or CLI flags (`--model`, `--sandbox`) to configure the environment.
    - Do not rely on slash commands for configuration.

2.  **Construct the Prompt**:
    - Formulate the natural language task.
    - Include context via `@filename` syntax (which *is* supported in non-interactive mode).

3.  **Execute Command**:
    - Run `llxprt "YOUR_PROMPT_HERE"`.
    - Capture `stdout` and `stderr`.

### Template (Bash Example)

```bash
#!/bin/bash

TASK="$1"
MODEL="gemini-2.0-flash-exp" # Example model

# 1. Run llxprt in non-interactive mode with flags
echo "Running llxprt with task: $TASK"
OUTPUT=$(llxprt --model "$MODEL" "$TASK")
EXIT_CODE=$?

# 2. Check status
if [ $EXIT_CODE -eq 0 ]; then
  echo "Success!"
  echo "Result: $OUTPUT"
else
  echo "Error executing llxprt."
  echo "$OUTPUT"
  exit 1
fi
```

### Template (Python Agent Tool Example)

```python
import subprocess

def run_llxprt_task(prompt: str, model: str = None) -> str:
    """
    Executes a task using the llxprt CLI agent.
    
    Args:
        prompt: The natural language instruction.
        model: Optional model override.
    """
    cmd = ["llxprt"]
    if model:
        cmd.extend(["--model", model])
    
    cmd.append(prompt)

    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            check=True
        )
        return result.stdout
    except subprocess.CalledProcessError as e:
        return f"Error: {e.stderr}"

# Usage
# Correct: Use flags for configuration
print(run_llxprt_task("Refactor src/utils.ts", model="gemini-1.5-pro"))

# Incorrect: Do NOT use slash commands
# print(run_llxprt_task("/model gemini-1.5-pro")) -> Will fail to change model locally
```

## Summary
- **Use Non-Interactive Mode** for automation.
- **Avoid Slash Commands** in non-interactive mode; they are treated as chat prompts.
- **Use Flags/Config** to control agent behavior (model, sandbox, etc.).
