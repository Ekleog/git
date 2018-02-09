#!/bin/sh

test_description='testing tweak-fetch-hook'
. ./test-lib.sh

HOOKDIR="$(git rev-parse --git-dir)/hooks"
HOOK="$HOOKDIR/tweak-fetch"
mkdir -p "$HOOKDIR"

# Setup
test_expect_success 'setup' '
	git init parent-repo &&
	git remote add parent parent-repo &&
	(cd parent-repo && test_commit commit-100) &&
	git fetch parent &&
	git tag | grep -E "^commit-100$"
'

# No-effect hook
write_script "$HOOK" <<EOF
cat
EOF
test_expect_success 'no-op hook' '
	(cd parent-repo && test_commit commit-200) &&
	git fetch parent &&
	git tag | grep -E "^commit-200$"
'

# Ref-renaming hook
write_script "$HOOK" <<EOF
sed 's/commit-/tag-/g'
EOF
test_expect_success 'ref-renaming hook' '
	(cd parent-repo && test_commit commit-300) &&
	git fetch parent &&
	git tag | grep -E "^tag-300" &&
	! git tag | grep -E "^commit-300"
'

# Drop branch
write_script "$HOOK" <<EOF
cat
EOF
test_expect_success 'dropping hook setup' '
	(cd parent-repo && test_commit commit-400) &&
	git fetch parent &&
	test "$(git rev-parse parent/master)" = "$(git rev-parse commit-400)"
'
write_script "$HOOK" <<EOF
grep -v 'refs/remotes/parent/master'
exit 0
EOF
test_expect_success 'dropping hook' '
	(cd parent-repo && test_commit commit-401) &&
	git fetch parent &&
	test "$(git rev-parse parent/master)" = "$(git rev-parse commit-400)" &&
	chmod -x "'"$HOOK"'" &&
	git fetch parent &&
	test "$(git rev-parse parent/master)" = "$(git rev-parse commit-401)"
'

# Repointing hook
write_script "$HOOK" <<EOF
cat
EOF
test_expect_success 'repointing hook setup' '
	(cd parent-repo && test_commit commit-500) &&
	git fetch parent
'
write_script "$HOOK" <<'EOF'
while read hash merge remote_ref local_ref; do
	if [ "$local_ref" = "refs/remotes/parent/master" ]; then
		repointed="$(git rev-parse "$hash^")"
		echo "$repointed $merge $remote_ref $local_ref"
	else
		echo "$hash $merge $remote_ref $local_ref"
	fi
done
exit 0
EOF
test_expect_success 'repointing hook' '
	(cd parent-repo && test_commit commit-501 && test_commit commit-502) &&
	git fetch parent &&
	test "$(git rev-parse parent/master)" = "$(git rev-parse commit-501)" &&
	(cd parent-repo && test_commit commit-503) &&
	git fetch parent &&
	test "$(git rev-parse parent/master)" = "$(git rev-parse commit-502)"
'

test_done
