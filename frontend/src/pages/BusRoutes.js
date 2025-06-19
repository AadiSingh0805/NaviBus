import React, { useState } from 'react';

const BusRoutes = () => {
  const [start, setStart] = useState('');
  const [end, setEnd] = useState('');
  const [results, setResults] = useState([]);
  const [error, setError] = useState('');

  const searchRoutes = async () => {
    if (!start || !end) {
      setError("Please enter both start and end stops");
      return;
    }

    try {
      const res = await fetch(
        `http://localhost:8000/api/routes/search/?start=${encodeURIComponent(start)}&end=${encodeURIComponent(end)}`
      );
      const data = await res.json();

      if (!res.ok) throw new Error(data.error || data.message || "Search failed");

      // For each route, fetch the fare using the new fare API
      const farePromises = data.map(async (route) => {
        try {
          const fareRes = await fetch(
            `http://localhost:8000/api/routes/fare/?route_number=${encodeURIComponent(route.route_number)}&source_stop=${encodeURIComponent(start)}&destination_stop=${encodeURIComponent(end)}`
          );
          const fareData = await fareRes.json();
          return { ...route, fare: fareData.fare };
        } catch {
          return { ...route, fare: null };
        }
      });
      const routesWithFare = await Promise.all(farePromises);
      // Sort by fare (if available)
      const sorted = routesWithFare.sort((a, b) => (a.fare || 9999) - (b.fare || 9999));

      setResults(sorted);
      setError('');
    } catch (err) {
      setResults([]);
      setError(err.message);
    }
  };

  return (
    <div className="p-4 max-w-xl mx-auto">
      <h2 className="text-xl font-semibold mb-4">Search Bus Routes</h2>

      <input
        type="text"
        value={start}
        onChange={(e) => setStart(e.target.value)}
        placeholder="Enter start stop"
        className="border p-2 mb-2 w-full"
      />
      <input
        type="text"
        value={end}
        onChange={(e) => setEnd(e.target.value)}
        placeholder="Enter end stop"
        className="border p-2 mb-2 w-full"
      />

      <button
        onClick={searchRoutes}
        className="bg-blue-600 text-white px-4 py-2 rounded mb-4 w-full"
      >
        Search
      </button>

      {error && <p className="text-red-500 text-sm">{error}</p>}

      {results.length > 0 && (
        <div>
          <h3 className="text-lg font-semibold mb-2">Available Routes:</h3>
          {results.map((route, idx) => (
            <div key={idx} className="border p-3 my-2 rounded bg-gray-50 shadow">
              <h4 className="text-lg font-bold mb-1">Route: {route.route_number}</h4>

              <p><span className="font-semibold">Stops:</span></p>
              <ul className="list-disc ml-6 text-sm mb-2">
                {route.sub_path.map((stop, i) => (
                  <li key={i}>{stop}</li>
                ))}
              </ul>

              <div className="text-sm space-y-1">
                <p><strong>Fare:</strong> ₹{route.fare || 'N/A'}</p>
                <p><strong>Weekday First Bus:</strong> {route.first_bus_time_weekday || 'N/A'}</p>
                <p><strong>Weekday Last Bus:</strong> {route.last_bus_time_weekday || 'N/A'}</p>
                <p><strong>Sunday First Bus:</strong> {route.first_bus_time_sunday || 'N/A'}</p>
                <p><strong>Sunday Last Bus:</strong> {route.last_bus_time_sunday || 'N/A'}</p>
                <p><strong>Weekday Frequency:</strong> {route.frequency_weekday || 'N/A'} mins</p>
                <p><strong>Sunday Frequency:</strong> {route.frequency_sunday || 'N/A'} mins</p>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
};

export default BusRoutes;
