#!/bin/sh
# Runs every suite; nonzero if any fails.
cd "$(dirname "$0")" || exit 1
rc=0
for t in install_test.sh uninstall_test.sh read_guard_test.sh session_boot_test.sh settings_test.sh; do
  echo "##### $t"
  sh "./$t" || rc=1
done
exit "$rc"
