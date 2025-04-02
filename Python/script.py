import requests
import json
import time

API_URL = "http://127.0.0.1:8000/api/busroutes/"  # Django API URL
OUTPUT_FILE = r"D:\NMMT_FLUTTER\NaviBus\NaviBus\assets\busdata.json"  # Path to store JSON

def fetch_and_update_json():
    try:
        response = requests.get(API_URL)
        if response.status_code == 200:
            data = response.json()
            with open(OUTPUT_FILE, "w") as json_file:
                json.dump(data, json_file, indent=4)
            print("✅ Bus data updated successfully!")
        else:
            print(f"❌ Failed to fetch data. Status Code: {response.status_code}")
    except Exception as e:
        print(f"⚠️ Error fetching data: {e}")

if __name__ == "__main__":
    while True:
        fetch_and_update_json()
        time.sleep(5)  # Wait for 5 seconds before fetching data again
