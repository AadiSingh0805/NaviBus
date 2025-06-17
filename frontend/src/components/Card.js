import React from "react";
import { Card } from "react-bootstrap";

const BasicExample = ({
  busNo,
  destination,
  routeLength,
  firstBusMonSat,
  firstBusSunday,
  lastBusMonSat,
  lastBusSunday,
  journeyTime,
  frequencyMonSat,
  frequencySunday,
  fare,
}) => {
  return (
    <Card className="bus-card">
      <Card.Body>
        <Card.Title>Bus No: {busNo}</Card.Title>
        <Card.Subtitle className="mb-2 text-muted">{destination}</Card.Subtitle>
        <Card.Text>
          <strong>Route Length:</strong> {routeLength} km<br />
          <strong>Journey Time:</strong> {journeyTime} min<br />
          <strong>First Bus (Mon-Sat):</strong> {firstBusMonSat}<br />
          <strong>First Bus (Sunday):</strong> {firstBusSunday}<br />
          <strong>Last Bus (Mon-Sat):</strong> {lastBusMonSat}<br />
          <strong>Last Bus (Sunday):</strong> {lastBusSunday}<br />
          <strong>Frequency (Mon-Sat):</strong> {frequencyMonSat} min<br />
          <strong>Frequency (Sunday):</strong> {frequencySunday} min<br />
          <strong>Fare:</strong> ₹{fare}
        </Card.Text>
      </Card.Body>
    </Card>
  );
};

export default BasicExample;
