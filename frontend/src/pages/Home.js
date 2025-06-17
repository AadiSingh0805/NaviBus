import React from "react";
import ColorSchemesExample from "../components/Navbar";
import UncontrolledExample from "../components/Carousel";
import Chatbot from "../components/AvatarChatbot"; // Import the chatbot

const Home = () => {
  return (
    <div>
      <ColorSchemesExample />
      <div>
        <UncontrolledExample />
      </div>

      {/* Add the Avatar Chatbot Component */}
      <Chatbot />
    </div>
  );
};

export default Home;
