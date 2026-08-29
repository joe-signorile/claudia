"""Minimal parser for the eval/tasks/*.md frontmatter dialect.

Not a general YAML parser — handles exactly the shape used in this repo's
task files: top-level scalar `key: value` lines, and top-level `key:`
followed by a list of `- id: ... \n    text: ...`-style mapping items.
Stdlib only, no PyYAML dependency, because the schema is fully within this
repo's control.
"""
import re


def parse(path):
    """Return (frontmatter_dict, body_text) for a task markdown file."""
    text = open(path, encoding="utf-8").read()
    lines = text.split("\n")
    if lines[0].strip() != "---":
        raise ValueError(f"{path}: missing frontmatter opening ---")
    end = None
    for i in range(1, len(lines)):
        if lines[i].strip() == "---":
            end = i
            break
    if end is None:
        raise ValueError(f"{path}: missing frontmatter closing ---")

    fm_lines = lines[1:end]
    body = "\n".join(lines[end + 1:]).strip("\n") + "\n"

    data = {}
    current_list_key = None
    current_item = None

    for raw in fm_lines:
        if not raw.strip():
            continue
        indent = len(raw) - len(raw.lstrip(" "))
        line = raw.strip()

        if indent == 0:
            m = re.match(r"^([A-Za-z0-9_]+):\s*(.*)$", line)
            if not m:
                continue
            key, val = m.group(1), m.group(2)
            if val == "":
                # Start of a list-of-mappings value.
                current_list_key = key
                data[key] = []
                current_item = None
            else:
                current_list_key = None
                data[key] = _scalar(val)
        elif line.startswith("- "):
            # New list item: "- id: foo"
            current_item = {}
            data[current_list_key].append(current_item)
            m = re.match(r"^- ([A-Za-z0-9_]+):\s*(.*)$", line)
            if m:
                current_item[m.group(1)] = _scalar(m.group(2))
        else:
            m = re.match(r"^([A-Za-z0-9_]+):\s*(.*)$", line)
            if m and current_item is not None:
                current_item[m.group(1)] = _scalar(m.group(2))

    return data, body


def _scalar(val):
    val = val.strip()
    if len(val) >= 2 and val[0] == val[-1] and val[0] in "\"'":
        return val[1:-1]
    return val
