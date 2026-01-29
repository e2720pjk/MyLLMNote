import json
import os
import glob
import shutil

# Paths
OPENCODE_DIR = "/Users/caishanghong/.local/share/opencode/storage"
BRAIN_DIR = "/Users/caishanghong/.gemini/antigravity/brain"
TARGET_DIR = "/Users/caishanghong/Shopify/cli-tool/MyLLMNote"

def analyze_opencode():
    projects = {}
    # Load projects
    for path in glob.glob(os.path.join(OPENCODE_DIR, "project", "*.json")):
        try:
            with open(path, 'r') as f:
                data = json.load(f)
                pid = data.get('id')
                worktree = data.get('worktree', '')
                if 'llxprt-code' in worktree:
                    projects[pid] = 'llxprt-code'
                elif 'CodeWiki' in worktree:
                    projects[pid] = 'CodeWiki'
        except:
            pass
    return projects

def analyze_antigravity():
    conversations = {} # id -> category
    # We'll use a heuristic for existing conversations based on scanning summaries or task.md
    
    # Check if BRAIN_DIR exists
    if not os.path.exists(BRAIN_DIR):
        print(f"Warning: Brain dir {BRAIN_DIR} does not exist.")
        return {}

    for conv_id in os.listdir(BRAIN_DIR):
        conv_path = os.path.join(BRAIN_DIR, conv_id)
        if not os.path.isdir(conv_path):
            continue
            
        task_md = os.path.join(conv_path, "task.md")
        if os.path.exists(task_md):
            try:
                with open(task_md, 'r') as f:
                    content = f.read().lower()
                    if 'codewiki' in content or 'opencode' in content: 
                         conversations[conv_id] = 'CodeWiki'
                    elif 'llxprt' in content or 'ast' in content or 'ast-edit' in content: 
                         conversations[conv_id] = 'llxprt-code'
            except:
                pass
    return conversations

def main():
    print("Analyzing Opencode projects...")
    opencode_map = analyze_opencode()
    print(f"Found {len(opencode_map)} relevant Opencode projects.")
    
    print("Analyzing Antigravity conversations...")
    antigravity_map = analyze_antigravity()
    print(f"Found {len(antigravity_map)} relevant Antigravity conversations.")
    
    print("JSON Result:")
    print(json.dumps({
        "opencode": opencode_map,
        "antigravity": antigravity_map
    }, indent=2))

if __name__ == "__main__":
    main()
