import json
import os
import glob
import shutil

# Config
OPENCODE_DIR = "/Users/caishanghong/.local/share/opencode/storage"
BRAIN_DIR = "/Users/caishanghong/.gemini/antigravity/brain"
TARGET_DIR = "/Users/caishanghong/Shopify/cli-tool/MyLLMNote"

# Mappings (from previous step)
OPENCODE_MAPPING = {
    "d329ad9b8f0c71288c703267547b1008d21a8e86": "CodeWiki",
    "add233c5043264d47ecc6d3339a383f41a241ae8": "llxprt-code",
    "2d29ffdf53f6a91efce2d0304aad9089385cea58": "CodeWiki"
}

ANTIGRAVITY_MAPPING = {
    "9038fd29-6a71-48e5-9f4a-991c6e708bd9": "CodeWiki",
    "19b78f8b-44be-402c-97f7-e713e5c9f6c9": "CodeWiki",
    "41b7afb6-93a3-44c8-b3f2-15925c28485f": "CodeWiki",
    "a23b76fd-8e45-4fba-a290-640871f0ea9a": "llxprt-code",
    "748703dc-f7d4-4b64-b0ac-a79c7a06d693": "llxprt-code",
    "b5bc4f6f-ed6a-49f3-be16-95716b28257c": "llxprt-code",
    "2b17b9f3-fd47-4403-b23e-a15e46f69736": "CodeWiki",
    "db9177a6-5a0e-4aed-ab83-8ec071b1078c": "llxprt-code",
    "223c9831-d817-4a30-a16c-52bfa9085b18": "llxprt-code",
    "f4182ee1-ea5d-469a-9972-a5d1749e7105": "llxprt-code",
    "1121a3ee-459c-40b2-b86f-7b86564a1cb3": "llxprt-code",
    "7839dabe-d5a7-440e-9a91-8efc9ed8ab93": "llxprt-code",
    "c5784b9e-0bd6-4822-aacc-97f832b301f7": "llxprt-code",
    "3347439a-d7df-4d33-b8f0-7756e4b323f7": "CodeWiki",
    "7248c104-3e66-4f17-946a-472790e39773": "llxprt-code",
    "7ee86aa0-5d56-4781-b7aa-6683fef83095": "CodeWiki",
    "d8053952-039a-4e8c-b3d7-17c6a2795a7b": "llxprt-code",
    "29bcaa4e-0080-4816-83ba-6b9be5e7e060": "CodeWiki",
    "cc881aa8-2376-4413-9ffd-2df9e3200323": "llxprt-code",
    "e5d945a7-e9f5-4d19-8785-f48e9c29963b": "llxprt-code",
    "7906414f-3dc1-4452-9b96-13cf2108257e": "llxprt-code",
    "08245ea5-9105-4b83-8e9a-ad0e11967ea3": "llxprt-code",
    "a26eba05-6f47-4f7b-b72f-359bf33520aa": "CodeWiki",
    "3a428465-4482-42ed-8f08-452a32fa2b7c": "llxprt-code",
    "b7134853-c376-4e82-941b-32fa68200d1e": "CodeWiki",
    "5326b033-08ca-4ac2-8ae5-546c24664494": "CodeWiki",
    "848a62d7-51b3-4016-badd-81e6dba9ca30": "llxprt-code",
    "3ab59064-4305-4ec2-a0d3-4ec372aee44c": "llxprt-code",
    "f54f70aa-8304-4e71-88c1-c2970ef637d1": "llxprt-code",
    "8904ae04-1308-47f4-a1e2-a899dc860b36": "CodeWiki",
    "be07420c-f019-439b-bfaf-171328c12583": "llxprt-code",
    "a0c75142-4be2-4289-bffc-07f99f0b5650": "llxprt-code",
    "ea6a3310-c907-4af3-8ca5-c0549c678037": "CodeWiki",
    "7b2770fe-5b28-4a7a-a72d-4cdb7a593ebc": "llxprt-code",
    "0a732cb1-a6b2-4b72-ba36-65ab416c2cf1": "llxprt-code",
    "7a320a38-36e3-4cfd-b09f-a38a7c0b1616": "llxprt-code",
    "93f007cf-4221-49c4-bbef-418951b32333": "llxprt-code",
    "6910fce3-ab8a-4faf-b72e-a583a4a9265f": "llxprt-code",
    "255aca39-fcd6-4dd6-82ae-26f9cf07b207": "CodeWiki",
    "eba36d9b-abe4-45c4-abe9-3a47a15661b9": "CodeWiki",
    "b2620f74-fc39-43a3-b772-c0b3a43c991f": "CodeWiki",
    "d94ee6dd-4f45-490b-92df-dc7c98f0e078": "llxprt-code"
}

def ensure_dir(path):
    if not os.path.exists(path):
        os.makedirs(path)

def copy_antigravity():
    print("Copying Antigravity conversations...")
    for conv_id, category in ANTIGRAVITY_MAPPING.items():
        src = os.path.join(BRAIN_DIR, conv_id)
        if not os.path.exists(src):
            print(f"Skipping {conv_id} (not found)")
            continue
            
        dest_base = os.path.join(TARGET_DIR, category, "Antigravity")
        ensure_dir(dest_base)
        dest = os.path.join(dest_base, conv_id)
        
        # Copy directory structure
        if os.path.exists(dest):
            shutil.rmtree(dest)
        
        try:
            shutil.copytree(src, dest)
            print(f"Copied {conv_id} to {category}/Antigravity")
        except Exception as e:
            print(f"Error copying {conv_id}: {e}")

def copy_opencode():
    print("Copying Opencode sessions...")
    session_root = os.path.join(OPENCODE_DIR, "session")
    for pid, category in OPENCODE_MAPPING.items():
        src_dir = os.path.join(session_root, pid)
        if not os.path.exists(src_dir):
            print(f"Skipping Opencode project {pid} (no session dir)")
            continue
            
        dest_base = os.path.join(TARGET_DIR, category, "Opencode", pid)
        ensure_dir(dest_base)
        
        try:
            # Copy all session files in this project dir
            for item in os.listdir(src_dir):
                s = os.path.join(src_dir, item)
                d = os.path.join(dest_base, item)
                if os.path.isfile(s):
                    shutil.copy2(s, d)
                elif os.path.isdir(s):
                    if os.path.exists(d): shutil.rmtree(d)
                    shutil.copytree(s, d)
            print(f"Copied Opencode project {pid} sessions to {category}/Opencode")
        except Exception as e:
            print(f"Error copying opencode project {pid}: {e}")

def main():
    ensure_dir(TARGET_DIR)
    
    copy_antigravity()
    copy_opencode()
    
    print("Migration complete.")

if __name__ == "__main__":
    main()
