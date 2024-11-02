import os
import re
import sys

comment_body = sys.argv[1]

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
