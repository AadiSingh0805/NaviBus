import React from 'react';
import Container from 'react-bootstrap/Container';
import Nav from 'react-bootstrap/Nav';
import Navbar from 'react-bootstrap/Navbar';
import { Link } from 'react-router-dom'; // Import Link
import './Navbar.css'; // Create Navbar.css for custom styles

function ColorSchemesExample() {
  return (
    <>
      <Navbar bg="dark" variant="dark" expand="lg" className="navbar">
        <Container className="navbar-container">
          <Navbar.Brand as={Link} to="/" className="navbar-brand">
            NaviBus
          </Navbar.Brand>
          <Navbar.Toggle aria-controls="basic-navbar-nav" />
          <Navbar.Collapse id="basic-navbar-nav">
            <Nav className="me-auto navbar-nav">
              <Nav.Link as={Link} to="/" className="navbar-link">
                Home
              </Nav.Link>
              <Nav.Link as={Link} to="/map" className="navbar-link">
                Map
              </Nav.Link>
              <Nav.Link as={Link} to="/buses" className="navbar-link">
                Buses
              </Nav.Link>
              <Nav.Link as={Link} to="/routes" className="navbar-link">
                Routes
              </Nav.Link>
              <Nav.Link as={Link} to="/fares" className="navbar-link">
                Fares
              </Nav.Link>
              <Nav.Link as={Link} to="/feedback" className="navbar-link">
                Feedback
              </Nav.Link>
            </Nav>
          </Navbar.Collapse>
        </Container>
      </Navbar>
    </>
  );
}

export default ColorSchemesExample;