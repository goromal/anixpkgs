import os
import re
import sys

file_path = sys.argv[1]

with open(file_path, 'r') as file:
    comment_body = file.read()

description_match = re.search(r"## Change Description\n+(.+?)\n", comment_body, re.DOTALL)
checkbox_marked = re.search(r"- \[x\] Add to global changelog", comment_body, re.IGNORECASE)

if description_match and checkbox_marked:
    change_description = description_match.group(1).strip()
    
    if change_description:
        print(change_description)
    else:
        print("NONE")
else:
    print("NONE")
