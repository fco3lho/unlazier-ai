---
name: bugfix
description: "Use when fixing a bug, defect, issue, or unexpected behavior. Follows Goal-Driven Execution: reproduce with a test, implement the fix, verify no regressions."
---

# Bug Fix Workflow

Follow these steps in order. Do not skip to implementation before reproducing the bug.

## Step 1: Reproduce

Write a test that reproduces the bug:

```python
def test_xxx_describing_the_bug():
    # Arrange
    input = ...
    expected = ...

    # Act
    result = function_under_test(input)

    # Assert
    assert result == expected
```

**Verify:** The test fails with the expected error.

## Step 2: Implement the Fix

Change the minimum code necessary. Follow Surgical Changes:
- Touch only the lines causing the bug
- Do not improve adjacent code, styles, or comments
- Match existing project style

## Step 3: Verify

- The reproduction test passes
- All existing tests still pass (no regressions)

## Step 4: Edge Cases

- Check null/empty/boundary cases related to this bug
- Add tests for those too
