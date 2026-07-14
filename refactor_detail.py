import os
import re

file_path = r"b:\VS Code Projects\flutter apps\MyAnimes\lib\pages\detail_page.dart"
with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# Replace the build method logic
build_start = content.find("  @override\n  Widget build(BuildContext context) {")
if build_start == -1:
    print("Could not find build method")
    exit(1)

# We want to replace everything from `return PopScope(` down to `);` of the PopScope.
# So we can search for `    return PopScope(`
pop_scope_idx = content.find("    return PopScope(\n      canPop: false,\n      onPopInvokedWithResult: (didPop, result) { if (!didPop) widget.onBack(); },\n      child: Scaffold(\n        body: CustomScrollView(", build_start)

if pop_scope_idx != -1:
    print("Found pop_scope_idx")
