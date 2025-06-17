import React from "react";
import ColorSchemesExample from "../components/Navbar";
import BasicExample from "../components/Card";
import "./BusRoutes.css";
import './Buses.css';

const busRoutes = [
  {
    bus_no: "3",
    destination: "Koperkhairne To Thane (Via Ghansoli Depot)",
    route_length: 14.5,
    first_bus_mon_sat: "6.30-7.18",
    first_bus_sunday: "6.30-7.18",
    last_bus_mon_sat: "19.35-20.25",
    last_bus_sunday: "19.35-20.25",
    journey_time: "45",
    frequency_mon_sat: "35-40-45",
    frequency_sunday: "35-40-45",
    fare: 21,
  },
  {
    bus_no: "4",
    destination: "Vashi Sec.07 To Thane via Koparkhairane Sec.22/23",
    route_length: 20.7,
    first_bus_mon_sat: "6.00-6.00",
    first_bus_sunday: "6.00-6.00",
    last_bus_mon_sat: "21.45-22.15",
    last_bus_sunday: "21.45-22.25",
    journey_time: "70",
    frequency_mon_sat: "25-30",
    frequency_sunday: "30-35",
    fare: 29,
  },
  {
    bus_no: "5",
    destination:
      "Airoli Bus Depot To Chatrapati Shivaji Maharaj Chowk Bhivandi Via Thane",
    route_length: 29.9,
    first_bus_mon_sat: "5.40-7.10",
    first_bus_sunday: "5.40-7.10",
    last_bus_mon_sat: "20.30(T)-22.00",
    last_bus_sunday: "20.30(T)-22.00",
    journey_time: "93-98-103",
    frequency_mon_sat: "20-25",
    frequency_sunday: "35-40-35",
    fare: 37,
  },
  {
    bus_no: "7",
    destination: "Vashi Rly.Stn. To Thane Via MBP Mahape",
    route_length: 19.7,
    first_bus_mon_sat: "7.10-6.05",
    first_bus_sunday: "7.10-6.05",
    last_bus_mon_sat: "21.30-22.45",
    last_bus_sunday: "21.30-22.45",
    journey_time: "63-65",
    frequency_mon_sat: "25-30-35",
    frequency_sunday: "25-30-35",
    fare: 27,
  },
];

const Buses = () => {
  return (
    <div>
      <ColorSchemesExample />
      <div className="card-container">
        {busRoutes.map((bus, index) => (
          <BasicExample
            key={index}
            busNo={bus.bus_no}
            destination={bus.destination}
            routeLength={bus.route_length}
            firstBusMonSat={bus.first_bus_mon_sat}
            firstBusSunday={bus.first_bus_sunday}
            lastBusMonSat={bus.last_bus_mon_sat}
            lastBusSunday={bus.last_bus_sunday}
            journeyTime={bus.journey_time}
            frequencyMonSat={bus.frequency_mon_sat}
            frequencySunday={bus.frequency_sunday}
            fare={bus.fare}
          />
        ))}
      </div>
    </div>
  );
};

export default Buses;
