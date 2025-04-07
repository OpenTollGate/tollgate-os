name: 'Update Release JSON from NIP-94 Events'
description: 'Updates release.json based on NIP-94 events, using only the newest event per architecture'
author: 'OpenTollGate'

inputs:
  artifacts_path:
    description: 'Path to the directory containing NIP-94 event files'
    required: true
  release_json_path:
    description: 'Path to the release.json file to update'
    required: true
  target_branch:
    description: 'Branch to push changes to'
    required: false
    default: 'develop'
  github_token:
    description: 'GitHub token for authentication'
    required: true
  commit_message:
    description: 'Commit message for the update'
    required: false
    default: 'Update release.json with NIP-94 events'
  verbose:
    description: 'Enable verbose output'
    required: false
    default: 'false'

runs:
  using: 'composite'
  steps:
    - name: Set up Python
      uses: actions/setup-python@v4
      with:
        python-version: '3.10'
    
    - name: Process NIP-94 Events
      shell: bash
      run: |
        echo "Looking for NIP-94 events in ${{ inputs.artifacts_path }}"
        ls -la ${{ inputs.artifacts_path }}
        
        # Create a backup of the original file
        cp ${{ inputs.release_json_path }} ${{ inputs.release_json_path }}.bak
        
        # Run the Python script
        VERBOSE_FLAG=""
        if [[ "${{ inputs.verbose }}" == "true" ]]; then
          VERBOSE_FLAG="--verbose"
        fi
        
        python3 ${{ github.action_path }}/update_release_json.py \
          --events-dir "${{ inputs.artifacts_path }}" \
          --release-json "${{ inputs.release_json_path }}" \
          $VERBOSE_FLAG
        
        # Show changes
        echo "Changes to release.json:"
        diff -u ${{ inputs.release_json_path }}.bak ${{ inputs.release_json_path }} || echo "No changes detected"
    
    - name: Commit and Push Changes
      shell: bash
      run: |
        # Configure git
        git config --local user.email "github-actions[bot]@users.noreply.github.com"
        git config --local user.name "github-actions[bot]"
        
        # Check if there are changes
        if git diff --exit-code ${{ inputs.release_json_path }}; then
          echo "No changes to commit."
          exit 0
        fi
        
        # Add, commit and push changes
        git add ${{ inputs.release_json_path }}
        git commit -m "${{ inputs.commit_message }}"
        echo "Pushing changes to ${{ inputs.target_branch }} branch..."
        git push https://${{ inputs.github_token }}@github.com/${{ github.repository }}.git HEAD:${{ inputs.target_branch }}