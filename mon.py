import requests
import json
import uuid
import re

def normalize_guid(guid: str) -> str:
    print("Original GUID:", guid)
    # Remove colons and normalize to UUID format
    if ':' in guid:
        parts = guid.split(':')

            # Convert to a full 32-character hex string
        guid = f"{parts[0]:0>8}-{parts[1][:4]}-{parts[1][4:]}-{parts[2][:4]}-{parts[2][4:]:0<8}{parts[3]:0>4}"
        

    print("Normalized GUID:", guid)
    # Convert to UUID object for comparison
    return guid#str(uuid.UUID(guid))

def download_json(url):
    try:
        response = requests.get(url)
        response.raise_for_status()
        parsed_json = response.json()
        print("Received JSON:", json.dumps(parsed_json, indent=4))
        return parsed_json
    except requests.exceptions.RequestException as e:
        print("HTTP Request failed:", e)
    except json.JSONDecodeError as e:
        print("Invalid JSON received:", e)
    return None

if __name__ == "__main__":

    

    url = "http://192.168.0.223:62641"
    monitorJson = download_json(url)


# 01104afb-f5fe-2649-5424-98a900000702,
# 01104afb-f5fe-2649-5424-98a900000702
# 01104afb-f5fe-2649-5424-98a90702
# 1104afb:f5fe2649:542498a9:702
# 01104afb-f5fe-2649-542498a9-702"
# 01104afb-f5fe-2649-5424-98a9100c2