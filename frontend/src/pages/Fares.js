import React from "react";
import ColorSchemesExample from "../components/Navbar";
import "bootstrap/dist/css/bootstrap.min.css";
import "./Fares.css";

const busRoutes = [
  {
    bus_no: "3",
    destination: "Koperkhairne To Thane (Via Ghansoli Depot)",
    fares: [
      { stop: "Koperkhairne", fare: 5 },
      { stop: "Ghansoli Depot", fare: 10 },
      { stop: "Rabale", fare: 15 },
      { stop: "Airoli", fare: 18 },
      { stop: "Thane", fare: 21 },
    ],
  },
  {
    bus_no: "4",
    destination: "Vashi Sec.07 To Thane via Koparkhairane Sec.22/23",
    fares: [
      { stop: "Vashi Sec.07", fare: 6 },
      { stop: "Koparkhairane Sec.22", fare: 12 },
      { stop: "Ghansoli", fare: 18 },
      { stop: "Airoli", fare: 24 },
      { stop: "Thane", fare: 29 },
    ],
  },
  {
    bus_no: "5",
    destination:
      "Airoli Bus Depot To Chatrapati Shivaji Maharaj Chowk Bhivandi Via Thane",
    fares: [
      { stop: "Airoli Bus Depot", fare: 7 },
      { stop: "Mulund Check Naka", fare: 14 },
      { stop: "Thane", fare: 28 },
      { stop: "Bhivandi", fare: 37 },
    ],
  },
];

function Fares() {
  return (
    <div>
      <ColorSchemesExample />
      <div className="container mt-5">
        <h2 className="text-center mb-4">Bus Fares Timeline</h2>
        {busRoutes.map((bus) => (
          <div key={bus.bus_no} className="mb-5">
            <h4 className="text-primary">Bus No: {bus.bus_no}</h4>
            <p className="text-muted">{bus.destination}</p>
            <ul className="list-group timeline">
              {bus.fares.map((stop, index) => (
                <li
                  key={index}
                  className="list-group-item d-flex justify-content-between align-items-center"
                >
                  <span className="stop-name">{stop.stop}</span>
                  <span className="badge bg-primary rounded-pill">
                    ₹{stop.fare}
                  </span>
                </li>
              ))}
            </ul>
          </div>
        ))}
      </div>
    </div>
  );
}

export default Fares;
