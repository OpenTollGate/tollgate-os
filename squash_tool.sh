#!/bin/bash

# Ensure we're on the correct branch
current_branch=$(git rev-parse --abbrev-ref HEAD)

# Find the commit where the current branch diverges from main
base_commit=$(git merge-base main HEAD)

# Create a temporary branch
temp_branch="temp_squash_branch_$(date +%s)"
git checkout -b $temp_branch

# Soft reset to the base commit
git reset --soft $base_commit

# Commit the changes with a new commit message
git commit -m "$current_branch"

# Force update the original branch
git branch -f $current_branch $temp_branch

# Switch back to the original branch
git checkout $current_branch

# Delete the temporary branch
git branch -D $temp_branch

# Force push to remote (be careful with this!)
git push origin +$current_branch
