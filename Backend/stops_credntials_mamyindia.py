import requests
import csv
import os
import json

# Load stops from stops.json
with open(r"D:\NMMT_FLUTTER\NaviBus\Backend\stops.json", "r", encoding="utf-8") as f:
    BUS_STOPS = json.load(f)

def search_location(bus_stop, access_token=None):
    url = "https://nominatim.openstreetmap.org/search"
    address_variants = [
        f"{bus_stop} bus stop, Navi Mumbai, Maharashtra, India",
        f"{bus_stop} sector, Navi Mumbai, Maharashtra, India",
        f"{bus_stop} road, Navi Mumbai, Maharashtra, India",
        f"{bus_stop}, Navi Mumbai, Maharashtra, India",
        f"{bus_stop} bus stop, Mumbai, Maharashtra, India",
        f"{bus_stop}, Mumbai, Maharashtra, India"
    ]
    headers = {
        "User-Agent": "NaviBus/1.0 (your_email@example.com)"
    }
    import time
    for address in address_variants:
        params = {
            "q": address,
            "format": "json",
            "limit": 1
        }
        try:
            res = requests.get(url, headers=headers, params=params, timeout=10)
            res.raise_for_status()
            results = res.json()
            if results:
                loc = results[0]
                return {
                    "name": bus_stop,
                    "latitude": loc.get("lat", ""),
                    "longitude": loc.get("lon", ""),
                    "eLoc": ""
                }
        except Exception as e:
            print(f"❌ Error searching '{bus_stop}' with address '{address}': {e}")
            print(f"Response text: {getattr(res, 'text', 'No response')}")
        time.sleep(1)  # Be polite to the API and avoid rate-limiting
    # If OSM fails, try Google Search scraping for coordinates
    print(f"🌐 Trying Google Search for: {bus_stop}")
    coords = scrape_google_search_for_coords(bus_stop)
    if coords:
        return {
            "name": bus_stop,
            "latitude": coords[0],
            "longitude": coords[1],
            "eLoc": ""
        }
    # If direct coordinates not found, try to extract similar place names from Google Search and retry OSM
    print(f"🔎 Trying to extract similar names from Google Search for: {bus_stop}")
    similar_names = scrape_google_search_for_similar_names(bus_stop)
    for name in similar_names:
        print(f"↪️ Retrying OSM with similar name: {name}")
        for variant in [
            f"{name} bus stop, Navi Mumbai, Maharashtra, India",
            f"{name} sector, Navi Mumbai, Maharashtra, India",
            f"{name} road, Navi Mumbai, Maharashtra, India",
            f"{name}, Navi Mumbai, Maharashtra, India",
            f"{name} bus stop, Mumbai, Maharashtra, India",
            f"{name}, Mumbai, Maharashtra, India"
        ]:
            params = {
                "q": variant,
                "format": "json",
                "limit": 1
            }
            try:
                res = requests.get(url, headers=headers, params=params, timeout=10)
                res.raise_for_status()
                results = res.json()
                if results:
                    loc = results[0]
                    print(f"✅ Found using similar name: {name}")
                    return {
                        "name": bus_stop,
                        "latitude": loc.get("lat", ""),
                        "longitude": loc.get("lon", ""),
                        "eLoc": ""
                    }
            except Exception as e:
                print(f"❌ Error searching '{bus_stop}' with similar name '{name}': {e}")
                print(f"Response text: {getattr(res, 'text', 'No response')}")
            import time
            time.sleep(1)
    return {
        "name": bus_stop,
        "latitude": "",
        "longitude": "",
        "eLoc": ""
    }

# --- Scrape similar place names from Google Search ---
def scrape_google_search_for_similar_names(bus_stop):
    """
    Scrape Google Search results for similar place names (e.g., from titles/snippets).
    Returns a list of alternative names.
    """
    import re
    from bs4 import BeautifulSoup
    try:
        query = f"{bus_stop} Navi Mumbai bus stop"
        url = f"https://www.google.com/search?q={requests.utils.quote(query)}"
        headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
        }
        res = requests.get(url, headers=headers, timeout=10)
        res.raise_for_status()
        soup = BeautifulSoup(res.text, "html.parser")
        # Extract titles/snippets from search results
        names = set()
        for tag in soup.find_all(['h3', 'span', 'div']):
            text = tag.get_text()
            # Heuristic: look for lines containing 'bus stop' or similar
            match = re.search(r'([A-Za-z0-9\-\'\s]+bus stop)', text, re.IGNORECASE)
            if match:
                name = match.group(1).strip()
                if len(name) > 5 and name.lower() != bus_stop.lower():
                    names.add(name)
        # Also look for bolded query matches
        for b in soup.find_all('b'):
            t = b.get_text()
            if 'bus stop' in t.lower() and t.lower() != bus_stop.lower():
                names.add(t.strip())
        return list(names)
    except Exception as e:
        print(f"❌ Google Search similar name scraping failed for '{bus_stop}': {e}")
    return []

# --- Google Search scraping fallback ---
import re
from bs4 import BeautifulSoup
def scrape_google_search_for_coords(bus_stop):
    """
    Try to extract coordinates from Google Search results page for the bus stop.
    Returns (lat, lon) tuple or None.
    """
    try:
        query = f"{bus_stop} Navi Mumbai coordinates"
        url = f"https://www.google.com/search?q={requests.utils.quote(query)}"
        headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
        }
        res = requests.get(url, headers=headers, timeout=10)
        res.raise_for_status()
        soup = BeautifulSoup(res.text, "html.parser")
        # Try to find coordinates in the snippet (e.g. "19.033, 73.029")
        text = soup.get_text()
        match = re.search(r"([+-]?\d+\.\d{3,}),\s*([+-]?\d+\.\d{3,})", text)
        if match:
            lat, lon = match.group(1), match.group(2)
            print(f"✅ Google Search found: {lat}, {lon}")
            return lat, lon
    except Exception as e:
        print(f"❌ Google Search scraping failed for '{bus_stop}': {e}")
    return None


def get_processed_stops(output_csv):
    processed_stops = set()
    if os.path.exists(output_csv):
        with open(output_csv, "r", encoding="utf-8") as f:
            reader = csv.DictReader(f)
            for row in reader:
                if row["latitude"] and row["longitude"]:
                    processed_stops.add(row["name"])
    return processed_stops


def process_bus_stops(output_csv, failed_csv):
    processed_stops = get_processed_stops(output_csv)
    remaining_stops = [stop for stop in BUS_STOPS if stop not in processed_stops]
    print(f"📋 Found {len(processed_stops)} already processed. Processing {len(remaining_stops)} more...")

    if not remaining_stops:
        print("✅ All bus stops already processed.")
        return

    failed_stops = []
    failed_details = []

    with open(output_csv, "a", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["name", "latitude", "longitude", "eLoc"])
        if not os.path.exists(output_csv) or os.path.getsize(output_csv) == 0:
            writer.writeheader()

        for i, stop in enumerate(remaining_stops):
            print(f"🔍 [{i+1}/{len(remaining_stops)}] {stop}")
            result = search_location(stop)
            if result is None or not result["latitude"]:
                print(f"⚠️ Failed: {stop}")
                failed_stops.append(stop)
                # Log the address variants tried for this stop
                failed_details.append({"stop": stop})
            else:
                writer.writerow(result)

    # Write failed stops to CSV for retry
    if failed_stops:
        with open(failed_csv, "w", newline="", encoding="utf-8") as f:
            writer = csv.writer(f)
            writer.writerow(["name"])
            for stop in failed_stops:
                writer.writerow([stop])
        # Also log details for manual review
        with open(failed_csv.replace('.csv', '_details.txt'), "w", encoding="utf-8") as f:
            for detail in failed_details:
                f.write(str(detail) + "\n")
        print(f"⚠️ {len(failed_stops)} lookups failed. Saved to '{failed_csv}' and details to '{failed_csv.replace('.csv', '_details.txt')}'.")

    print(f"\n✅ All done. Saved to: {output_csv}")

# Run the script
if __name__ == "__main__":
    process_bus_stops("bus_stop_locations.csv", "failed_stops.csv")
