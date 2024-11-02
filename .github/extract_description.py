import os
import re
import sys

# Get the comment body passed as an argument
comment_body = sys.argv[1]

# Regex to find the change description and the checkbox
description_match = re.search(r"## Change Description\s+\n+(.+?)\n", comment_body, re.DOTALL)
checkbox_marked = re.search(r"- \[x\] Add to global changelog", comment_body, re.IGNORECASE)

if description_match and checkbox_marked:
    # Extract and clean the change description text
    change_description = description_match.group(1).strip()
    
    # Set the change description as an output for GitHub Actions
    print(f"::set-output name=CHANGE_DESCRIPTION::{change_description}")
else:
    print(f"::set-output name=CHANGE_DESCRIPTION::NONE")
