import json
import os
import glob
from datetime import datetime
import sys

OPENCODE_DIR = "/Users/caishanghong/.local/share/opencode/storage"
PROJECT_DIR = os.path.join(OPENCODE_DIR, "project")
SESSION_DIR = os.path.join(OPENCODE_DIR, "session")
TODO_DIR = os.path.join(OPENCODE_DIR, "todo")

def load_json(path):
    try:
        with open(path, 'r') as f:
            return json.load(f)
    except Exception:
        return None

def main():
    projects = {}
    if os.path.exists(PROJECT_DIR):
        for path in glob.glob(os.path.join(PROJECT_DIR, "*.json")):
            data = load_json(path)
            if data:
                name = os.path.basename(data.get("worktree", "Unknown").rstrip('/'))
                projects[data.get("id")] = name
    
    sessions = []
    if os.path.exists(SESSION_DIR):
        for project_id in os.listdir(SESSION_DIR):
            project_session_dir = os.path.join(SESSION_DIR, project_id)
            if not os.path.isdir(project_session_dir):
                continue
            
            for filename in os.listdir(project_session_dir):
                if not filename.endswith(".json"):
                    continue
                
                path = os.path.join(project_session_dir, filename)
                sess_data = load_json(path)
                if sess_data:
                    sess_data['projectID'] = project_id # Ensure linkage if missing in file
                    sessions.append(sess_data)

    data_list = []
    for sess in sessions:
        ts = sess.get("time", {}).get("updated", 0)
        if not ts:
            ts = sess.get("time", {}).get("created", 0)
        
        # Normalize timestamp to seconds
        if ts > 10000000000:
            ts = ts / 1000.0
        
        dt = datetime.fromtimestamp(ts)
        date_str = dt.strftime("%Y-%m-%d")

        project_id = sess.get("projectID")
        project_name = projects.get(project_id, "Unknown Project")
        
        sess_id = sess.get("id")
        sess_title = sess.get("title", "No Title")
        
        # Link Todos
        todo_path = os.path.join(TODO_DIR, f"{sess_id}.json")
        todos = []
        todo_data = load_json(todo_path)
        if todo_data and isinstance(todo_data, list):
            for t in todo_data:
                todos.append({
                    "status": t.get("status"),
                    "content": t.get("content")
                })
        
        data_list.append({
            "date": date_str,
            "timestamp": ts,
            "project": project_name,
            "title": sess_title,
            "todos": todos
        })
    
    # Sort by timestamp descending
    data_list.sort(key=lambda x: x["timestamp"], reverse=True)
    
    # Print as JSON string to stdout
    print(json.dumps(data_list[:20], indent=2))
    sys.stdout.flush()

if __name__ == "__main__":
    main()
