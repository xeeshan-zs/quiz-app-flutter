
import requests

try:
    response = requests.get("https://rfid-numl.web.app/")
    print(response.text)
except Exception as e:
    print(e)
