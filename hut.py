#!/usr/bin/env python3
"""HUT - HTML 托管展示平台 CLI 工具

用法: hut <command> [options]
"""
import sys
import os
import json
import random
import string
import shutil
import subprocess
from datetime import datetime, timezone

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
MANIFEST = os.path.join(SCRIPT_DIR, "manifest.json")
APPS_DIR = os.path.join(SCRIPT_DIR, "apps")

def ensure_dirs():
    os.makedirs(APPS_DIR, exist_ok=True)
    if not os.path.exists(MANIFEST):
        with open(MANIFEST, "w", encoding="utf-8") as f:
            json.dump({"items": []}, f, ensure_ascii=False)

def read_manifest():
    with open(MANIFEST, "r", encoding="utf-8") as f:
        return json.load(f)

def write_manifest(data):
    with open(MANIFEST, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

def gen_id():
    chars = string.ascii_lowercase + string.digits
    while True:
        rid = "".join(random.choices(chars, k=6))
        if not os.path.exists(os.path.join(APPS_DIR, f"{rid}.html")):
            return rid

def auto_commit(msg):
    try:
        subprocess.run(["git", "add", "manifest.json", "apps/"],
                       cwd=SCRIPT_DIR, capture_output=True)
        subprocess.run(["git", "commit", "-m", msg, "--quiet"],
                       cwd=SCRIPT_DIR, capture_output=True)
    except Exception:
        pass

def cmd_upload(args):
    file = name = desc = cat = tags = None
    i = 0
    while i < len(args):
        if args[i] == "--name" and i + 1 < len(args):
            name = args[i + 1]; i += 2
        elif args[i] == "--desc" and i + 1 < len(args):
            desc = args[i + 1]; i += 2
        elif args[i] == "--cat" and i + 1 < len(args):
            cat = args[i + 1]; i += 2
        elif args[i] == "--tags" and i + 1 < len(args):
            tags = args[i + 1]; i += 2
        elif args[i].startswith("-"):
            print(f"❌ 未知选项: {args[i]}"); sys.exit(1)
        else:
            file = args[i]; i += 1

    if not file:
        print('❌ 用法: hut upload <file.html> --name "名称" --desc "描述" --cat "分类" [--tags "t1,t2"]')
        sys.exit(1)
    if not name or not desc or not cat:
        print("❌ 缺少必填参数: --name, --desc, --cat 均为必填")
        print('用法: hut upload <file.html> --name "名称" --desc "描述" --cat "分类" [--tags "t1,t2"]')
        sys.exit(1)
    if not os.path.isfile(file):
        print(f"❌ 文件不存在: {file}")
        sys.exit(1)
    if not file.lower().endswith(".html"):
        print("❌ 仅支持 .html 文件")
        sys.exit(1)

    rid = gen_id()
    shutil.copy2(file, os.path.join(APPS_DIR, f"{rid}.html"))

    data = read_manifest()
    tags_list = [t.strip() for t in tags.split(",")] if tags else []
    item = {
        "id": rid,
        "name": name,
        "description": desc,
        "category": cat,
        "filename": f"{rid}.html",
        "uploaded_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "tags": tags_list,
    }
    data["items"].append(item)
    write_manifest(data)
    auto_commit(f"feat: 添加 {name}")

    print(f"✅ 已上传: {name} (id: {rid})")
    print("   运行 'hut push' 推送到 GitHub Pages")

def cmd_list(args):
    cat_filter = search = None
    i = 0
    while i < len(args):
        if args[i] == "--cat" and i + 1 < len(args):
            cat_filter = args[i + 1]; i += 2
        elif args[i] == "--search" and i + 1 < len(args):
            search = args[i + 1]; i += 2
        else:
            i += 1

    data = read_manifest()
    items = data.get("items", [])
    if not items:
        print("暂无已上传的 HTML 页面")
        return

    if cat_filter:
        items = [it for it in items if it.get("category") == cat_filter]
    if search:
        q = search.lower()
        items = [it for it in items if q in it.get("name", "").lower() or q in it.get("description", "").lower()]

    items.sort(key=lambda x: x.get("uploaded_at", ""), reverse=True)

    print(f"{'ID':<10} {'名称':<20} {'分类':<10} {'上传时间'}")
    print(f"{'──':<10} {'────':<20} {'────':<10} {'────────'}")
    for it in items:
        print(f"{it['id']:<10} {it['name']:<20} {it['category']:<10} {it.get('uploaded_at', '')}")

def cmd_delete(args):
    if not args:
        print("❌ 用法: hut delete <id>")
        sys.exit(1)
    did = args[0]
    data = read_manifest()
    found = [it for it in data["items"] if it["id"] == did]
    if not found:
        print(f"❌ 未找到 ID: {did}")
        sys.exit(1)
    dname = found[0]["name"]
    fp = os.path.join(APPS_DIR, f"{did}.html")
    if os.path.exists(fp):
        os.remove(fp)
    data["items"] = [it for it in data["items"] if it["id"] != did]
    write_manifest(data)
    auto_commit(f"feat: 删除 {dname}")
    print(f"✅ 已删除: {dname}")

def cmd_update(args):
    if not args:
        print('❌ 用法: hut update <id> [--name "名称"] [--desc "描述"] [--cat "分类"] [--tags "t1,t2"]')
        sys.exit(1)
    uid = args[0]
    name = desc = cat = tags = None
    i = 1
    while i < len(args):
        if args[i] == "--name" and i + 1 < len(args):
            name = args[i + 1]; i += 2
        elif args[i] == "--desc" and i + 1 < len(args):
            desc = args[i + 1]; i += 2
        elif args[i] == "--cat" and i + 1 < len(args):
            cat = args[i + 1]; i += 2
        elif args[i] == "--tags" and i + 1 < len(args):
            tags = args[i + 1]; i += 2
        else:
            i += 1

    data = read_manifest()
    item = next((it for it in data["items"] if it["id"] == uid), None)
    if not item:
        print(f"❌ 未找到 ID: {uid}")
        sys.exit(1)
    if name: item["name"] = name
    if desc: item["description"] = desc
    if cat:  item["category"] = cat
    if tags: item["tags"] = [t.strip() for t in tags.split(",")]
    write_manifest(data)
    auto_commit(f"feat: 更新 {uid} 元数据")
    print(f"✅ 已更新: {uid}")

def cmd_replace(args):
    if len(args) < 2:
        print("❌ 用法: hut replace <id> <file.html>")
        sys.exit(1)
    rid, rfile = args[0], args[1]
    if not os.path.isfile(rfile):
        print(f"❌ 文件不存在: {rfile}")
        sys.exit(1)
    data = read_manifest()
    found = [it for it in data["items"] if it["id"] == rid]
    if not found:
        print(f"❌ 未找到 ID: {rid}")
        sys.exit(1)
    shutil.copy2(rfile, os.path.join(APPS_DIR, f"{rid}.html"))
    auto_commit(f"feat: 替换 {rid} 文件")
    print(f"✅ 已替换: {rid}")

def cmd_push():
    result = subprocess.run(
        ["git", "push", "origin", "gh-pages"],
        cwd=SCRIPT_DIR, capture_output=True, text=True
    )
    if result.returncode != 0:
        print(f"❌ 推送失败: {result.stderr.strip()}")
        sys.exit(1)
    print("✅ 已推送到 GitHub Pages")

def cmd_help(subcmd=None):
    helps = {
        "upload":  '用法: hut upload <file.html> --name "名称" --desc "描述" --cat "分类" [--tags "t1,t2"]',
        "list":    "用法: hut list [--cat 分类] [--search 关键词]",
        "delete":  "用法: hut delete <id>",
        "update":  '用法: hut update <id> [--name "名称"] [--desc "描述"] [--cat "分类"] [--tags "t1,t2"]',
        "replace": "用法: hut replace <id> <file.html>",
        "push":    "用法: hut push\n执行 git push 到远程仓库，触发 GitHub Pages 更新",
    }
    if subcmd and subcmd in helps:
        print(helps[subcmd])
        return

    print("HUT - HTML 托管展示平台 CLI 工具")
    print()
    print("用法: hut <命令> [选项]")
    print()
    print("命令:")
    print("  upload <file>   上传新 HTML 页面")
    print("  list            列出已上传的 HTML")
    print("  delete <id>     删除指定 HTML")
    print("  update <id>     更新元数据")
    print("  replace <id>    替换 HTML 文件")
    print("  push            推送到 GitHub Pages")
    print("  help [cmd]      显示帮助信息")
    print()
    print("运行 'hut help <command>' 查看命令详情")

def main():
    ensure_dirs()
    args = sys.argv[1:]
    if not args or args[0] == "help":
        cmd_help(args[1] if len(args) > 1 else None)
        return

    cmd = args[0]
    rest = args[1:]

    if cmd == "upload":   cmd_upload(rest)
    elif cmd == "list":   cmd_list(rest)
    elif cmd == "delete": cmd_delete(rest)
    elif cmd == "update": cmd_update(rest)
    elif cmd == "replace": cmd_replace(rest)
    elif cmd == "push":   cmd_push()
    else:
        print(f"❌ 未知命令: {cmd}")
        print("运行 'hut help' 查看帮助")
        sys.exit(1)

if __name__ == "__main__":
    main()