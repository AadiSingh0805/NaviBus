import React, { useState, useEffect } from "react";
import { MapContainer, TileLayer, Marker, Popup, Polyline } from "react-leaflet";
import "leaflet/dist/leaflet.css";
import L from "leaflet";
import markerIconPng from "leaflet/dist/images/marker-icon.png";
import { Dropdown, DropdownButton } from "react-bootstrap";
import "bootstrap/dist/css/bootstrap.min.css";
import "./MapStyles.css";
import axios from "axios";
import Navbar from "../components/Navbar"; // ✅ Import Navbar component

// 📍 Icons
const busIcon = new L.Icon({
  iconUrl: markerIconPng,
  iconSize: [25, 41],
  iconAnchor: [12, 41],
  popupAnchor: [1, -34],
});

const userIcon = new L.Icon({
  iconUrl: "https://cdn-icons-png.flaticon.com/512/684/684908.png",
  iconSize: [30, 30],
  iconAnchor: [15, 30],
  popupAnchor: [0, -30],
});

// 🗺️ OpenRouteService API Key
const ORS_API_KEY = "5b3ce3597851110001cf62488a5c47eda3ea4c92888480af9d809cc8"; // Replace with a valid API key

// 🚌 Hardcoded Bus Data
const busRoutes = [
  { route_no: "2", source: { name: "Airoli", latitude: 19.1591, longitude: 72.9981 }, destination: { name: "Thane", latitude: 19.2183, longitude: 72.9781 } },
  { route_no: "3", source: { name: "Koperkhairane", latitude: 19.1197, longitude: 73.0037 }, destination: { name: "Thane", latitude: 19.2183, longitude: 72.9781 } },
  { route_no: "4", source: { name: "Vashi", latitude: 19.075, longitude: 72.998 }, destination: { name: "Thane", latitude: 19.2183, longitude: 72.9781 } },
  { route_no: "5", source: { name: "Airoli", latitude: 19.1500, longitude: 72.9950 }, destination: { name: "Bhivandi", latitude: 19.3400, longitude: 73.1300 } },
  { route_no: "7", source: { name: "Vashi", latitude: 19.0600, longitude: 73.0000 }, destination: { name: "Thane", latitude: 19.2183, longitude: 72.9781 } },
];

const MapComponent = () => {
  const [selectedBus, setSelectedBus] = useState(busRoutes[0]); // Default selection
  const [routePath, setRoutePath] = useState([]);
  const [userLocation, setUserLocation] = useState(null);

  // Get user location
  useEffect(() => {
    if (navigator.geolocation) {
      navigator.geolocation.getCurrentPosition(
        (position) => {
          setUserLocation([position.coords.latitude, position.coords.longitude]);
        },
        (error) => {
          console.error("Error getting location:", error);
        }
      );
    }
  }, []);

  // Fetch the actual route when the selected bus changes
  useEffect(() => {
    if (selectedBus) {
      fetchRoute(selectedBus);
    }
  }, [selectedBus]);

  // Fetch route using OpenRouteService API
  const fetchRoute = async (bus) => {
    if (!bus.source || !bus.destination) {
      console.error("Invalid bus data:", bus);
      return;
    }

    const startLat = bus.source.latitude;
    const startLng = bus.source.longitude;
    const endLat = bus.destination.latitude;
    const endLng = bus.destination.longitude;

    try {
      const response = await axios.get(
        `https://api.openrouteservice.org/v2/directions/driving-car?api_key=${ORS_API_KEY}&start=${startLng},${startLat}&end=${endLng},${endLat}&format=geojson`
      );

      console.log("API Response:", response.data); // ✅ Debugging: Check API response

      if (response.data.routes.length === 0) {
        console.error("No route found!");
        setRoutePath([]); // 🔹 Clear previous routes if none found
        return;
      }

      const newPath = response.data.routes[0].geometry.coordinates.map((coord) => coord.reverse()); // Reverse lat-lng
      setRoutePath(newPath);
    } catch (error) {
      console.error("Error fetching route:", error.response ? error.response.data : error);
    }
  };

  return (
    <>
      <Navbar /> {/* ✅ Added Navbar at the top */}
      <div style={{ height: "500px", width: "100%", position: "relative" }}>
        {/* 🔽 Dropdown for Bus Selection */}
        <DropdownButton
          id="custom-dropdown"
          title={`🚌 ${selectedBus.route_no}: ${selectedBus.source.name} → ${selectedBus.destination.name}`}
          variant="info"
          className="beautiful-dropdown"
        >
          {busRoutes.map((bus) => (
            <Dropdown.Item key={bus.route_no} onClick={() => setSelectedBus(bus)} className="dropdown-item-custom">
              🚌 {bus.route_no}: {bus.source.name} → {bus.destination.name}
            </Dropdown.Item>
          ))}
        </DropdownButton>

        {/* 🗺️ Map */}
        <MapContainer center={userLocation || [19.1, 72.99]} zoom={12} style={{ height: "100%", width: "100%" }}>
          <TileLayer
            url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
            attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
          />

          {/* Show Selected Bus Markers */}
          {selectedBus && (
            <>
              {/* Source Marker */}
              <Marker position={[selectedBus.source.latitude, selectedBus.source.longitude]} icon={busIcon}>
                <Popup>🚌 {selectedBus.route_no}: {selectedBus.source.name} → {selectedBus.destination.name}</Popup>
              </Marker>

              {/* Destination Marker */}
              <Marker position={[selectedBus.destination.latitude, selectedBus.destination.longitude]} icon={busIcon}>
                <Popup>🚌 {selectedBus.route_no}: {selectedBus.source.name} → {selectedBus.destination.name}</Popup>
              </Marker>
            </>
          )}

          {/* Draw Route from API Response */}
          {routePath.length > 0 ? (
            <Polyline positions={routePath} color="blue" weight={5} />
          ) : (
            console.warn("No route available") // Logs if no route is available
          )}

          {/* Show User Location */}
          {userLocation && (
            <Marker position={userLocation} icon={userIcon}>
              <Popup>📍 You are here</Popup>
            </Marker>
          )}
        </MapContainer>
      </div>
    </>
  );
};

export default MapComponent;
