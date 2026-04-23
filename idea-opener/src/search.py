#!/usr/bin/python3
# encoding: utf-8
import functools
import os
import re
import sys
from xml.etree import ElementTree

from Feedback import Feedback

PROJECT_DIR = "/Users/huqiang/soft/java_project"
JETBRAINS_DIR = os.path.expanduser("~/Library/Application Support/JetBrains")


class Project:
    def __init__(self, name, path, time=0):
        self.name = name
        self.path = path
        self.time = time


def is_project_dir(path):
    """判断是否是 Java/Go 项目（含 pom.xml 或 go.mod）"""
    if os.path.isdir(path):
        try:
            files = os.listdir(path)
            return "pom.xml" in files or "go.mod" in files
        except PermissionError:
            pass
    return False


def search(workspace, keyword):
    """搜索工作空间下第1、2级目录的 Java/Go 项目"""
    results = []
    try:
        for name in os.listdir(workspace):
            fullpath = os.path.join(workspace, name)
            if not os.path.isdir(fullpath) or name.startswith('.'):
                continue
            # 第1级
            if is_project_dir(fullpath) and re.search(keyword, name, re.IGNORECASE):
                results.append(Project(name, fullpath))
            # 第2级
            try:
                for sub in os.listdir(fullpath):
                    subfull = os.path.join(fullpath, sub)
                    if not os.path.isdir(subfull) or sub.startswith('.'):
                        continue
                    if is_project_dir(subfull) and re.search(keyword, sub, re.IGNORECASE):
                        results.append(Project(sub, subfull))
            except PermissionError:
                pass
    except PermissionError:
        pass
    return results


def find_idea_dir():
    """找到最新版本的 IntelliJ IDEA 配置目录"""
    if not os.path.isdir(JETBRAINS_DIR):
        return None
    dirs = [d for d in os.listdir(JETBRAINS_DIR) if d.startswith("IntelliJIdea")]
    if not dirs:
        return None
    dirs.sort(reverse=True)
    return os.path.join(JETBRAINS_DIR, dirs[0])


def recent_projects():
    """读取 IDEA 最近打开的项目列表"""
    results = []
    idea_dir = find_idea_dir()
    if not idea_dir:
        return results

    xml_path = os.path.join(idea_dir, "options", "recentProjects.xml")
    if not os.path.isfile(xml_path):
        return results

    try:
        tree = ElementTree.parse(xml_path)
        for component in tree.findall("./component/"):
            if component.get("name") == "additionalInfo":
                entries = component.findall("map/entry")
                for entry in entries:
                    path = os.path.expanduser(entry.get("key", "").replace("$USER_HOME$", "~"))
                    name = path.rstrip("/").split("/")[-1]
                    time = 0
                    for o in entry.findall("value/RecentProjectMetaInfo/option"):
                        if o.get("name") == "activationTimestamp":
                            try:
                                time = int(o.get("value", "0"))
                            except ValueError:
                                pass
                    results.append(Project(name, path, time))
    except Exception:
        pass

    # 过滤不存在的路径
    results = [p for p in results if os.path.isdir(p.path)]
    return results


def sort_fun(p1, p2):
    """按最近使用时间倒序，相同时间按名字排"""
    if p1.time < p2.time:
        return -1
    elif p1.time > p2.time:
        return 1
    else:
        if p1.name < p2.name:
            return 1
        elif p1.name > p2.name:
            return -1
        return 0


if __name__ == '__main__':
    fb = Feedback()
    projects = []

    if len(sys.argv) < 2 or sys.argv[1].strip() == "":
        # 无参数：显示最近打开的项目
        projects = recent_projects()
    else:
        # 有参数：搜索项目
        arg = sys.argv[1].strip()
        projects = search(PROJECT_DIR, arg)

    projects.sort(key=functools.cmp_to_key(sort_fun), reverse=True)
    projects = projects[:9]
    for p in projects:
        fb.add_item(p.name, p.path, p.path)

    if fb.isEmpty():
        keyword = sys.argv[1] if len(sys.argv) >= 2 else ""
        fb.add_item("找不到项目: " + keyword, "找不到这个项目，请确认输入没有错🙅‍♂️!", valid="no")

    print(fb)
