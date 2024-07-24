import requests

# Replace with your Notion API token and page ID
API_TOKEN = "secret_KYYedzDmimPocPqHOr9xeK3rDXf6xXQu6AYXllyfIAN"
PAGE_ID = "8fc778d7a4bf4102bd017ac1b74bbbaf" # ITNS/Kathleen

def create_notion_bulleted_list(data, level=0):
    """
    Converts a nested list into a list of blocks for Notion's API.
    
    :param data: A list of lists where each list represents a level of bullets.
    :param level: The current level of nesting (used internally for recursion).
    :return: A list of Notion API block objects.
    """
    if not isinstance(data, list):
        raise ValueError("Input data must be a list.")
    
    notion_blocks = []
    
    for item in data:
        if isinstance(item, list):
            # Recursively handle nested lists
            nested_blocks = create_notion_bulleted_list(item, level + 1)
            if notion_blocks:
                notion_blocks[-1]["bulleted_list_item"]["children"] = nested_blocks
            else:
                raise ValueError("Nested list structure is invalid.")
        else:
            # Create a block for a single item
            block = {
                "object": "block",
                "type": "bulleted_list_item",
                "bulleted_list_item": {
                    "rich_text": [
                        {
                            "type": "text",
                            "text": {
                                "content": str(item)
                            }
                        }
                    ]
                }
            }
            notion_blocks.append(block)
    
    return notion_blocks

# Headers for the API request
headers = {
    "Authorization": f"Bearer {API_TOKEN}",
    "Content-Type": "application/json",
    "Notion-Version": "2022-06-28"
}

# Data for the blocks you want to add
data = {
    "children": create_notion_bulleted_list([
        "Andrew", ["is", ["the"]], "best", ["husband"]
    ])
}

# URL for the Notion API to append blocks
url = f"https://api.notion.com/v1/blocks/{PAGE_ID}/children"

# Send the request
response = requests.patch(url, json=data, headers=headers)

# Check for success
if response.status_code == 200:
    print("Bulleted list added successfully!")
else:
    print(f"Error: {response.status_code}, {response.text}")