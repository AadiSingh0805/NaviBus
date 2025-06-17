import React, { useState, useEffect } from 'react';
import { Form, Button, Container, Card, Row, Col } from 'react-bootstrap';
import ColorSchemesExample from '../components/Navbar';
import 'bootstrap/dist/css/bootstrap.min.css';
import './Feedback.css'; // Import your CSS file for custom styles
import './FeedbackCard.css';

function Feedback() {
  const [name, setName] = useState('');
  const [category, setCategory] = useState('');
  const [description, setDescription] = useState('');
  const [feedbackList, setFeedbackList] = useState([]);

  useEffect(() => {
    fetchFeedback();
  }, []);

  // Fetch feedback from backend
  const fetchFeedback = async () => {
    try {
      const response = await fetch('http://localhost:8000/feedback/feedback/');
      if (!response.ok) throw new Error("Failed to fetch");

      const data = await response.json();
      console.log("Fetched Feedback Data:", data); // Debugging
      setFeedbackList(data);
    } catch (error) {
      console.error("Error fetching feedback:", error);
    }
  };

  // Handle feedback submission
  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!name.trim() || !category.trim() || !description.trim()) {
      alert('Please fill out all fields');
      return;
    }

    try {
      const response = await fetch('http://localhost:8000/feedback/feedback/', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name, category, description }),
      });

      if (response.ok) {
        alert('Feedback submitted successfully!');
        setName('');
        setCategory('');
        setDescription('');
        fetchFeedback(); // Refresh feedback list
      } else {
        alert('Failed to submit feedback');
      }
    } catch (error) {
      console.error("Error submitting feedback:", error);
    }
  };

  return (
    <>
      <ColorSchemesExample />

      <Container className="mt-5 pt-5">
        <h2 className="text-center mb-4">Submit Feedback</h2>

        <Form onSubmit={handleSubmit} className="mb-4 w-50 mx-auto">
          <Form.Group controlId="nameInput">
            <Form.Label>Name</Form.Label>
            <Form.Control
              type="text"
              placeholder="Enter your name"
              value={name}
              onChange={(e) => setName(e.target.value)}
            />
          </Form.Group>

          <Form.Group controlId="categoryInput">
            <Form.Label>Category</Form.Label>
            <Form.Control
              as="select"
              value={category}
              onChange={(e) => setCategory(e.target.value)}
            >
              <option value="">Select Category</option>
              <option value="Payment Issue">Payment Issue</option>
              <option value="Bus Delay">Bus Delay</option>
              <option value="Driver Behavior">Driver Behavior</option>
              <option value="Other">Other</option>
            </Form.Control>
          </Form.Group>

          <Form.Group controlId="descriptionTextarea">
            <Form.Label>Feedback</Form.Label>
            <Form.Control
              as="textarea"
              rows={4}
              placeholder="Enter your feedback..."
              value={description}
              onChange={(e) => setDescription(e.target.value)}
            />
          </Form.Group>

          <div className="d-flex justify-content-center mt-3">
            <Button variant="primary" type="submit">
              Submit
            </Button>
          </div>
        </Form>

        <h2 className="text-center mb-3">Previous Feedback</h2>

        {/* Display Feedback using Bootstrap Cards */}
        <Row className="justify-content-center">
          {feedbackList.length > 0 ? (
            feedbackList.map((item) => (
              <Col key={item.id} xs={12} sm={6} md={4} lg={3} className="mb-3">
                <Card className="shadow-sm">
                  <Card.Body>
                    <Card.Title>{item.name}</Card.Title>
                    <Card.Subtitle className="mb-2 text-muted">{item.category}</Card.Subtitle>
                    <Card.Text>{item.description}</Card.Text>
                    <Card.Footer className="text-muted" style={{ fontSize: '12px' }}>
                      {new Date(item.created_at).toLocaleString()}
                    </Card.Footer>
                  </Card.Body>
                </Card>
              </Col>
            ))
          ) : (
            <p className="text-muted text-center">No feedback available.</p>
          )}
        </Row>
      </Container>
    </>
  );
}

export default Feedback;