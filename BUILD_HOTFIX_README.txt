SlamDone V7.14.7 - GitHub Flutter Web Build Hotfix

Apply this AFTER the V7.14.7 responsive/tables patch that triggered GitHub Actions run #50.

Root cause fixed:
- do_first_screen.dart passed `tooltip:` directly to TextButton.icon.
- Flutter's TextButton.icon constructor does not accept a tooltip named parameter, so Flutter web compilation stops before deployment.
- The visible Show/Hide filters label already makes that tooltip unnecessary, so the unsupported parameter was removed without changing the requested behavior.

Upload/overwrite these root-relative files in your SlamDone repository:
- lib/src/screens/do_first_screen.dart
- tool_tests/test_slamdone_v7147_build_hotfix_contract.py

No database, Firebase, sync, task data, table data, or settings schema files are changed by this hotfix.
