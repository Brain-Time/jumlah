#!/usr/bin/env python3
"""Generate audio for B1 lessons 120-200 in sequence."""
import subprocess, sys, os
lessons = list(range(120, 201))
total = len(lessons)
for i, lesson in enumerate(lessons):
    print(f"[{i+1}/{total}] Generating lesson {lesson}...")
    result = subprocess.run(
        [sys.executable, 'scripts/test_first_10.py', '--lesson', str(lesson)],
        capture_output=True, timeout=600
    )
    if result.returncode != 0:
        print(f"  ERROR: {result.stderr.decode()[:200]}")
    else:
        print(f"  OK")
print("Done!")