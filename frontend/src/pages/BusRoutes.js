import React, { useState, useEffect } from "react";
import { Table, Form, Button, Container } from "react-bootstrap";
import ColorSchemesExample from "../components/Navbar";
import "bootstrap/dist/css/bootstrap.min.css";

function BusRoutes() {
  const [busRoutes, setBusRoutes] = useState([]);
  const [formData, setFormData] = useState({
    bus_no: "",
    destination: "",
    route_length: "",
    first_bus_mon_sat: "",
    first_bus_sunday: "",
    last_bus_mon_sat: "",
    last_bus_sunday: "",
    journey_time: "",
    frequency_mon_sat: "N/A", // Default to avoid blank error
    frequency_sunday: "N/A", // Default to avoid blank error
    fare: "",
  });

  useEffect(() => {
    fetchRoutes();
  }, []);

  const fetchRoutes = async () => {
    try {
      const response = await fetch("http://localhost:8000/api/busroutes/");
      if (!response.ok) throw new Error("Failed to fetch bus routes");
      const data = await response.json();
      setBusRoutes(data);
    } catch (error) {
      console.error("Error fetching bus routes:", error);
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    
    const formattedData = {
      ...formData,
      route_length: parseFloat(formData.route_length) || 0,
      fare: parseInt(formData.fare) || 0,
    };

    console.log("Submitting Data:", formattedData); // Debugging

    try {
      const response = await fetch("http://localhost:8000/api/busroutes/add/", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(formattedData),
      });

      const data = await response.json();

      if (response.ok) {
        alert("Bus route added successfully!");
        setFormData({
          bus_no: "",
          destination: "",
          route_length: "",
          first_bus_mon_sat: "",
          first_bus_sunday: "",
          last_bus_mon_sat: "",
          last_bus_sunday: "",
          journey_time: "",
          frequency_mon_sat: "N/A",
          frequency_sunday: "N/A",
          fare: "",
        });
        fetchRoutes();
      } else {
        console.error("Failed to add bus route:", data);
        alert(`Error: ${JSON.stringify(data)}`);
      }
    } catch (error) {
      console.error("Error submitting bus route:", error);
    }
  };

  return (
    <>
      <ColorSchemesExample />
      <Container className="mt-5 pt-5">
        <h2 className="text-center mb-4">Bus Routes</h2>

        {/* Table for Displaying Bus Routes */}
        <Table striped bordered hover responsive className="text-center">
          <thead className="thead-dark">
            <tr>
              <th>#</th>
              <th>Bus No</th>
              <th>Destination</th>
              <th>Route Length (km)</th>
              <th>First Bus (Mon-Sat)</th>
              <th>First Bus (Sunday)</th>
              <th>Last Bus (Mon-Sat)</th>
              <th>Last Bus (Sunday)</th>
              <th>Journey Time (min)</th>
              <th>Frequency (Mon-Sat)</th>
              <th>Frequency (Sunday)</th>
              <th>Fare (₹)</th>
            </tr>
          </thead>
          <tbody>
            {busRoutes.length > 0 ? (
              busRoutes.map((route, index) => (
                <tr key={index}>
                  <td>{index + 1}</td>
                  <td>{route.bus_no}</td>
                  <td>{route.destination}</td>
                  <td>{route.route_length}</td>
                  <td>{route.first_bus_mon_sat}</td>
                  <td>{route.first_bus_sunday}</td>
                  <td>{route.last_bus_mon_sat}</td>
                  <td>{route.last_bus_sunday}</td>
                  <td>{route.journey_time}</td>
                  <td>{route.frequency_mon_sat}</td>
                  <td>{route.frequency_sunday}</td>
                  <td>{route.fare}</td>
                </tr>
              ))
            ) : (
              <tr>
                <td colSpan="12" className="text-muted text-center">
                  No bus routes available.
                </td>
              </tr>
            )}
          </tbody>
        </Table>

        {/* Form to Add New Bus Route */}
        <h3 className="text-center mt-4">Add New Bus Route</h3>
        <Form onSubmit={handleSubmit} className="w-75 mx-auto">
          {[
            { label: "Bus Number", field: "bus_no", type: "text" },
            { label: "Destination", field: "destination", type: "text" },
            { label: "Route Length (km)", field: "route_length", type: "number" },
            { label: "First Bus (Mon-Sat)", field: "first_bus_mon_sat", type: "text" },
            { label: "First Bus (Sunday)", field: "first_bus_sunday", type: "text" },
            { label: "Last Bus (Mon-Sat)", field: "last_bus_mon_sat", type: "text" },
            { label: "Last Bus (Sunday)", field: "last_bus_sunday", type: "text" },
            { label: "Journey Time (min)", field: "journey_time", type: "number" },
            { label: "Frequency (Mon-Sat)", field: "frequency_mon_sat", type: "text" },
            { label: "Frequency (Sunday)", field: "frequency_sunday", type: "text" },
            { label: "Fare (₹)", field: "fare", type: "number" },
          ].map(({ label, field, type }) => (
            <Form.Group className="mb-2" key={field}>
              <Form.Label>{label}</Form.Label>
              <Form.Control
                type={type}
                placeholder={`Enter ${label.toLowerCase()}`}
                value={formData[field]}
                onChange={(e) => setFormData({ ...formData, [field]: e.target.value })}
                required
              />
            </Form.Group>
          ))}

          {/* Submit Button Centered */}
          <div className="d-flex justify-content-center mt-3">
            <Button variant="primary" type="submit">
              Add Route
            </Button>
          </div>
        </Form>
      </Container>
    </>
  );
}

export default BusRoutes;
