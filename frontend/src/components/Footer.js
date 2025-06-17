import React from 'react';
import './Footer.css'; // Optional: Create a CSS file for styling
import { Link } from 'react-router-dom'; // Import Link for navigation

function Footer() {
  return (
    <footer className="footer">
      <div className="footer-container">
        <div className="footer-section">
          <h4>About NaviBus</h4>
          <p>
            NaviBus is your go-to platform for hassle-free bus travel. We provide details about all the NMMT buses.
          </p>
        </div>

        

        <div className="footer-section">
          <h4>Contact Us</h4>
          <p>Email: info@navibas.com</p>
          
        </div>

        <div className="footer-bottom">
          <p>&copy; {new Date().getFullYear()} Navibas. All Rights Reserved.</p>
          <div className="social-icons">
            {/* Add your social media icons here (e.g., Font Awesome) */}
            <a href="#" className="social-icon">
              <i className="fab fa-facebook"></i>
            </a>
            <a href="#" className="social-icon">
              <i className="fab fa-twitter"></i>
            </a>
            <a href="#" className="social-icon">
              <i className="fab fa-instagram"></i>
            </a>
          </div>
        </div>
      </div>
    </footer>
  );
}

export default Footer;