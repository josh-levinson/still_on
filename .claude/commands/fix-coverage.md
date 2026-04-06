Parse `coverage/.resultset.json` to find uncovered branches, then write tests to cover them.

## Steps

1. Read `coverage/.resultset.json`
2. Parse the JSON to find all branch keys with a value of `0` (uncovered). The structure is:
   `data[suite_name][coverage][file_path][branches][branch_key] = hit_count`
3. For each uncovered branch, read the source file to understand the code path
4. Write or extend tests in the appropriate `test/` file to exercise that branch
5. Run `bin/rails test` to confirm the new tests pass

Focus only on application code (skip `db/`, `config/`, `vendor/`, `bin/`).
