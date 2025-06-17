import React from 'react';
import { BrowserRouter as Router, Route, Routes } from 'react-router-dom';
import Home from './pages/Home';
import Buses from './pages/Buses';
import Fares from './pages/Fares';
import BusRoutes from './pages/BusRoutes'; // Renamed to avoid conflict with Router
import Feedback from './pages/Feedback';
import Footer from './components/Footer';
import MapComponent from './pages/MapComponent';


function App() {
  return (
    <Router>
      <Routes>
        <Route path="/" element={<Home />} />
        <Route path="/buses" element={<Buses />} />
        <Route path="/fares" element={<Fares />} />
        <Route path="/routes" element={<BusRoutes />} /> 
        <Route path="/feedback" element={<Feedback />} /> 
        <Route path="/map" element={<MapComponent />} /> 
      </Routes>
      <Footer/>
    </Router>
  );
}

export default App;