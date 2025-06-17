import React, { useState } from "react";

const Chatbot = () => {
  const [isOpen, setIsOpen] = useState(false); // State to toggle chatbot

  return (
    <div>
      {/* Chatbot Floating Button */}
      <button
        onClick={() => setIsOpen(!isOpen)}
        style={{
          position: "fixed",
          bottom: "30px",
          right: "30px",
          backgroundColor: "#fff",
          border: "none",
          borderRadius: "50%",
          width: "100px",  // Increased button size
          height: "100px",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          cursor: "pointer",
          boxShadow: "0px 5px 12px rgba(0, 0, 0, 0.2)",
          transition: "transform 0.2s ease, box-shadow 0.2s ease",
          zIndex: 9999,
        }}
        onMouseEnter={(e) =>
          (e.currentTarget.style.transform = "scale(1.1)")
        }
        onMouseLeave={(e) =>
          (e.currentTarget.style.transform = "scale(1)")
        }
      >
        <img
          src="/assets/bot.png" // Your chatbot button image
          alt="Chatbot"
          style={{
            width: "110%",
            height: "100%",
            objectFit: "cover",
            borderRadius: "50%",
            boxShadow: "0px 2px 10px rgba(0, 0, 0, 0.2)",
          }}
        />
      </button>

      {/* Chatbot Modal */}
      {isOpen && (
        <div
          style={{
            position: "fixed",
            bottom: "30px",
            right: "30px",
            width: "600px",  // Increased chatbot width
            height: "750px", // Increased chatbot height
            backgroundColor: "#fff",
            backgroundImage: "url('/assets/bot.png')", // Background image
            backgroundSize: "cover", // Cover entire modal
            backgroundPosition: "center", // Center the image
            borderRadius: "20px", // Slightly larger border radius
            boxShadow: "0px 10px 25px rgba(0, 0, 0, 0.2)",
            overflow: "hidden",
            zIndex: 99999,
            transform: isOpen ? "translateY(0)" : "translateY(50px)",
            opacity: isOpen ? 1 : 0,
            transition: "all 0.3s ease-in-out",
          }}
        >
          {/* Close Button */}
          <button
            onClick={() => setIsOpen(false)}
            style={{
              position: "absolute",
              top: "10px",
              right: "10px",
              background: "#ff4c4c",
              color: "#fff",
              border: "none",
              borderRadius: "50%",
              width: "40px",
              height: "40px",
              cursor: "pointer",
              fontSize: "22px",
              fontWeight: "bold",
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              boxShadow: "0px 2px 6px rgba(0, 0, 0, 0.2)",
              transition: "background 0.2s ease",
              zIndex: 100000,
            }}
            onMouseEnter={(e) =>
              (e.currentTarget.style.background = "#ff2c2c")
            }
            onMouseLeave={(e) =>
              (e.currentTarget.style.background = "#ff4c4c")
            }
          >
            ✕
          </button>

          {/* Embedded Chatbot */}
          <iframe
            src="https://app.vectorshift.ai/voicebots/embedded/67c42e6ba4d1089732434ba2"
            width="100%"
            height="100%"
            allow="microphone"
            style={{
              border: "none",
              borderRadius: "20px",
              zIndex: 99999,
            }}
          />
        </div>
      )}
    </div>
  );
};

export default Chatbot;
